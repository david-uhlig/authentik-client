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

  describe "endpoint access" do
    it "dispatches known endpoints to their generated API class" do
      fake_core_api = double("fake_core_api")
      allow(fake_core_api).to receive(:core_users_list).and_return(:ok)
      allow(Authentik::Api::CoreApi).to receive(:new).and_return(fake_core_api)

      expect(client.core_users_list).to eq(:ok)
    end

    it "reuses the same API class instance for repeated calls in the same group" do
      fake_core_api = double("fake_core_api", core_users_list: :users, core_groups_list: :groups)
      allow(Authentik::Api::CoreApi).to receive(:new).and_return(fake_core_api)

      expect(client.core_users_list).to eq(:users)
      expect(client.core_groups_list).to eq(:groups)
      expect(Authentik::Api::CoreApi).to have_received(:new).once
    end

    it "responds to every discovered endpoint" do
      described_class.endpoints.each do |endpoint|
        expect(client).to respond_to(endpoint), "expected client to respond to :#{endpoint}"
      end
    end

    it "raises NoMethodError for unknown endpoints" do
      expect { client.nonexistent_endpoint }.to raise_error(NoMethodError)
    end

    it "exposes API groups" do
      expect(client).to respond_to(:core)
    end
  end

  describe "API discovery helpers" do
    describe ".group?" do
      it "accepts symbols and strings case-insensitively" do
        expect(described_class.group?(:core)).to be(true)
        expect(described_class.group?("CORE")).to be(true)
        expect(described_class.group?("missing")).to be(false)
      end
    end

    describe ".resources and .resource?" do
      before do
        described_class.remove_instance_variable(:@resources) if described_class.instance_variable_defined?(:@resources)
        allow(described_class).to receive(:endpoints).and_return(
          %i[
            core_users_list
            core_users_retrieve
            core_users_list_with_http_info
            admin_version_retrieve
            admin_version_retrieve_with_http_info
          ]
        )
      end

      it "normalizes endpoint names to unique resource names" do
        expect(described_class.resources).to match_array(%i[core_users admin_version])
      end

      it "checks resource existence by symbol or string" do
        expect(described_class.resource?(:core_users)).to be(true)
        expect(described_class.resource?("admin_version")).to be(true)
        expect(described_class.resource?("core_groups")).to be(false)
      end
    end

    describe ".endpoints" do
      it "includes only methods matching each API group prefix" do
        described_class.remove_instance_variable(:@endpoint_group_map) if described_class.instance_variable_defined?(:@endpoint_group_map)

        fake_api_map = {
          fake: Class.new do
            def fake_users_list = nil
            def fake_groups_retrieve = nil
            def not_fake_method = nil
          end
        }

        allow(described_class).to receive(:group_api_class_map).and_return(fake_api_map)

        expect(described_class.endpoints).to match_array(%i[fake_users_list fake_groups_retrieve])
      end
    end
  end
end
