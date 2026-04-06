OopsieExceptions.configure do |config|
  # Webhook endpoints — exceptions get POSTed as JSON.
  # Configure per-environment so dev errors don't hit your prod tracker.
  if Rails.env.development?
    config.add_webhook(
      "http://localhost:3099/api/v1/exceptions",
      headers: { "Authorization" => "Bearer #{ENV['OOPSIE_DEV_TOKEN']}" },
      name: "oopsie-local"
    )
    config.async_delivery = false
  end

  if Rails.env.production?
    config.add_webhook(
      "https://oopsie.example.com/api/v1/exceptions",
      headers: { "Authorization" => "Bearer #{ENV['OOPSIE_PROD_TOKEN']}" },
      name: "oopsie-prod"
    )
    config.async_delivery = true
  end

  # config.add_webhook "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
  # config.add_webhook "https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK"

  config.app_name = Rails.application.class.module_parent_name
  config.environment = Rails.env

  # Filter sensitive params from payloads (inherits from Rails by default)
  config.filter_parameters = Rails.application.config.filter_parameters.map(&:to_s)

  # Master kill switch — leave off in test
  config.enabled = Rails.env.development? || Rails.env.production?

  # Exceptions that won't be reported (404s, bot garbage, etc.)
  # config.ignore_exception "MyApp::IgnorableError"

  # Attach the current user and controller#action to every exception.
  # `env` is the Rack env — runs once per request, before any controller code.
  # config.context_builder = ->(env) {
  #   warden = env["warden"]
  #   user = warden&.user
  #   params = env["action_dispatch.request.path_parameters"]
  #   {
  #     user: user ? { id: user.id, email: user.email } : nil,
  #     action: params ? "#{params[:controller]}##{params[:action]}" : nil
  #   }.compact
  # }

  # Optional: modify or drop payloads before sending
  # config.before_notify = ->(payload) {
  #   payload[:context][:deploy_sha] = ENV["GIT_SHA"]
  #   payload  # return nil to skip this notification
  # }
end
