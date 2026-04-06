# frozen_string_literal: true

require "rack"

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

        ctx = {
          request: {
            url: request.url,
            method: request.request_method,
            ip: request.ip,
            user_agent: env["HTTP_USER_AGENT"],
            referer: env["HTTP_REFERER"],
            request_id: env["action_dispatch.request_id"] || env["HTTP_X_REQUEST_ID"],
            params: sanitize_params(request.params, config),
            headers: extract_headers(env, config)
          }
        }

        if config.capture_request_body && request.content_type&.include?("application/json")
          body = request.body.read
          request.body.rewind
          ctx[:request][:body] = body[0, 10_000] if body && !body.empty?
        end

        ctx
      end

      private

      def sanitize_params(params, config)
        filtered = params.reject { |k, _| k == "controller" || k == "action" }
        filter_keys = config.filter_parameters
        filtered.each_with_object({}) do |(k, v), hash|
          hash[k] = filter_keys.any? { |f| k.to_s.include?(f) } ? "[FILTERED]" : v
        end
      rescue
        {}
      end

      def extract_headers(env, config)
        headers = {}
        env.each do |key, value|
          next unless key.start_with?("HTTP_")
          header_name = key.sub("HTTP_", "").split("_").map(&:capitalize).join("-")
          next if config.filter_headers.any? { |h| h.casecmp(header_name) == 0 }
          headers[header_name] = value
        end
        headers
      end
    end
  end
end
