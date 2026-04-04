OopsieExceptions.configure do |config|
  # Add webhook endpoints — exceptions get POSTed here as JSON
  # config.add_webhook "https://your-endpoint.com/webhooks/exceptions",
  #   headers: { "Authorization" => "Bearer <%= "#{ENV['OOPSIE_WEBHOOK_TOKEN']}" %>" },
  #   name: "primary"

  # config.add_webhook "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
  # config.add_webhook "https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK"

  config.app_name = Rails.application.class.module_parent_name
  config.environment = Rails.env

  # Deliver webhooks async via ActiveJob (set false for sync delivery)
  config.async_delivery = true

  # Exceptions that won't be reported (404s, bot garbage, etc.)
  # config.ignore_exception "ActionController::RoutingError"

  # Filter sensitive params from payloads (inherits from Rails by default)
  config.filter_parameters = Rails.application.config.filter_parameters.map(&:to_s)

  # Set false to disable in dev/test
  config.enabled = Rails.env.production? || Rails.env.staging?

  # Optional: modify or drop payloads before sending
  # config.before_notify = ->(payload) {
  #   payload[:context][:deploy_sha] = ENV["GIT_SHA"]
  #   payload  # return nil to skip this notification
  # }
end
