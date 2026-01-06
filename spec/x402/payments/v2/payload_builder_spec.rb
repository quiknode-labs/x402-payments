# frozen_string_literal: true

require "spec_helper"

RSpec.describe X402::Payments::V2::PayloadBuilder do
  let(:authorization) do
    {
      from: "0x857b06519E91e3A54538791bDbb0E22373e36b66",
      to: "0x209693Bc6afc0C5328bA36FaF03C514EF312287C",
      value: "10000",
      valid_after: "1740672089",
      valid_before: "1740672154",
      nonce: "0xf3746613c2d920b5fdabc0856f2aeb2d4f88ee6037b8cc5d04a71a4462f13480"
    }
  end

  let(:signature) { "0x2d6a7588d6acca505cbf0d9a4a227e0c52c6c34008c8e8986a1283259764173608a2ce6496642e377d6da8dbbf5836e9bd15092f9ecab05ded3d6293af148b571c" }

  let(:resource) do
    {
      url: "https://api.example.com/premium-data",
      description: "Access to premium market data",
      mime_type: "application/json"
    }
  end

  let(:accepted) do
    {
      scheme: "exact",
      network: "eip155:84532",
      amount: "10000",
      asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      pay_to: "0x209693Bc6afc0C5328bA36FaF03C514EF312287C",
      max_timeout_seconds: 60,
      extra: { name: "USDC", version: "2" }
    }
  end

  describe ".build" do
    it "builds a valid v2 payload structure" do
      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        resource: resource,
        accepted: accepted
      )

      expect(payload[:x402Version]).to eq(2)
      expect(payload[:payload][:signature]).to eq(signature)
      expect(payload[:extensions]).to eq({})
    end

    it "builds resource object correctly" do
      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        resource: resource,
        accepted: accepted
      )

      expect(payload[:resource][:url]).to eq("https://api.example.com/premium-data")
      expect(payload[:resource][:description]).to eq("Access to premium market data")
      expect(payload[:resource][:mimeType]).to eq("application/json")
    end

    it "builds accepted object correctly" do
      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        resource: resource,
        accepted: accepted
      )

      expect(payload[:accepted][:scheme]).to eq("exact")
      expect(payload[:accepted][:network]).to eq("eip155:84532")
      expect(payload[:accepted][:amount]).to eq("10000")
      expect(payload[:accepted][:asset]).to eq("0x036CbD53842c5426634e7929541eC2318f3dCF7e")
      expect(payload[:accepted][:payTo]).to eq("0x209693Bc6afc0C5328bA36FaF03C514EF312287C")
      expect(payload[:accepted][:maxTimeoutSeconds]).to eq(60)
    end

    it "includes authorization with correct field casing" do
      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        resource: resource,
        accepted: accepted
      )

      auth = payload[:payload][:authorization]
      expect(auth[:from]).to eq(authorization[:from])
      expect(auth[:to]).to eq(authorization[:to])
      expect(auth[:value]).to eq(authorization[:value])
      expect(auth[:validAfter]).to eq(authorization[:valid_after])
      expect(auth[:validBefore]).to eq(authorization[:valid_before])
      expect(auth[:nonce]).to eq(authorization[:nonce])
    end

    it "supports custom extensions" do
      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        resource: resource,
        accepted: accepted,
        extensions: { "custom" => { "key" => "value" } }
      )

      expect(payload[:extensions]).to eq({ "custom" => { "key" => "value" } })
    end

    it "defaults mimeType to application/json when not provided" do
      resource_without_mime = resource.dup
      resource_without_mime.delete(:mime_type)

      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        resource: resource_without_mime,
        accepted: accepted
      )

      expect(payload[:resource][:mimeType]).to eq("application/json")
    end
  end

  describe "#build" do
    it "works via instance method" do
      builder = described_class.new(
        authorization: authorization,
        signature: signature,
        resource: resource,
        accepted: accepted
      )

      payload = builder.build
      expect(payload[:x402Version]).to eq(2)
    end
  end
end
