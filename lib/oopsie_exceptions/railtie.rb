# frozen_string_literal: true

module OopsieExceptions
  class Railtie < Rails::Railtie
    initializer "oopsie_exceptions.middleware" do |app|
      app.middleware.insert_after ActionDispatch::DebugExceptions, OopsieExceptions::Middleware
    end

    initializer "oopsie_exceptions.error_subscriber", after: :load_config_initializers do
      if Rails.respond_to?(:error) && OopsieExceptions.configuration.enabled
        Rails.error.subscribe(OopsieExceptions::ErrorSubscriber.new)
      end
    end
  end
end
