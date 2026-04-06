# frozen_string_literal: true

# Webhook delivery job. Loaded from the Railtie inside on_load(:active_job),
# so it's only defined when the host app has ActiveJob available.
#
# Inherits from ActiveJob::Base directly (not ApplicationJob) so the gem has
# zero hard dependencies on host-app code.
module OopsieExceptions
  class WebhookJob < ActiveJob::Base
    queue_as :default

    discard_on StandardError do |_job, error|
      logger = OopsieExceptions.configuration.logger
      logger&.error("[OopsieExceptions] WebhookJob discarded permanently: #{error.message}")
    end

    retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 5.seconds, attempts: 3

    def perform(payload_json, webhook_url, headers_json)
      webhook = OopsieExceptions::Configuration::Webhook.new(
        url: webhook_url,
        headers: JSON.parse(headers_json),
        name: webhook_url
      )

      OopsieExceptions::WebhookClient.post(webhook, payload_json)
    end
  end
end
