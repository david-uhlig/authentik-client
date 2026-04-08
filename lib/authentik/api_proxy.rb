# frozen_string_literal: true

module Authentik
  # ApiProxy wraps an auto-generated OpenAPI API class and forwards method calls
  # to it, stripping the redundant API group prefix from method names.
  #
  # For example, when accessed via +client.core+, the prefix +"core_"+ is
  # stripped, so +client.core.applications_list+ calls
  # +CoreApi#core_applications_list+.
  #
  # @api private
  class ApiProxy
    # @param api_instance [Object] The underlying OpenAPI API class instance
    # @param prefix [String] The method prefix to strip (e.g., +"core_"+)
    def initialize(api_instance, prefix)
      @api = api_instance
      @prefix = prefix
    end

    # Forwards method calls to the underlying API instance.
    # First tries with the prefix prepended (unless already prefixed), then without.
    def method_missing(name, *args, **kwargs, &block)
      prefixed = name.to_s.start_with?(@prefix) ? name : :"#{@prefix}#{name}"
      if @api.respond_to?(prefixed)
        @api.send(prefixed, *args, **kwargs, &block)
      elsif @api.respond_to?(name)
        @api.send(name, *args, **kwargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      prefixed = name.to_s.start_with?(@prefix) ? name : :"#{@prefix}#{name}"
      @api.respond_to?(prefixed) ||
        @api.respond_to?(name) ||
        super
    end
  end
end
