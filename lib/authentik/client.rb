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
  # API endpoints are accessed directly as methods on the client. The client
  # resolves the endpoint prefix (for example, +core_+ or +admin_+) to the
  # corresponding auto-generated OpenAPI API class.
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
  #   client.core_applications_list
  #
  # @example Get the admin version
  #   client.admin_version_retrieve
  #
  # @example List OAuth2 access tokens
  #   client.oauth2_access_tokens_list
  class Client
    RESOURCE_ACTIONS = %w[list retrieve create update partial_update destroy].freeze

    class NoEndpointError < NoMethodError; end

    class << self
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
      def configure
        yield(configuration)
      end

      # Returns the global {Configuration} instance, creating it on the first call.
      #
      # @return [Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # Resets the global configuration to a fresh {Configuration} instance.
      #
      # @return [Configuration]
      def reset_configuration!
        @configuration = Configuration.new
      end

      # Returns true if `name` is an API group.
      #
      # @param name [String, Symbol] Group name identifier, e.g., `core`.
      # @return [Boolean] True if an API group of `name` exists.
      def group?(name)
        groups.include?(name.downcase.to_sym)
      end

      # Returns all known API groups.
      #
      # @return [Array<Symbol>]
      def groups
        group_api_class_map.keys
      end

      # Returns true if `name` is a known resource.
      #
      # A resource is a collection of API endpoints that share a common prefix.
      # For example, `:core_users` is the resource for `:core_users_list`,
      # `:core_users_retrieve`, etc.
      #
      # @param name [String, Symbol] Resource name identifier, e.g., `core_users`
      # @return [Boolean] True if a resource of `name` exists.
      def resource?(name)
        resources.include?(name.to_sym)
      end

      # Returns all known API resources.
      def resources
        @resources ||= begin
          remove_action_regexp = /(.*?)(_(#{RESOURCE_ACTIONS.join("|")}))?(_with_http_info)?$/
          endpoints
            .map { |endpoint| endpoint.to_s.gsub(remove_action_regexp, '\1').to_sym }
            .uniq
        end
      end

      # Returns true if `name` is a known endpoint.
      #
      # @param name [String, Symbol] Endpoint name identifier, e.g., `core_users_list`.
      # @return [Boolean] True if `name` is a known endpoint.
      def endpoint?(name)
        endpoints.include?(name.to_sym)
      end

      # Returns all known API endpoints.
      #
      # @return [Array<Symbol>]
      def endpoints
        endpoint_group_map.keys
      end

      # Returns the API group for a given endpoint.
      #
      # @param name [String, Symbol] Endpoint name identifier, e.g., `core_users_list`.
      # @return [Symbol, nil] The API group for the endpoint, or nil if not found.
      def group_by_endpoint(name)
        endpoint_group_map[name.to_sym]
      end

      # Returns the API class for a given API group.
      #
      # @param name [String, Symbol] API group name, e.g., `core`.
      # @raise [KeyError] if the group is not known.
      # @return [Class] The API class for the group.
      def fetch_api_class_by_group(name)
        group_api_class_map.fetch(name.to_sym)
      end

      private

      def endpoint_group_map
        @endpoint_group_map ||= group_api_class_map.each_with_object({}) do |(group, api_class), map|
          group_prefix = "#{group}_"
          api_class.public_instance_methods(false).each do |method_name|
            next unless method_name.start_with?(group_prefix)
            map[method_name] = group
          end
        end
      end

      # Returns a hash mapping API group name to API class.
      #
      # Automatically discovers all classes in +Authentik::Api+ that end in
      # +"Api"+.
      #
      # @return [Hash{Symbol => Class}]
      def group_api_class_map
        @group_api_class_map ||= Authentik::Api.constants
          .select { |c| c.to_s.end_with?("Api") }
          .filter_map do |c|
            klass = Authentik::Api.const_get(c)
            next unless klass.is_a?(Class)

            base = c.to_s.delete_suffix("Api").downcase
            [base.to_sym, klass]
        end
          .to_h
      end
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

    # Dispatches endpoint calls directly to the corresponding generated API
    # group instance, resolved by the endpoint prefix.
    def method_missing(name, ...)
      if self.class.endpoint?(name)
        group = self.class.group_by_endpoint(name)
        api_group_instance(group).public_send(name, ...)
      elsif self.class.group?(name)
        api_group_instance(name)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      self.class.group?(name) || self.class.endpoint?(name) || super
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

    def api_group_instance(group)
      api_class = self.class.fetch_api_class_by_group(group)
      @api_instances[group] ||= api_class.new(@api_client)
    end
  end
end

require "authentik/client/railtie" if defined?(Rails::Railtie)
