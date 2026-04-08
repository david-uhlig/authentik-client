# frozen_string_literal: true

require "authentik/api"
require "logger"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem_extension(Authentik)
loader.ignore("#{__dir__}/client/railtie.rb")
loader.setup

module Authentik
  # Client provides a Ruby interface to the authentik API. It wraps the
  # auto-generated OpenAPI client and organizes API calls into groups that
  # correspond to the underlying API classes.
  #
  # API groups are accessed as methods on the client. Each group returns an
  # {ApiProxy} that forwards method calls to the corresponding OpenAPI API
  # class, stripping the redundant API group prefix for brevity.
  #
  # New API groups added to the underlying OpenAPI client are automatically
  # discovered and available without changes to this class.
  #
  # @example Configure at startup and create a client
  #   Authentik::Client.configure do |config|
  #     config.host = "authentik.example.com"
  #     config.token = "your-api-token"
  #   end
  #
  #   client = Authentik::Client.new
  #
  # @example Create a client with inline options
  #   client = Authentik::Client.new(
  #     host: "authentik.example.com",
  #     token: "your-api-token"
  #   )
  #
  # @example List all applications
  #   client.core.applications_list
  #
  # @example Get the admin version
  #   client.admin.version_retrieve
  #
  # @example List OAuth2 access tokens
  #   client.oauth2.access_tokens_list
  class Client
    # Yields the global {Configuration} object so that settings can be applied
    # at startup (e.g., in a Rails initializer).
    #
    # @example
    #   Authentik::Client.configure do |config|
    #     config.host  = "authentik.example.com"
    #     config.token = "your-api-token"
    #   end
    #
    # @yieldparam config [Configuration]
    def self.configure
      yield(configuration)
    end

    # Returns the global {Configuration} instance, creating it on first call.
    #
    # @return [Configuration]
    def self.configuration
      @configuration ||= Configuration.new
    end

    # Resets the global configuration to a fresh {Configuration} instance.
    #
    # @return [Configuration]
    def self.reset_configuration!
      @configuration = Configuration.new
    end

    # @param host [String, nil] The authentik server hostname
    #   (e.g., +"authentik.example.com"+). Falls back to the value set in
    #   {.configuration} when not provided.
    # @param token [String, nil] The API bearer token for authentication.
    #   Falls back to the value set in {.configuration} when not provided.
    # @param scheme [String, nil] The URL scheme (+"https"+ or +"http"+).
    #   Falls back to the value set in {.configuration}, which defaults to
    #   +"https"+.
    # @param options [Hash] Additional per-instance options forwarded to
    #   +Authentik::Api::Configuration+ (e.g., +verify_ssl: false+,
    #   +timeout: 60+). Take precedence over values set in {.configuration}.
    # @raise [ArgumentError] if +host+ is not provided here or in the global
    #   configuration
    # @raise [ArgumentError] if +token+ is not provided here or in the global
    #   configuration
    def initialize(host: nil, token: nil, scheme: nil, **options)
      cfg = self.class.configuration
      resolved_host = host || cfg.host
      resolved_token = token || cfg.access_token
      resolved_scheme = scheme || cfg.scheme

      raise ArgumentError, "host is required" if resolved_host.nil?
      raise ArgumentError, "token is required" if resolved_token.nil?

      @api_client = build_api_client(
        cfg,
        host: resolved_host,
        token: resolved_token,
        scheme: resolved_scheme,
        **options
      )
      @api_instances = {}
    end

    # Provides access to an API group by name. Returns an {ApiProxy} that
    # wraps the corresponding OpenAPI API class instance.
    #
    # The method name is the API class name (without the +"Api"+ suffix)
    # in lowercase. For example, +:core+ maps to +CoreApi+, +:admin+ to
    # +AdminApi+, and +:oauth2+ to +OAuth2Api+.
    #
    # @return [ApiProxy] A proxy wrapping the underlying API class instance
    # @raise [NoMethodError] if the name does not match any known API group
    def method_missing(name, ...)
      api_info = self.class.api_map[name]
      return super unless api_info

      @api_instances[name] ||= ApiProxy.new(api_info[:klass].new(@api_client), api_info[:prefix])
    end

    def respond_to_missing?(name, include_private = false)
      self.class.api_map.key?(name) || super
    end

    # Returns a hash mapping API group name symbols to their API class and
    # prefix. Automatically discovers all classes in +Authentik::Api+
    # that end with +"Api"+.
    #
    # @return [Hash{Symbol => Hash}]
    def self.api_map
      @api_map ||= Authentik::Api.constants
        .select { |c| c.to_s.end_with?("Api") }
        .filter_map do |c|
          klass = Authentik::Api.const_get(c)
          next unless klass.is_a?(Class)

          base = c.to_s.delete_suffix("Api").downcase
          [base.to_sym, {klass: klass, prefix: "#{base}_"}]
      end
        .to_h
    end

    private

    def build_api_client(base_config, host:, token:, scheme:, **options)
      config = base_config.dup
      config.host = host
      config.access_token = token
      config.scheme = scheme
      options.each { |k, v| config.public_send(:"#{k}=", v) if config.respond_to?(:"#{k}=") }
      Authentik::Api::ApiClient.new(config)
    end
  end
end

require "authentik/client/railtie" if defined?(Rails::Railtie)
