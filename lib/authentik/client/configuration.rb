# frozen_string_literal: true

module Authentik
  class Client
    # Global configuration for {Authentik::Client}. Subclasses
    # {Authentik::Api::Configuration} so all underlying API settings
    # (e.g., +verify_ssl+, +timeout+, +debugging+) are available directly.
    # Adds a +token+ accessor as a friendlier alias for +access_token+.
    #
    # Use {Authentik::Client.configure} to set configuration at startup.
    #
    # @example Configure at startup (e.g., in a Rails initializer)
    #   Authentik::Client.configure do |config|
    #     config.host  = "authentik.example.com"
    #     config.token = "your-api-token"
    #   end
    class Configuration < Authentik::Api::Configuration
      attr_writer :logger

      def initialize
        super
        # Override parent defaults: host is intentionally nil until the user
        # sets it, so Client can detect when it has not been configured.
        @host = nil
        @scheme = "https"
      end

      # @return [String, nil] The API bearer token for authentication. Alias for +access_token+.
      def token
        access_token
      end

      # @param value [String, nil]
      def token=(value)
        self.access_token = value
      end
    end
  end
end
