# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module OopsieExceptions
  class WebhookClient
    class << self
      def post(webhook, payload)
        uri = URI.parse(webhook.url)
        config = OopsieExceptions.configuration

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = config.open_timeout
        http.read_timeout = config.timeout

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "OopsieExceptions/#{VERSION}"

        webhook.headers.each { |k, v| request[k] = v }

        request.body = payload.is_a?(String) ? payload : payload.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          log_warn("Webhook #{webhook.name} responded #{response.code}: #{response.body.to_s[0, 500]}")
        end

        response
      rescue => e
        log_error("Failed to deliver to #{webhook.name}: #{e.message}")
        nil
      end

      private

      def log_warn(message)
        if defined?(Rails.logger) && Rails.logger
          Rails.logger.warn("[OopsieExceptions] #{message}")
        else
          warn("[OopsieExceptions] #{message}")
        end
      end

      def log_error(message)
        if defined?(Rails.logger) && Rails.logger
          Rails.logger.error("[OopsieExceptions] #{message}")
        else
          warn("[OopsieExceptions] ERROR: #{message}")
        end
      end
    end
  end
end
