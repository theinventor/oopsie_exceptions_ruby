# frozen_string_literal: true

require_relative "oopsie_exceptions/version"
require_relative "oopsie_exceptions/configuration"
require_relative "oopsie_exceptions/context"
require_relative "oopsie_exceptions/exception_normalizer"
require_relative "oopsie_exceptions/payload"
require_relative "oopsie_exceptions/webhook_client"
require_relative "oopsie_exceptions/middleware"
require_relative "oopsie_exceptions/error_subscriber"
require_relative "oopsie_exceptions/active_job_extension"
require_relative "oopsie_exceptions/railtie" if defined?(Rails::Railtie)

module OopsieExceptions
  REPORTED_MARKER = :@__oopsie_reported

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def report(exception, context: {}, handled: true)
      return unless configuration.enabled
      normalized = ExceptionNormalizer.normalize(exception, context: context)
      reportable_exception = normalized.exception

      return if configuration.ignored?(reportable_exception)
      return if reportable_exception.instance_variable_get(REPORTED_MARKER)

      ([reportable_exception] + normalized.wrappers).each do |reported_exception|
        reported_exception.instance_variable_set(REPORTED_MARKER, true)
      end

      payload = Payload.build(reportable_exception, context: normalized.context, handled: handled)

      if configuration.before_notify
        payload = configuration.before_notify.call(payload)
        return if payload.nil?
      end

      deliver(payload)
    end

    def set_context(hash)
      Context.merge(hash)
    end

    def clear_context
      Context.clear
    end

    def with_context(hash)
      previous = Context.current.dup
      Context.merge(hash)
      yield
    ensure
      Context.replace(previous)
    end

    private

    def deliver(payload)
      configuration.webhook_urls.each do |webhook|
        if configuration.async_delivery && defined?(OopsieExceptions::WebhookJob)
          WebhookJob.perform_later(
            payload.to_json,
            webhook.url,
            webhook.headers.to_json
          )
        else
          WebhookClient.post(webhook, payload)
        end
      end
    end
  end
end
