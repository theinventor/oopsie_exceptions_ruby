# frozen_string_literal: true

module OopsieExceptions
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Context.clear

      begin
        request_context = Context.from_rack_env(env)
        Context.merge(request_context)

        response = @app.call(env)

        if response[0].to_i >= 500
          Context.merge(response_status: response[0].to_i)
        end

        response
      rescue Exception => exception
        Context.merge(response_status: 500)
        OopsieExceptions.report(exception, handled: false)
        raise
      ensure
        Context.clear
      end
    end
  end
end
