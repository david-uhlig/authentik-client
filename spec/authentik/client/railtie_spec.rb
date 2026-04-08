# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/module/delegation"
require "rails/railtie"

# Provide a minimal Rails.logger stub so the vendored authentik-api
# configuration (which checks `defined?(Rails)`) does not raise NoMethodError
# when Rails is only partially loaded in tests.
module Rails
  def self.logger
    @logger ||= Logger.new(nil)
  end
end

require "authentik/client/railtie"

RSpec.describe Authentik::Client::Railtie do
  it "is a subclass of Rails::Railtie" do
    expect(described_class.superclass).to eq(Rails::Railtie)
  end

  it "is registered with Rails" do
    expect(Rails::Railtie.subclasses).to include(described_class)
  end

  describe "config.authentik_client" do
    before do
      Authentik::Client.reset_configuration!
      described_class.config.authentik_client = Authentik::Client.configuration
    end

    after do
      Authentik::Client.reset_configuration!
      described_class.config.authentik_client = Authentik::Client.configuration
    end

    it "exposes Authentik::Client.configuration as config.authentik_client" do
      expect(described_class.config.authentik_client).to be(Authentik::Client.configuration)
    end

    it "allows setting host via config.authentik_client" do
      described_class.config.authentik_client.host = "rails-config.example.com"
      expect(Authentik::Client.configuration.host).to eq("rails-config.example.com")
    end

    it "allows setting token via config.authentik_client" do
      described_class.config.authentik_client.token = "rails-token"
      expect(Authentik::Client.configuration.token).to eq("rails-token")
    end
  end
end
