# frozen_string_literal: true

require_relative "../test_helper"

module Sidekiq
  class JobRetry
    class Handled < StandardError; end
  end
end

class OopsieExceptionsReportingTest < Minitest::Test
  REAL_BACKTRACE = ["/app/jobs/import_job.rb:42:in `perform'"].freeze
  DIRECT_BACKTRACE = ["/app/services/direct_reporter.rb:7:in `call'"].freeze

  def setup
    @previous_configuration = OopsieExceptions.instance_variable_get(:@configuration)
    @payloads = []
    OopsieExceptions.instance_variable_set(:@configuration, OopsieExceptions::Configuration.new)
    OopsieExceptions.configuration.before_notify = ->(payload) do
      @payloads << payload
      payload
    end
    OopsieExceptions.clear_context
  end

  def teardown
    OopsieExceptions.clear_context
    OopsieExceptions.instance_variable_set(:@configuration, @previous_configuration)
  end

  def test_sidekiq_retry_wrapper_reports_underlying_exception_as_top_level_error
    wrapper = sidekiq_retry_wrapper_with_cause

    OopsieExceptions.report(
      wrapper,
      context: { source: "sidekiq" },
      handled: false
    )

    payload = @payloads.fetch(0)
    error = payload[:error]

    assert_equal "RuntimeError", error[:class_name]
    assert_equal "real job failure", error[:message]
    assert_equal REAL_BACKTRACE, error[:backtrace]
    assert_equal(
      { file: "/app/jobs/import_job.rb", line: 42, method: "perform" },
      error[:first_line]
    )
    assert_equal [], error[:causes]
    assert_equal false, error[:handled]

    wrapper_context = payload[:context].fetch(:exception_wrapper)
    assert_equal "Sidekiq::JobRetry::Handled", wrapper_context[:class_name]
    assert_equal "sidekiq handled retry", wrapper_context[:message]
    assert_equal "sidekiq", wrapper_context[:source]
    assert_nil wrapper_context[:first_line]
  end

  def test_direct_exceptions_report_unchanged
    exception = StandardError.new("direct report")
    exception.set_backtrace(DIRECT_BACKTRACE)

    OopsieExceptions.report(
      exception,
      context: { request_id: "req_123" },
      handled: true
    )

    payload = @payloads.fetch(0)
    error = payload[:error]

    assert_equal "StandardError", error[:class_name]
    assert_equal "direct report", error[:message]
    assert_equal DIRECT_BACKTRACE, error[:backtrace]
    assert_equal(
      { file: "/app/services/direct_reporter.rb", line: 7, method: "call" },
      error[:first_line]
    )
    assert_equal [], error[:causes]
    assert_equal true, error[:handled]
    assert_equal "req_123", payload[:context][:request_id]
    refute payload[:context].key?(:exception_wrapper)
  end

  def test_ignored_sidekiq_retry_wrapper_still_reports_non_ignored_cause
    OopsieExceptions.configuration.ignore_exception("Sidekiq::JobRetry::Handled")

    OopsieExceptions.report(sidekiq_retry_wrapper_with_cause)

    assert_equal 1, @payloads.size
    assert_equal "RuntimeError", @payloads.fetch(0)[:error][:class_name]
  end

  def test_ignored_underlying_exception_is_not_reported
    OopsieExceptions.configuration.ignore_exception("RuntimeError")

    OopsieExceptions.report(sidekiq_retry_wrapper_with_cause)

    assert_empty @payloads
  end

  def test_sidekiq_retry_wrapper_marks_underlying_exception_as_reported
    wrapper = sidekiq_retry_wrapper_with_cause

    OopsieExceptions.report(wrapper)
    OopsieExceptions.report(wrapper.cause)

    assert_equal 1, @payloads.size
    assert_equal "RuntimeError", @payloads.fetch(0)[:error][:class_name]
  end

  private

  def sidekiq_retry_wrapper_with_cause
    real_exception = RuntimeError.new("real job failure")
    real_exception.set_backtrace(REAL_BACKTRACE)

    begin
      raise real_exception
    rescue RuntimeError
      begin
        raise Sidekiq::JobRetry::Handled, "sidekiq handled retry"
      rescue Sidekiq::JobRetry::Handled => wrapper
        wrapper.set_backtrace([])
        return wrapper
      end
    end
  end
end
