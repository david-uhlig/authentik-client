# frozen_string_literal: true

require "rails/railtie"
require "authentik/client"

module Authentik
  class Client
    # Railtie integrates authentik-client with Ruby on Rails. It is
    # automatically loaded when Rails is present, so no manual require is
    # needed.
    #
    # Exposes +config.authentik_client+ so the client can be configured
    # directly from Rails configuration files (e.g., +config/application.rb+
    # or environment files). +config.authentik_client+ is the same
    # {Authentik::Client::Configuration} instance returned by
    # {Authentik::Client.configuration}, so both styles are always in sync.
    #
    # @example config/application.rb
    #   config.authentik_client.host  = "authentik.example.com"
    #   config.authentik_client.token = ENV["AUTHENTIK_TOKEN"]
    #
    # @example config/environments/production.rb
    #   config.authentik_client.verify_ssl = true
    #
    # @example config/initializers/authentik_client.rb (traditional style, still works)
    #   Authentik::Client.configure do |config|
    #     config.host  = "authentik.example.com"
    #     config.token = ENV["AUTHENTIK_TOKEN"]
    #   end
    class Railtie < Rails::Railtie
      config.authentik_client = Authentik::Client.configuration

      initializer "authentik_client.after_logger_initialization", after: :initialize_logger do
        config.authentik_client.logger ||= Rails.logger
      end
    end
  end
end
