# frozen_string_literal: true

module OopsieExceptions
  class ExceptionNormalizer
    RETRY_WRAPPER_CLASS_NAMES = %w[
      Sidekiq::JobRetry::Handled
    ].freeze

    Result = Struct.new(:exception, :context, :wrappers, keyword_init: true)

    class << self
      def normalize(exception, context:)
        wrappers = collect_retry_wrappers(exception)
        return Result.new(exception: exception, context: context, wrappers: []) if wrappers.empty?

        Result.new(
          exception: wrappers.last.cause,
          context: merge_wrapper_context(context, wrappers, wrappers.last.cause),
          wrappers: wrappers
        )
      end

      private

      def collect_retry_wrappers(exception)
        wrappers = []
        current = exception
        seen = {}

        while retry_wrapper?(current) && current.cause && !seen[current.__id__]
          seen[current.__id__] = true
          wrappers << current
          current = current.cause
        end

        wrappers
      end

      def retry_wrapper?(exception)
        RETRY_WRAPPER_CLASS_NAMES.include?(exception.class.name)
      end

      def merge_wrapper_context(context, wrappers, normalized_exception)
        merged_context = context.dup
        metadata = wrappers.map do |wrapper|
          wrapper_metadata(wrapper, normalized_exception, context)
        end

        if merged_context.key?(:exception_wrapper) || merged_context.key?("exception_wrapper")
          merged_context[:oopsie_exception_wrapper] = metadata.first
        else
          merged_context[:exception_wrapper] = metadata.first
        end

        merged_context[:exception_wrappers] = metadata if metadata.length > 1
        merged_context
      end

      def wrapper_metadata(wrapper, normalized_exception, context)
        metadata = {
          class_name: wrapper.class.name,
          message: wrapper.message.to_s[0, 1_000],
          first_line: parse_backtrace_line(wrapper.backtrace&.first),
          normalized_exception: {
            class_name: normalized_exception.class.name,
            message: normalized_exception.message.to_s[0, 1_000]
          }
        }

        source = context[:source] || context["source"]
        metadata[:source] = source if source
        metadata
      end

      def parse_backtrace_line(line)
        return nil unless line

        match = line.match(/\A(.+):(\d+):in [`'](.+)'\z/)
        return { raw: line } unless match

        {
          file: match[1],
          line: match[2].to_i,
          method: match[3]
        }
      end
    end
  end
end
