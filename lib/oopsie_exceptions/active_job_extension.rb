# frozen_string_literal: true

module OopsieExceptions
  # Class-level extension for ActiveJob::Base. Wraps `execute(job_data)`, the
  # entry point queue adapters call, so we capture every unhandled exception
  # — including ones that fire before `perform` runs (e.g. DeserializationError,
  # or a missing job class).
  #
  # This mirrors how Appsignal hooks ActiveJob (lib/appsignal/hooks/active_job.rb).
  module ActiveJobExtension
    def execute(job_data)
      job_context = {
        job: {
          class: job_data["job_class"],
          job_id: job_data["job_id"],
          queue: job_data["queue_name"],
          arguments: job_data["arguments"],
          executions: job_data["executions"],
          provider_job_id: job_data["provider_job_id"]
        }.compact
      }

      OopsieExceptions.with_context(job_context) do
        super
      rescue Exception => exception
        OopsieExceptions.report(
          exception,
          context: { namespace: "background_job" },
          handled: false
        )
        raise
      end
    end
  end
end
