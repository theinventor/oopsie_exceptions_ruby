# OopsieExceptions

Lightweight exception capture and webhook delivery for Rails. Like Sentry/Rollbar, but self-hosted and webhook-driven.

Captures unhandled exceptions from web requests and background jobs, enriches them with request/user/server context, and POSTs structured JSON payloads to one or more webhook endpoints.

## Installation

Add to your Gemfile:

```ruby
gem "oopsie_exceptions"
```

Then run the install generator:

```bash
bin/rails generate oopsie_exceptions:install
```

That creates a single file: `config/initializers/oopsie_exceptions.rb`. No code lands in `app/` — the Rack middleware, Rails error subscriber, ActiveJob hook, and webhook delivery job all live inside the gem.

## Configuration

The most common pattern is to configure a different webhook per environment, with the URL and auth token coming from environment variables. Here's a real-world initializer:

```ruby
# config/initializers/oopsie_exceptions.rb
OopsieExceptions.configure do |config|
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

  config.app_name = "MyApp"
  config.environment = Rails.env
  config.filter_parameters = %w[password password_confirmation secret token api_key]
  config.enabled = Rails.env.development? || Rails.env.production?

  # Attach the current user and controller#action to every exception.
  # `env` is the Rack env — runs once per request.
  config.context_builder = ->(env) {
    warden = env["warden"]
    user = warden&.user
    params = env["action_dispatch.request.path_parameters"]
    {
      user: user ? { id: user.id, email: user.email } : nil,
      action: params ? "#{params[:controller]}##{params[:action]}" : nil
    }.compact
  }
end
```

### Configuration options

| Option | Default | Description |
| --- | --- | --- |
| `add_webhook(url, headers:, name:)` | — | Register a webhook. Call multiple times for fan-out. |
| `app_name` | Rails app module name | Identifier sent in every payload. |
| `environment` | `Rails.env` | Environment label sent in every payload. |
| `enabled` | `true` | Master kill switch. Set false in test/dev. |
| `async_delivery` | `true` | Deliver via ActiveJob. Set false to POST inline. |
| `filter_parameters` | `password, secret, token, api_key, ...` | Param names to redact in payloads. |
| `filter_headers` | `Authorization, Cookie, Set-Cookie` | Headers to strip from payloads. |
| `capture_request_body` | `false` | Include first 10KB of JSON request bodies. |
| `ignored_exceptions` | 404s, routing errors, etc. | Exception class names to silently drop. |
| `ignore_exception(*names)` | — | Append to `ignored_exceptions`. |
| `context_builder` | `nil` | `->(env) { Hash }` — extra context per request. |
| `before_notify` | `nil` | `->(payload) { payload }` — mutate or drop payloads. |
| `timeout` / `open_timeout` | `10` / `5` | HTTP timeouts (seconds). |

## What gets captured automatically

- **Web requests** — A Rack middleware inserted after `ActionDispatch::DebugExceptions` catches unhandled exceptions and 5xx responses.
- **Background jobs** — `ActiveJob::Base.execute` is wrapped at the class level (the same approach Appsignal uses), so every queue adapter (Solid Queue, Sidekiq, Async, etc.) is covered. Catches `DeserializationError` and missing job classes too.
- **`Rails.error` reports** — Subscribed via `Rails.error.subscribe`, so anything reported through the framework error reporter (`Rails.error.report` / `Rails.error.handle`) flows through.

Each captured exception is enriched with request URL/method/IP/params/headers, the current user (via `context_builder` or `set_context`), server hostname/PID/Ruby version, and a UTC timestamp.

## Adding context per-request

If you don't want to use `context_builder`, you can set context from a controller:

```ruby
class ApplicationController < ActionController::Base
  before_action :set_oopsie_context

  private

  def set_oopsie_context
    OopsieExceptions.set_context(
      user: current_user ? { id: current_user.id, email: current_user.email } : nil,
      action: "#{self.class.name}##{action_name}"
    )
  end
end
```

`context_builder` is preferred — it runs in the middleware before the request hits any controller, so it captures context even on errors raised before `before_action` runs.

## Manual reporting

```ruby
begin
  risky_operation
rescue => e
  OopsieExceptions.report(e, context: { order_id: 123 }, handled: true)
end
```

Or scope context to a block:

```ruby
OopsieExceptions.with_context(tenant_id: 42) do
  do_work
end
```

## Multiple webhooks

```ruby
config.add_webhook "https://your-api.com/exceptions",
  headers: { "Authorization" => "Bearer #{ENV['PRIMARY_TOKEN']}" }

config.add_webhook "https://hooks.slack.com/services/..."
config.add_webhook "https://discord.com/api/webhooks/..."
```

Each endpoint receives every exception. Failures on one webhook don't affect the others.

## Payload format

Each webhook receives a JSON POST with:

- **exception** — class, message, backtrace, cause chain
- **request** — URL, method, IP, params, headers, user agent
- **context** — `user`, `action`, `job`, plus anything you set via `context_builder` / `set_context`
- **server** — hostname, PID, Ruby/Rails versions
- **app** — `app_name`, `environment`
- **timestamp** — UTC ISO8601
- **handled** — `true` for `OopsieExceptions.report(..., handled: true)`, `false` for unhandled

## Filtering noise

By default these are dropped:

```
ActionController::RoutingError
ActionController::UnknownFormat
ActionController::BadRequest
ActionDispatch::Http::MimeNegotiation::InvalidType
AbstractController::ActionNotFound
ActiveRecord::RecordNotFound
ActionController::UnknownHttpMethod
```

Add your own:

```ruby
config.ignore_exception "MyApp::IgnorableError", "ThirdParty::Timeout"
```

Sensitive params (`password`, `token`, `secret`, `api_key`) and headers (`Authorization`, `Cookie`, `Set-Cookie`) are redacted from payloads automatically.

## Mutating or dropping payloads

```ruby
config.before_notify = ->(payload) {
  payload[:context][:deploy_sha] = ENV["GIT_SHA"]
  return nil if payload[:exception][:message].include?("known noise")
  payload
}
```

Return `nil` to drop the notification entirely.

## Upgrading from earlier versions

If you're coming from an older version of the gem that generated `app/jobs/oopsie_exceptions/delivery_job.rb` in your app, **delete that file**. The gem now ships its own `OopsieExceptions::WebhookJob` and the host-app file is obsolete.

```bash
rm app/jobs/oopsie_exceptions/delivery_job.rb
rmdir app/jobs/oopsie_exceptions  # if empty
```

Or just re-run the install generator and it will detect and remove the legacy file for you:

```bash
bin/rails generate oopsie_exceptions:install
```

No initializer changes are required.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
