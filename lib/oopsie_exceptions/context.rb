# frozen_string_literal: true

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
        request = ActionDispatch::Request.new(env)
        config = OopsieExceptions.configuration

        ctx = {
          request: {
            url: request.original_url,
            method: request.method,
            ip: request.remote_ip,
            user_agent: request.user_agent,
            referer: request.referer,
            request_id: request.request_id,
            params: sanitize_params(request.filtered_parameters),
            headers: extract_headers(env, config)
          }
        }

        if config.capture_request_body && request.content_type&.include?("application/json")
          body = request.body.read
          request.body.rewind
          ctx[:request][:body] = body.truncate(10_000) if body.present?
        end

        ctx
      end

      private

      def sanitize_params(params)
        params.except("controller", "action").to_h
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
