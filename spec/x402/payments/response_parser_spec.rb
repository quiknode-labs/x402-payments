# frozen_string_literal: true

require "spec_helper"
require "base64"
require "json"

RSpec.describe X402::Payments::ResponseParser do
  let(:v1_response_body) do
    {
      "x402Version" => 1,
      "error" => "X-PAYMENT header is required",
      "accepts" => [
        {
          "scheme" => "exact",
          "network" => "base-sepolia",
          "maxAmountRequired" => "10000",
          "asset" => "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
          "payTo" => "0x209693Bc6afc0C5328bA36FaF03C514EF312287C",
          "resource" => "https://api.example.com/premium-data",
          "description" => "Access to premium market data",
          "mimeType" => "application/json",
          "maxTimeoutSeconds" => 60,
          "extra" => { "name" => "USDC", "version" => "2" }
        }
      ]
    }
  end

  let(:v2_payment_required) do
    {
      "x402Version" => 2,
      "error" => "PAYMENT-SIGNATURE header is required",
      "resource" => {
        "url" => "https://api.example.com/premium-data",
        "description" => "Access to premium market data",
        "mimeType" => "application/json"
      },
      "accepts" => [
        {
          "scheme" => "exact",
          "network" => "eip155:84532",
          "amount" => "10000",
          "asset" => "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
          "payTo" => "0x209693Bc6afc0C5328bA36FaF03C514EF312287C",
          "maxTimeoutSeconds" => 60,
          "extra" => { "name" => "USDC", "version" => "2" }
        }
      ],
      "extensions" => {}
    }
  end

  describe ".detect_version" do
    context "with v1 response" do
      let(:response) do
        double(
          body: v1_response_body.to_json,
          headers: {}
        )
      end

      it "detects v1 from body x402Version" do
        expect(described_class.detect_version(response)).to eq(1)
      end
    end

    context "with v2 response" do
      let(:v2_header) { Base64.strict_encode64(v2_payment_required.to_json) }
      let(:response) do
        double(
          body: '{"error": "Payment required"}',
          headers: { "PAYMENT-REQUIRED" => v2_header }
        )
      end

      it "detects v2 from PAYMENT-REQUIRED header" do
        expect(described_class.detect_version(response)).to eq(2)
      end
    end

    context "with no version info" do
      let(:response) do
        double(
          body: '{}',
          headers: {}
        )
      end

      it "defaults to v1" do
        expect(described_class.detect_version(response)).to eq(1)
      end
    end
  end

  describe ".parse" do
    context "with v1 response" do
      let(:response) do
        double(
          body: v1_response_body.to_json,
          headers: {}
        )
      end

      it "parses and normalizes v1 response" do
        result = described_class.parse(response)

        expect(result[:version]).to eq(1)
        expect(result[:error]).to eq("X-PAYMENT header is required")
        expect(result[:resource][:url]).to eq("https://api.example.com/premium-data")
        expect(result[:accepts].first[:scheme]).to eq("exact")
        expect(result[:accepts].first[:network]).to eq("base-sepolia")
        expect(result[:accepts].first[:amount]).to eq("10000")
        expect(result[:accepts].first[:pay_to]).to eq("0x209693Bc6afc0C5328bA36FaF03C514EF312287C")
      end
    end

    context "with v2 response" do
      let(:v2_header) { Base64.strict_encode64(v2_payment_required.to_json) }
      let(:response) do
        double(
          body: '{"error": "Payment required"}',
          headers: { "PAYMENT-REQUIRED" => v2_header }
        )
      end

      it "parses and normalizes v2 response" do
        result = described_class.parse(response)

        expect(result[:version]).to eq(2)
        expect(result[:error]).to eq("PAYMENT-SIGNATURE header is required")
        expect(result[:resource][:url]).to eq("https://api.example.com/premium-data")
        expect(result[:accepts].first[:scheme]).to eq("exact")
        expect(result[:accepts].first[:network]).to eq("eip155:84532")
        expect(result[:accepts].first[:amount]).to eq("10000")
        expect(result[:accepts].first[:pay_to]).to eq("0x209693Bc6afc0C5328bA36FaF03C514EF312287C")
        expect(result[:extensions]).to eq({})
      end
    end

    context "with hash response" do
      let(:response) do
        {
          body: v1_response_body.to_json,
          headers: {}
        }
      end

      it "handles hash responses" do
        result = described_class.parse(response)
        expect(result[:version]).to eq(1)
      end
    end

    context "with invalid v2 header" do
      let(:response) do
        double(
          body: '{}',
          headers: { "PAYMENT-REQUIRED" => "invalid-base64!!!" }
        )
      end

      it "raises ParseError" do
        expect { described_class.parse(response) }.to raise_error(X402::Payments::ResponseParser::ParseError)
      end
    end
  end
end
