# frozen_string_literal: true

module OopsieExceptions
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an OopsieExceptions initializer"

      def create_initializer
        template "initializer.rb", "config/initializers/oopsie_exceptions.rb"
      end

      def remove_legacy_delivery_job
        legacy_path = "app/jobs/oopsie_exceptions/delivery_job.rb"
        return unless File.exist?(File.join(destination_root, legacy_path))

        say ""
        say "Found legacy #{legacy_path} from a previous version.", :yellow
        say "The gem now ships its own webhook job — this file is no longer used."
        remove_file legacy_path
      end

      def show_post_install
        say ""
        say "OopsieExceptions installed!", :green
        say ""
        say "Next step: edit config/initializers/oopsie_exceptions.rb and add your webhook URLs."
        say ""
      end
    end
  end
end
