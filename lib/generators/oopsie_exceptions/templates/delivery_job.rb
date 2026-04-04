module OopsieExceptions
  class DeliveryJob < ApplicationJob
    queue_as :default

    discard_on StandardError do |job, error|
      Rails.logger.error("[OopsieExceptions] DeliveryJob failed permanently: #{error.message}")
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
