# frozen_string_literal: true

module OopsieExceptions
  class Payload
    MAX_CAUSE_DEPTH = 10

    class << self
      def build(exception, context: {}, handled: true)
        config = OopsieExceptions.configuration
        backtrace = clean_backtrace(exception, config)

        {
          notifier: "OopsieExceptions",
          version: VERSION,
          timestamp: Time.now.utc.iso8601(3),
          app: {
            name: config.app_name,
            environment: config.environment
          },
          error: {
            class_name: exception.class.name,
            message: exception.message.to_s[0, 10_000],
            backtrace: backtrace,
            first_line: parse_backtrace_line(backtrace&.first),
            causes: collect_causes(exception),
            handled: handled
          },
          context: Context.current.merge(context),
          server: server_info
        }
      end

      private

      def server_info
        info = {
          hostname: Socket.gethostname,
          pid: Process.pid,
          ruby_version: RUBY_VERSION
        }
        info[:rails_version] = Rails::VERSION::STRING if defined?(Rails::VERSION)
        info
      end

      def clean_backtrace(exception, config)
        bt = exception.backtrace || []
        cleaner = config.backtrace_cleaner || default_cleaner
        cleaner ? cleaner.clean(bt) : bt
      end

      def default_cleaner
        Rails.backtrace_cleaner if defined?(Rails)
      rescue
        nil
      end

      def collect_causes(exception)
        causes = []
        current = exception.cause
        depth = 0

        while current && depth < MAX_CAUSE_DEPTH
          causes << {
            class_name: current.class.name,
            message: current.message.to_s[0, 1_000],
            first_line: parse_backtrace_line(current.backtrace&.first)
          }
          current = current.cause
          depth += 1
        end

        causes
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
