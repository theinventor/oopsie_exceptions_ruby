# frozen_string_literal: true

module OopsieExceptions
  class ErrorSubscriber
    def report(error, handled:, severity:, context: {}, source: nil)
      return if severity == :warning

      merged_context = context.merge(
        rails_error_reporter: true,
        severity: severity.to_s,
        source: source
      ).compact

      OopsieExceptions.report(error, context: merged_context, handled: handled)
    end
  end
end
