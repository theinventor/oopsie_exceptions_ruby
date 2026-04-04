# frozen_string_literal: true

module OopsieExceptions
  class Configuration
    attr_accessor :webhook_urls, :app_name, :environment,
                  :ignored_exceptions, :filter_parameters,
                  :filter_headers, :capture_request_body,
                  :async_delivery, :timeout, :open_timeout,
                  :backtrace_cleaner, :before_notify,
                  :enabled

    def initialize
      @webhook_urls = []
      @app_name = defined?(Rails) ? (Rails.application.class.module_parent_name rescue "App") : "App"
      @environment = defined?(Rails) ? (Rails.env rescue "development") : "development"
      @ignored_exceptions = default_ignored_exceptions
      @filter_parameters = %w[password password_confirmation secret token api_key]
      @filter_headers = %w[Authorization Cookie Set-Cookie]
      @capture_request_body = false
      @async_delivery = true
      @timeout = 10
      @open_timeout = 5
      @backtrace_cleaner = nil
      @before_notify = nil
      @enabled = true
    end

    def add_webhook(url, headers: {}, name: nil)
      @webhook_urls << Webhook.new(url: url, headers: headers, name: name || url)
    end

    def ignore_exception(*class_names)
      @ignored_exceptions.concat(class_names.map(&:to_s))
    end

    def ignored?(exception)
      @ignored_exceptions.include?(exception.class.name)
    end

    private

    def default_ignored_exceptions
      %w[
        ActionController::RoutingError
        ActionController::UnknownFormat
        ActionController::BadRequest
        ActionDispatch::Http::MimeNegotiation::InvalidType
        AbstractController::ActionNotFound
        ActiveRecord::RecordNotFound
        ActionController::UnknownHttpMethod
      ]
    end

    Webhook = Data.define(:url, :headers, :name)
  end
end
