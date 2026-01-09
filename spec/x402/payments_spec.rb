# frozen_string_literal: true

RSpec.describe X402::Payments do
  let(:test_wallet) { "0xd086Ef8F2c0F9d642120cCf0898BD101b1d18Db6" }
  let(:test_private_key) { "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef" }

  before do
    X402::Payments.configure do |config|
      config.default_pay_to = test_wallet
      config.private_key = test_private_key
    end
  end

  after do
    X402::Payments.reset_configuration!
  end

  it "has a version number" do
    expect(X402::Payments::VERSION).not_to be_nil
  end

  describe ".generate_header" do
    it "delegates to Generator#generate_header" do
      header = X402::Payments.generate_header(
        amount: 0.001,
        resource: "http://localhost:3000/api/test"
      )

      expect(header).to be_a(String)
      expect(header).not_to be_empty
    end

    it "passes all options to generator" do
      header = X402::Payments.generate_header(
        amount: 0.001,
        resource: "http://localhost:3000/api/test",
        description: "Test",
        network: "base-sepolia",
        version: 1
      )

      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["network"]).to eq("base-sepolia")
    end
  end

  describe ".generate_link" do
    it "delegates to Generator#generate_link" do
      link = X402::Payments.generate_link(
        amount: 0.001,
        resource: "http://localhost:3000/api/test"
      )

      expect(link).to be_a(Hash)
      expect(link[:payment_header]).to be_a(String)
      expect(link[:curl_command]).to be_a(String)
    end
  end

  describe ".normalize_version" do
    it "returns nil for nil input" do
      expect(X402::Payments.normalize_version(nil)).to be_nil
    end

    it "returns integer for integer input" do
      expect(X402::Payments.normalize_version(1)).to eq(1)
      expect(X402::Payments.normalize_version(2)).to eq(2)
    end

    it "coerces string to integer" do
      expect(X402::Payments.normalize_version("1")).to eq(1)
      expect(X402::Payments.normalize_version("2")).to eq(2)
    end

    it "raises ArgumentError for unsupported versions" do
      expect { X402::Payments.normalize_version(3) }.to raise_error(ArgumentError, /Unsupported protocol version/)
      expect { X402::Payments.normalize_version("3") }.to raise_error(ArgumentError, /Unsupported protocol version/)
      expect { X402::Payments.normalize_version(0) }.to raise_error(ArgumentError, /Unsupported protocol version/)
    end
  end

  describe "string version parameter handling" do
    it "handles string version '2' correctly in generate_header" do
      header = X402::Payments.generate_header(
        amount: 0.001,
        resource: "http://localhost:3000/api/test",
        version: "2"
      )

      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["x402Version"]).to eq(2)
      expect(decoded["accepted"]["network"]).to include("eip155:")
    end

    it "handles string version '1' correctly in generate_header" do
      header = X402::Payments.generate_header(
        amount: 0.001,
        resource: "http://localhost:3000/api/test",
        version: "1"
      )

      decoded = JSON.parse(Base64.strict_decode64(header))
      expect(decoded["x402Version"]).to eq(1)
      expect(decoded["network"]).not_to include("eip155:")
    end

    it "returns correct header name for string version '2'" do
      expect(X402::Payments.payment_header_name("2")).to eq("PAYMENT-SIGNATURE")
    end

    it "returns correct header name for string version '1'" do
      expect(X402::Payments.payment_header_name("1")).to eq("X-PAYMENT")
    end

    it "handles string version correctly in generate_link" do
      link = X402::Payments.generate_link(
        amount: 0.001,
        resource: "http://localhost:3000/api/test",
        version: "2"
      )

      expect(link[:header_name]).to eq("PAYMENT-SIGNATURE")
      decoded = JSON.parse(Base64.strict_decode64(link[:payment_header]))
      expect(decoded["x402Version"]).to eq(2)
    end
  end
end
