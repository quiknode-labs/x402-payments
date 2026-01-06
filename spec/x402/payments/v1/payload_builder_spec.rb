# frozen_string_literal: true

require "spec_helper"

RSpec.describe X402::Payments::V1::PayloadBuilder do
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

  describe ".build" do
    it "builds a valid v1 payload structure" do
      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        scheme: "exact",
        network: "base-sepolia"
      )

      expect(payload[:x402Version]).to eq(1)
      expect(payload[:scheme]).to eq("exact")
      expect(payload[:network]).to eq("base-sepolia")
      expect(payload[:payload][:signature]).to eq(signature)
    end

    it "includes authorization fields with correct casing" do
      payload = described_class.build(
        authorization: authorization,
        signature: signature,
        scheme: "exact",
        network: "base-sepolia"
      )

      auth = payload[:payload][:authorization]
      expect(auth[:from]).to eq(authorization[:from])
      expect(auth[:to]).to eq(authorization[:to])
      expect(auth[:value]).to eq(authorization[:value])
      expect(auth[:validAfter]).to eq(authorization[:valid_after])
      expect(auth[:validBefore]).to eq(authorization[:valid_before])
      expect(auth[:nonce]).to eq(authorization[:nonce])
    end
  end

  describe "#build" do
    it "works via instance method" do
      builder = described_class.new(
        authorization: authorization,
        signature: signature,
        scheme: "exact",
        network: "base-sepolia"
      )

      payload = builder.build
      expect(payload[:x402Version]).to eq(1)
    end
  end
end
