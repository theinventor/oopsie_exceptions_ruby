# OopsieExceptions

Lightweight exception capture and webhook delivery for Rails. Like Sentry/Rollbar, but self-hosted and webhook-driven.

Captures unhandled exceptions from web requests and background jobs, enriches them with request/user/server context, and delivers structured JSON payloads to configurable webhook endpoints.

## Installation

Add to your Gemfile:

```ruby
gem "oopsie_exceptions"
```

Then run the install generator:

```bash
bin/rails generate oopsie_exceptions:install
```

This creates:
- `config/initializers/oopsie_exceptions.rb` — configuration
- `app/jobs/oopsie_exceptions/delivery_job.rb` — async webhook delivery

## Configuration

Edit `config/initializers/oopsie_exceptions.rb`:

```ruby
OopsieExceptions.configure do |config|
  config.add_webhook "https://your-endpoint.com/webhooks/exceptions",
    headers: { "Authorization" => "Bearer #{ENV['OOPSIE_WEBHOOK_TOKEN']}" }

  config.app_name = "MyApp"
  config.environment = Rails.env
  config.enabled = Rails.env.production?
end
```

## What happens automatically

- **Rack middleware** inserted after `DebugExceptions` catches unhandled exceptions
- **Rails.error subscriber** captures framework-reported errors
- Request context (URL, IP, params, headers) is collected automatically
- Webhooks are delivered async via ActiveJob

## Adding user context

In your `ApplicationController`:

```ruby
before_action :set_oopsie_context

private

def set_oopsie_context
  OopsieExceptions.set_context(
    user: current_user ? { id: current_user.id, email: current_user.email } : nil,
    action: "#{self.class.name}##{action_name}"
  )
end
```

## Manual reporting

```ruby
begin
  risky_operation
rescue => e
  OopsieExceptions.report(e, context: { order_id: 123 }, handled: true)
end
```

## Multiple webhooks

```ruby
config.add_webhook "https://your-api.com/exceptions"
config.add_webhook "https://hooks.slack.com/services/..."
config.add_webhook "https://discord.com/api/webhooks/..."
```

Each endpoint receives every exception.

## Payload format

Each webhook receives a JSON payload with:

- **exception** — class, message, backtrace, cause chain
- **request** — URL, method, IP, params, headers, user agent
- **context** — user info and custom data you set
- **server** — hostname, PID, Ruby/Rails versions
- **app** — name, environment
- **timestamp** — UTC ISO8601

## Filtering

By default, common noise exceptions are ignored (404s, routing errors, `ActionController::BadRequest`, etc.). Sensitive parameters (`password`, `token`, `secret`, `api_key`) and headers (`Authorization`, `Cookie`) are automatically filtered from payloads.

Customize in your initializer:

```ruby
config.ignored_exceptions += ["MyApp::IgnorableError"]
config.filter_parameters += [:credit_card]
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).
