# frozen_string_literal: true

RSpec.describe X402::Payments::Solana::Generator do
  let(:test_wallet) { "EYNQARNg9gZTtj1xMMrHK7dRFAkVjAAMubxaH7Do8d9Y" }
  let(:test_private_key) { "5qWMxUb8XGRz7CzTpBLCvSGXoYZeZk4iUwHZJHWqA7eBVPrCwAmRqpMgAQHvqpCjdWNj1iLpCmvPXd8KQgqFPYdC" }
  let(:test_resource) { "http://localhost:3000/api/weather" }
  let(:mock_blockhash) { "GWWy2aAev5X3TMRVwdw8W2KMN3dyVrHrQMZukGTf9R1A" }
  let(:mock_source_ata) { "DJqvut91WJFzoub419vpnG7PYYUgvxefTro7kAnwNxM9" }
  let(:mock_dest_ata) { "C38SumbDFvHp8sGCR3uD6TA7pQwV188nfSisneQNLGU9" }

  let(:mock_client) do
    instance_double(SolanaRuby::HttpClient).tap do |client|
      allow(client).to receive(:get_latest_blockhash).and_return({ "blockhash" => mock_blockhash })
    end
  end

  let(:mock_transaction) do
    instance_double("SolanaRuby::Transaction").tap do |tx|
      allow(tx).to receive(:sign)
      allow(tx).to receive(:to_base64).and_return("mock_serialized_transaction_base64")
    end
  end

  before do
    X402::Payments.configure do |config|
      config.default_pay_to = test_wallet
      config.private_key = test_private_key
      config.chain = "solana-devnet"
      config.max_timeout_seconds = 600
    end

    allow(SolanaRuby::HttpClient).to receive(:new).and_return(mock_client)
    allow(SolanaRuby::TransactionHelpers::TokenAccount).to receive(:get_associated_token_address)
      .and_return(mock_source_ata, mock_dest_ata)
    allow(SolanaRuby::TransactionHelper).to receive(:new_spl_token_transaction)
      .and_return(mock_transaction)
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
      expect(json["network"]).to eq("solana-devnet")
      expect(json["payload"]).to be_a(Hash)
      expect(json["payload"]["transaction"]).to be_a(String)
    end

    it "converts amount to atomic units correctly" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 2
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      # 0.001 USD = 1000 atomic units (6 decimals)
      expect(json["accepted"]["amount"]).to eq("1000")
    end

    it "allows overriding network" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        network: "solana",
        version: 1
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["network"]).to eq("solana")
    end

    it "allows overriding pay_to recipient" do
      different_recipient = "AnotherPubkeyForTestingPurposes123456789ABCD"

      allow(SolanaRuby::TransactionHelpers::TokenAccount).to receive(:get_associated_token_address)
        .and_return(mock_source_ata, "different_dest_ata")

      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        pay_to: different_recipient,
        version: 2
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["accepted"]["payTo"]).to eq(different_recipient)
    end

    it "raises error for non-Solana chains" do
      expect {
        generator.generate_header(
          amount: 0.001,
          resource: test_resource,
          network: "base-sepolia"
        )
      }.to raise_error(X402::Payments::ConfigurationError, "Solana chain required")
    end

    it "raises error when private key is missing" do
      X402::Payments.configuration.private_key = nil

      expect {
        generator.generate_header(amount: 0.001, resource: test_resource)
      }.to raise_error(X402::Payments::ConfigurationError, /private key is required/)
    end

    it "raises error when recipient is missing" do
      X402::Payments.configuration.default_pay_to = nil

      expect {
        generator.generate_header(amount: 0.001, resource: test_resource)
      }.to raise_error(X402::Payments::ConfigurationError, /Recipient address is required/)
    end
  end

  describe "v1 protocol support" do
    let(:generator) { described_class.new }

    it "generates v1 payload structure" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 1
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["x402Version"]).to eq(1)
      expect(json["scheme"]).to eq("exact")
      expect(json["network"]).to eq("solana-devnet")
      expect(json["payload"]["transaction"]).to be_a(String)
    end

    it "uses human-readable network name" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 1
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["network"]).to eq("solana-devnet")
    end
  end

  describe "v2 protocol support" do
    let(:generator) { described_class.new }

    it "generates v2 payload structure" do
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

    it "uses CAIP-2 network format" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 2
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["accepted"]["network"]).to eq("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
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
      expect(json["accepted"]["asset"]).to eq("4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU")
    end

    it "includes feePayer in extra" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 2
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["accepted"]["extra"]["feePayer"]).to eq("CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5")
    end

    it "includes transaction in payload" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 2
      )

      decoded = Base64.strict_decode64(header)
      json = JSON.parse(decoded)

      expect(json["payload"]["transaction"]).to be_a(String)
      # Transaction should be base64 encoded
      expect { Base64.strict_decode64(json["payload"]["transaction"]) }.not_to raise_error
    end
  end

  describe "amount conversion" do
    let(:generator) { described_class.new }

    it "converts 0.001 USD to 1000 atomic units" do
      header = generator.generate_header(amount: 0.001, resource: test_resource, version: 2)
      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["accepted"]["amount"]).to eq("1000")
    end

    it "converts 1 USD to 1000000 atomic units" do
      header = generator.generate_header(amount: 1, resource: test_resource, version: 2)
      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["accepted"]["amount"]).to eq("1000000")
    end

    it "converts 0.000001 USD to 1 atomic unit" do
      header = generator.generate_header(amount: 0.000001, resource: test_resource, version: 2)
      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["accepted"]["amount"]).to eq("1")
    end
  end

  describe "ATA derivation" do
    let(:generator) { described_class.new }

    it "derives correct ATA addresses" do
      # Test that our custom ATA derivation works correctly
      mint = "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU"
      owner = "EYNQARNg9gZTtj1xMMrHK7dRFAkVjAAMubxaH7Do8d9Y"
      expected_ata = "Cyq5ivewKSEADjRqQijP4rtQjSKP4QV1D77uipnpyjdh"

      ata = generator.send(:derive_associated_token_address, mint, owner)
      expect(ata).to eq(expected_ata)
    end
  end

  describe "transaction building" do
    let(:generator) { described_class.new }

    it "fetches recent blockhash from RPC" do
      expect(mock_client).to receive(:get_latest_blockhash)
        .and_return({ "blockhash" => mock_blockhash })

      generator.generate_header(
        amount: 0.001,
        resource: test_resource
      )
    end

    it "builds transaction with correct structure" do
      header = generator.generate_header(
        amount: 0.001,
        resource: test_resource,
        version: 1
      )

      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["payload"]["transaction"]).to be_a(String)
      # Transaction should be base64 encoded
      expect { Base64.strict_decode64(decoded["payload"]["transaction"]) }.not_to raise_error
    end
  end
end
