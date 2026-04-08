# frozen_string_literal: true

RSpec.describe Authentik::Client do
  subject(:client) do
    described_class.new(
      host: "authentik.example.com",
      token: "test-token"
    )
  end

  before do
    described_class.reset_configuration!
  end

  describe ".configure" do
    it "yields the global configuration object" do
      expect { |b| described_class.configure(&b) }
        .to yield_with_args(instance_of(Authentik::Client::Configuration))
    end

    it "sets host on the global configuration" do
      described_class.configure { |c| c.host = "configured.example.com" }
      expect(described_class.configuration.host).to eq("configured.example.com")
    end

    it "sets token on the global configuration" do
      described_class.configure { |c| c.token = "global-token" }
      expect(described_class.configuration.token).to eq("global-token")
    end

    it "sets scheme on the global configuration" do
      described_class.configure { |c| c.scheme = "http" }
      expect(described_class.configuration.scheme).to eq("http")
    end

    it "sets verify_ssl on the global configuration" do
      described_class.configure { |c| c.verify_ssl = false }
      expect(described_class.configuration.verify_ssl).to be(false)
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(Authentik::Client::Configuration)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.configuration).to equal(described_class.configuration)
    end

    it "defaults scheme to https" do
      expect(described_class.configuration.scheme).to eq("https")
    end
  end

  describe ".reset_configuration!" do
    it "replaces the configuration with a fresh instance" do
      original = described_class.configuration
      described_class.configure { |c| c.host = "example.com" }
      described_class.reset_configuration!
      expect(described_class.configuration).not_to equal(original)
      expect(described_class.configuration.host).to be_nil
    end
  end

  describe "#initialize" do
    it "creates a client with host and token" do
      expect(client).to be_a(described_class)
    end

    it "accepts additional configuration options" do
      expect {
        described_class.new(
          host: "authentik.example.com",
          token: "test-token",
          verify_ssl: false,
          timeout: 60
        )
      }.not_to raise_error
    end

    it "uses global configuration when no arguments are passed" do
      described_class.configure do |config|
        config.host = "global.example.com"
        config.token = "global-token"
      end
      expect { described_class.new }.not_to raise_error
    end

    it "allows per-instance arguments to override global configuration" do
      described_class.configure do |config|
        config.host = "global.example.com"
        config.token = "global-token"
      end
      expect {
        described_class.new(host: "override.example.com", token: "override-token")
      }.not_to raise_error
    end

    it "propagates global configuration options to the underlying API client" do
      described_class.configure do |config|
        config.host = "authentik.example.com"
        config.token = "test-token"
        config.timeout = 30
      end
      expect {
        described_class.new(verify_ssl: false)
      }.not_to raise_error
    end

    it "raises ArgumentError when host is missing from both arguments and global config" do
      expect {
        described_class.new(token: "test-token")
      }.to raise_error(ArgumentError, /host is required/)
    end

    it "raises ArgumentError when token is missing from both arguments and global config" do
      expect {
        described_class.new(host: "authentik.example.com")
      }.to raise_error(ArgumentError, /token is required/)
    end

    it "raises ArgumentError when called without arguments and no global config is set" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  describe "API group access" do
    it "returns an ApiProxy for a known API group" do
      expect(client.core).to be_a(Authentik::ApiProxy)
    end

    it "returns the same instance on repeated access" do
      expect(client.core).to equal(client.core)
    end

    it "responds to all expected API group names" do
      %i[admin authenticators core crypto enterprise events flows managed
        oauth2 outposts policies propertymappings providers rac rbac root
        schema sources ssf stages tasks tenants].each do |group|
        expect(client).to respond_to(group), "expected client to respond to :#{group}"
      end
    end

    it "raises NoMethodError for unknown API groups" do
      expect { client.nonexistent_api }.to raise_error(NoMethodError)
    end

    it "does not respond to unknown API group names" do
      expect(client).not_to respond_to(:nonexistent_api)
    end
  end

  describe ".api_map" do
    subject(:api_map) { described_class.api_map }

    it "contains known API groups" do
      expect(api_map.keys).to include(:core, :admin, :oauth2, :propertymappings)
    end

    it "maps group names to the correct API classes" do
      expect(api_map[:core][:klass]).to eq(Authentik::Api::CoreApi)
      expect(api_map[:admin][:klass]).to eq(Authentik::Api::AdminApi)
      expect(api_map[:oauth2][:klass]).to eq(Authentik::Api::Oauth2Api)
    end

    it "sets the correct prefix for each group" do
      expect(api_map[:core][:prefix]).to eq("core_")
      expect(api_map[:admin][:prefix]).to eq("admin_")
      expect(api_map[:oauth2][:prefix]).to eq("oauth2_")
      expect(api_map[:propertymappings][:prefix]).to eq("propertymappings_")
    end
  end
end
