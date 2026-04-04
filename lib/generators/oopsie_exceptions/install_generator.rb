# frozen_string_literal: true

module OopsieExceptions
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an OopsieExceptions initializer and delivery job"

      def create_initializer
        template "initializer.rb", "config/initializers/oopsie_exceptions.rb"
      end

      def create_delivery_job
        template "delivery_job.rb", "app/jobs/oopsie_exceptions/delivery_job.rb"
      end

      def show_post_install
        say ""
        say "OopsieExceptions installed!", :green
        say ""
        say "Next steps:"
        say "  1. Edit config/initializers/oopsie_exceptions.rb to add your webhook URLs"
        say "  2. Optionally add user context in ApplicationController:"
        say ""
        say "     before_action :set_oopsie_context"
        say ""
        say "     def set_oopsie_context"
        say "       OopsieExceptions.set_context("
        say "         user: current_user ? { id: current_user.id, email: current_user.email } : nil,"
        say "         action: \"\#{self.class.name}#\#{action_name}\""
        say "       )"
        say "     end"
        say ""
      end
    end
  end
end
