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
end
