# frozen_string_literal: true

RSpec.describe Authentik::ApiProxy do
  # A simple stand-in for a generated API class.
  let(:fake_api_class) do
    Class.new do
      def prefix_method_a(opts = {}) = "called prefix_method_a"

      def prefix_method_b(id, opts = {}) = "called prefix_method_b with #{id}"

      def unprefixed_method = "called unprefixed_method"
    end
  end

  let(:api_instance) { fake_api_class.new }
  let(:proxy) { described_class.new(api_instance, "prefix_") }

  describe "#method_missing / method forwarding" do
    it "calls the prefixed method on the underlying API when found" do
      expect(proxy.method_a).to eq("called prefix_method_a")
    end

    it "passes arguments through to the prefixed method" do
      expect(proxy.method_b("my-id")).to eq("called prefix_method_b with my-id")
    end

    it "calls the method directly when the prefixed version does not exist" do
      expect(proxy.unprefixed_method).to eq("called unprefixed_method")
    end

    it "raises NoMethodError when neither prefix nor direct method exists" do
      expect { proxy.nonexistent }.to raise_error(NoMethodError)
    end

    it "does not double-prefix a name that already starts with the prefix" do
      expect(proxy.prefix_method_a).to eq("called prefix_method_a")
    end

    it "forwards blocks to the underlying method" do
      block_received = nil
      fake_api_class.define_method(:prefix_block_method) { |&blk| block_received = blk.call }
      proxy.block_method { "block result" }
      expect(block_received).to eq("block result")
    end
  end

  describe "#respond_to?" do
    it "returns true for a method available with the prefix" do
      expect(proxy).to respond_to(:method_a)
    end

    it "returns true for a method available without the prefix" do
      expect(proxy).to respond_to(:unprefixed_method)
    end

    it "returns true for a method whose name already includes the prefix" do
      expect(proxy).to respond_to(:prefix_method_a)
    end

    it "returns false for an unknown method" do
      expect(proxy).not_to respond_to(:nonexistent)
    end
  end
end
