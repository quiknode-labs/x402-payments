# frozen_string_literal: true

RSpec.describe X402::Payments::Generator do
  let(:test_wallet) { "0xd086Ef8F2c0F9d642120cCf0898BD101b1d18Db6" }
  let(:test_private_key) { "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef" }
  let(:test_resource) { "http://localhost:3000/api/weather" }

  before do
    X402::Payments.configure do |config|
      config.default_pay_to = test_wallet
      config.private_key = test_private_key
      config.chain = "base-sepolia"
      config.max_timeout_seconds = 600
    end
  end

  after do
    X402::Payments.reset_configuration!
  end

  describe "#generate_header" do
    let(:generator) { described_class.new }

    it "generates a base64-encoded payment header" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        description: "Test payment"
      )

      expect(header).to be_a(String)
      expect(header).not_to be_empty

      # Should be valid base64
      decoded = Base64.strict_decode64(header)
      expect(decoded).to be_a(String)
    end

    it "creates valid JSON in the header" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 1
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["x402Version"]).to eq(1)
      expect(json["scheme"]).to eq("exact")
      expect(json["network"]).to eq("base-sepolia")
      expect(json["payload"]).to be_a(Hash)
      expect(json["payload"]["signature"]).to be_a(String)
      expect(json["payload"]["authorization"]).to be_a(Hash)
    end

    it "converts amount to atomic units correctly" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      # 0.001 USD = 1000 atomic units (6 decimals)
      expect(json["payload"]["authorization"]["value"]).to eq("1000")
    end

    it "includes correct authorization fields" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)
      auth = json["payload"]["authorization"]

      expect(auth["from"]).to match(/^0x[a-fA-F0-9]{40}$/)
      expect(auth["to"]).to eq(test_wallet)
      expect(auth["value"]).to eq("1000")
      expect(auth["validAfter"]).to be_a(String)
      expect(auth["validBefore"]).to be_a(String)
      expect(auth["nonce"]).to match(/^0x[a-fA-F0-9]{64}$/)
    end

    it "includes a valid signature" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      signature = json["payload"]["signature"]
      expect(signature).to match(/^0x[a-fA-F0-9]{130}$/)
    end

    it "uses default description when not provided" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource
      )

      # Just verify it doesn't error - description is internal
      expect(header).to be_a(String)
    end

    it "allows overriding network" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        network: "base",
        version: 1
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["network"]).to eq("base")
    end

    it "allows overriding private_key" do
      different_key = "0x1234567890123456789012345678901234567890123456789012345678901234"

      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        private_key: different_key
      )

      expect(header).to be_a(String)
    end

    it "allows overriding pay_to recipient" do
      different_recipient = "0x1111111111111111111111111111111111111111"

      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        pay_to: different_recipient
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["payload"]["authorization"]["to"]).to eq(different_recipient)
    end

    it "uses config default_pay_to when pay_to is not provided" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["payload"]["authorization"]["to"]).to eq(test_wallet)
    end

    it "allows custom extra EIP-712 domain data" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        extra: {
          name: "Custom Token",
          version: "1"
        }
      )

      expect(header).to be_a(String)
    end

    it "validates configuration before generating" do
      X402::Payments.configuration.default_pay_to = nil

      expect {
        generator.generate_header(amount: 0.001, resource: test_resource)
      }.to raise_error(X402::Payments::ConfigurationError, "default_pay_to is required")
    end
  end

  describe "#generate_link" do
    let(:generator) { described_class.new }

    it "returns a hash with payment_header and curl_command" do
      link = generator.generate_link(
        amount: 0.001,
        resource: test_resource
      )

      expect(link).to be_a(Hash)
      expect(link[:payment_header]).to be_a(String)
      expect(link[:curl_command]).to be_a(String)
    end

    it "generates a valid curl command" do
      link = generator.generate_link(
        amount: 0.001,
        resource: test_resource,
        version: 1
      )

      expect(link[:curl_command]).to include("curl")
      expect(link[:curl_command]).to include("-H")
      expect(link[:curl_command]).to include("X-PAYMENT:")
      expect(link[:curl_command]).to include(test_resource)
      expect(link[:curl_command]).to include(link[:payment_header])
    end

    it "passes through all options to generate_header" do
      link = generator.generate_link(
        amount: 0.005,
        resource: test_resource,
        description: "Test description",
        network: "base",
        version: 1
      )

      decoded = Base64.strict_decode64(link[:payment_header])
      json = JSON.parse(decoded)

      expect(json["network"]).to eq("base")
      expect(json["payload"]["authorization"]["value"]).to eq("5000")
    end
  end

  describe "amount conversion" do
    let(:generator) { described_class.new }

    it "converts 0.001 USD to 1000 atomic units" do
      header = generator.generate_header(amount: 0.001, resource: test_resource)
      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["payload"]["authorization"]["value"]).to eq("1000")
    end

    it "converts 1 USD to 1000000 atomic units" do
      header = generator.generate_header(amount: 1, resource: test_resource)
      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["payload"]["authorization"]["value"]).to eq("1000000")
    end

    it "converts 0.000001 USD to 1 atomic unit" do
      header = generator.generate_header(amount: 0.000001, resource: test_resource)
      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["payload"]["authorization"]["value"]).to eq("1")
    end
  end

  describe "v2 protocol support" do
    let(:generator) { described_class.new }

    describe "#generate_header with version: 2" do
      it "generates a v2 payload structure" do
        header = generator.generate_header(
          amount: 0.001,
          resource: test_resource,
          description: "Test payment",
          version: 2
        )

        decoded = Base64.strict_decode64(header)
        json = JSON.parse(decoded)

        expect(json["x402Version"]).to eq(2)
        expect(json["resource"]).to be_a(Hash)
        expect(json["accepted"]).to be_a(Hash)
        expect(json["extensions"]).to eq({})
      end

      it "includes resource object with correct fields" do
        header = generator.generate_header(
          amount: 0.001,
          resource: test_resource,
          description: "Test payment",
          version: 2
        )

        decoded = Base64.strict_decode64(header)
        json = JSON.parse(decoded)

        expect(json["resource"]["url"]).to eq(test_resource)
        expect(json["resource"]["description"]).to eq("Test payment")
        expect(json["resource"]["mimeType"]).to eq("application/json")
      end

      it "uses CAIP-2 network format in accepted" do
        header = generator.generate_header(
          amount: 0.001,
          resource: test_resource,
          version: 2
        )

        decoded = Base64.strict_decode64(header)
        json = JSON.parse(decoded)

        expect(json["accepted"]["network"]).to eq("eip155:84532")
      end

      it "includes accepted object with payment requirements" do
        header = generator.generate_header(
          amount: 0.001,
          resource: test_resource,
          version: 2
        )

        decoded = Base64.strict_decode64(header)
        json = JSON.parse(decoded)

        expect(json["accepted"]["scheme"]).to eq("exact")
        expect(json["accepted"]["amount"]).to eq("1000")
        expect(json["accepted"]["payTo"]).to eq(test_wallet)
        expect(json["accepted"]["maxTimeoutSeconds"]).to eq(600)
      end
    end

    describe "#generate_link with version: 2" do
      it "uses PAYMENT-SIGNATURE header name" do
        link = generator.generate_link(
          amount: 0.001,
          resource: test_resource,
          version: 2
        )

        expect(link[:header_name]).to eq("PAYMENT-SIGNATURE")
        expect(link[:curl_command]).to include("PAYMENT-SIGNATURE:")
      end
    end
  end

  describe "#generate_header_for" do
    let(:generator) { described_class.new }

    let(:v1_payment_required) do
      {
        version: 1,
        resource: {
          url: test_resource,
          description: "Test API",
          mime_type: "application/json"
        },
        accepts: [
          {
            scheme: "exact",
            network: "base-sepolia",
            amount: "1000",
            asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
            pay_to: test_wallet,
            max_timeout_seconds: 60,
            extra: { "name" => "USDC", "version" => "2" }
          }
        ]
      }
    end

    let(:v2_payment_required) do
      {
        version: 2,
        resource: {
          url: test_resource,
          description: "Test API",
          mime_type: "application/json"
        },
        accepts: [
          {
            scheme: "exact",
            network: "eip155:84532",
            amount: "1000",
            asset: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
            pay_to: test_wallet,
            max_timeout_seconds: 60,
            extra: { "name" => "USDC", "version" => "2" }
          }
        ],
        extensions: {}
      }
    end

    it "generates v1 payload for v1 payment requirements" do
      header = generator.generate_header_for(v1_payment_required)

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["x402Version"]).to eq(1)
      expect(json["scheme"]).to eq("exact")
      expect(json["network"]).to eq("base-sepolia")
    end

    it "generates v2 payload for v2 payment requirements" do
      header = generator.generate_header_for(v2_payment_required)

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["x402Version"]).to eq(2)
      expect(json["accepted"]["network"]).to eq("eip155:84532")
      expect(json["resource"]["url"]).to eq(test_resource)
    end

    it "raises error when no accepts found" do
      payment_required = { version: 1, accepts: [] }

      expect {
        generator.generate_header_for(payment_required)
      }.to raise_error(X402::Payments::Error, "No payment requirements found")
    end

    it "allows overriding private_key" do
      different_key = "0x1234567890123456789012345678901234567890123456789012345678901234"

      header = generator.generate_header_for(v1_payment_required, private_key: different_key)
      expect(header).to be_a(String)
    end

    it "uses config private_key by default" do
      header = generator.generate_header_for(v1_payment_required)
      expect(header).to be_a(String)
    end

    it "raises error when private_key is not configured" do
      X402::Payments.configuration.private_key = nil

      expect {
        generator.generate_header_for(v1_payment_required)
      }.to raise_error(X402::Payments::ConfigurationError, "private_key is required")
    end
  end
end
