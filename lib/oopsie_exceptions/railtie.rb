# frozen_string_literal: true

module OopsieExceptions
  class Railtie < Rails::Railtie
    initializer "oopsie_exceptions.middleware" do |app|
      app.middleware.insert_after ActionDispatch::DebugExceptions, OopsieExceptions::Middleware
    end

    initializer "oopsie_exceptions.active_job" do
      ActiveSupport.on_load(:active_job) do
        around_perform do |job, block|
          OopsieExceptions.with_context(
            job: {
              class: job.class.name,
              job_id: job.job_id,
              queue: job.queue_name,
              arguments: job.arguments.map(&:to_s)
            }
          ) do
            block.call
          end
        rescue Exception => e
          OopsieExceptions.report(e, context: { namespace: "background_job" }, handled: false)
          raise
        end
      end
    end

    initializer "oopsie_exceptions.error_subscriber", after: :load_config_initializers do
      if Rails.respond_to?(:error) && OopsieExceptions.configuration.enabled
        Rails.error.subscribe(OopsieExceptions::ErrorSubscriber.new)
      end
    end
  end
end
