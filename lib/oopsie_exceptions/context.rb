# frozen_string_literal: true

require "rack/request"

module OopsieExceptions
  module Context
    THREAD_KEY = :oopsie_exceptions_context

    class << self
      def current
        Thread.current[THREAD_KEY] ||= {}
      end

      def merge(hash)
        current.merge!(hash)
      end

      def replace(hash)
        Thread.current[THREAD_KEY] = hash
      end

      def clear
        Thread.current[THREAD_KEY] = nil
      end

      def from_rack_env(env)
        request = Rack::Request.new(env)
        config = OopsieExceptions.configuration

        request_context = {
          url: request.url,
          method: request.request_method,
          ip: request.ip,
          user_agent: env["HTTP_USER_AGENT"],
          referer: env["HTTP_REFERER"],
          request_id: env["action_dispatch.request_id"] || env["HTTP_X_REQUEST_ID"],
          headers: extract_headers(env, config)
        }

        request_context.merge!(request_params_context(request, config))
        request_context.merge!(request_body_context(request, config))

        ctx = {
          request: request_context
        }

        ctx
      end

      private

      def request_params_context(request, config)
        { params: sanitize_params(request.params, config) }
      rescue StandardError => error
        rewind_body(request.body)
        {
          params: {},
          params_omitted: true,
          params_error_class: error.class.name
        }
      end

      def request_body_context(request, config)
        return {} unless config.capture_request_body
        return {} unless request.content_type&.include?("application/json")

        body_io = request.body
        body = body_io.read
        return {} if body.nil? || body.empty?

        { body: body[0, 10_000] }
      rescue StandardError => error
        {
          body_omitted: true,
          body_error_class: error.class.name
        }
      ensure
        rewind_body(body_io)
      end

      def sanitize_params(params, config)
        filtered = params.reject { |k, _| k == "controller" || k == "action" }
        filter_keys = config.filter_parameters
        filtered.each_with_object({}) do |(k, v), hash|
          hash[k] = filter_keys.any? { |f| k.to_s.include?(f.to_s) } ? "[FILTERED]" : v
        end
      end

      def extract_headers(env, config)
        headers = {}
        env.each do |key, value|
          next unless key.start_with?("HTTP_")
          header_name = key.sub("HTTP_", "").split("_").map(&:capitalize).join("-")
          next if config.filter_headers.any? { |h| h.to_s.casecmp(header_name) == 0 }
          headers[header_name] = value
        end
        headers
      end

      def rewind_body(body_io)
        body_io.rewind if body_io&.respond_to?(:rewind)
      rescue StandardError
        nil
      end
    end
  end
end
