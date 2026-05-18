# frozen_string_literal: true

require_relative "../test_helper"

class OopsieExceptionsContextTest < Minitest::Test
  class RaisingBody
    attr_reader :rewound

    def read(*)
      raise EOFError, "end of file reached"
    end

    def rewind
      @rewound = true
    end
  end

  def setup
    @previous_configuration = OopsieExceptions.instance_variable_get(:@configuration)
    OopsieExceptions.instance_variable_set(:@configuration, OopsieExceptions::Configuration.new)
  end

  def teardown
    OopsieExceptions.instance_variable_set(:@configuration, @previous_configuration)
  end

  def test_preserves_sanitized_params_for_valid_requests
    env = Rack::MockRequest.env_for(
      "/submit?visible=1&token=query-secret",
      method: "POST",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      input: "name=Troy&password=body-secret&controller=home&action=create"
    )

    request_context = OopsieExceptions::Context.from_rack_env(env)[:request]

    assert_equal "1", request_context[:params]["visible"]
    assert_equal "Troy", request_context[:params]["name"]
    assert_equal "[FILTERED]", request_context[:params]["token"]
    assert_equal "[FILTERED]", request_context[:params]["password"]
    refute request_context[:params].key?("controller")
    refute request_context[:params].key?("action")
    refute request_context.key?(:params_omitted)
  end

  def test_omits_params_when_rack_parser_rejects_malformed_multipart
    env = Rack::MockRequest.env_for(
      "/upload",
      method: "POST",
      "CONTENT_TYPE" => "multipart/form-data; boundary=oopsie",
      input: "--oopsie\r\nContent-Disposition: form-data; name=\"file\"; filename=\"x.txt\"\r\nContent-Type: text/plain\r\n\r\npartial"
    )

    request_context = OopsieExceptions::Context.from_rack_env(env)[:request]

    assert_equal({}, request_context[:params])
    assert_equal true, request_context[:params_omitted]
    assert_match(/\A(?:EOFError|Rack::Multipart::)/, request_context[:params_error_class])
  end

  def test_omits_json_body_when_capture_read_raises_eof
    OopsieExceptions.configuration.capture_request_body = true
    body = RaisingBody.new
    env = Rack::MockRequest.env_for(
      "/events",
      method: "POST",
      "CONTENT_TYPE" => "application/json",
      input: ""
    )
    env["rack.input"] = body

    request_context = OopsieExceptions::Context.from_rack_env(env)[:request]

    assert_equal true, request_context[:body_omitted]
    assert_equal "EOFError", request_context[:body_error_class]
    assert_equal true, body.rewound
  end

  def test_preserves_json_body_capture_for_valid_requests
    OopsieExceptions.configuration.capture_request_body = true
    env = Rack::MockRequest.env_for(
      "/events",
      method: "POST",
      "CONTENT_TYPE" => "application/json",
      input: '{"ok":true}'
    )

    request_context = OopsieExceptions::Context.from_rack_env(env)[:request]

    assert_equal '{"ok":true}', request_context[:body]
    refute request_context.key?(:body_omitted)
  end
end
