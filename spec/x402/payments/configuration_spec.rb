# frozen_string_literal: true

RSpec.describe X402::Payments::Configuration do
  after do
    X402::Payments.reset_configuration!
  end

  describe "#initialize" do
    it "sets default values from environment variables" do
      config = described_class.new
      expect(config.chain).to eq("base-sepolia")
      expect(config.max_timeout_seconds).to eq(600)
    end

    it "reads default_pay_to from environment" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("X402_PAY_TO", nil).and_return("0x123")
      config = described_class.new
      expect(config.default_pay_to).to eq("0x123")
    end

    it "reads private_key from environment" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("X402_PRIVATE_KEY", nil).and_return("0xabc")
      config = described_class.new
      expect(config.private_key).to eq("0xabc")
    end

    it "reads chain from environment" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("X402_CHAIN", "base-sepolia").and_return("base")
      config = described_class.new
      expect(config.chain).to eq("base")
    end

    it "parses max_timeout_seconds as integer" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("X402_MAX_TIMEOUT_SECONDS", "600").and_return("300")
      config = described_class.new
      expect(config.max_timeout_seconds).to eq(300)
    end
  end

  describe "#validate!" do
    let(:config) { described_class.new }

    it "raises error when default_pay_to is nil" do
      config.default_pay_to = nil
      config.private_key = "0xkey"
      expect { config.validate! }.to raise_error(X402::Payments::ConfigurationError, "default_pay_to is required")
    end

    it "raises error when default_pay_to is empty" do
      config.default_pay_to = ""
      config.private_key = "0xkey"
      expect { config.validate! }.to raise_error(X402::Payments::ConfigurationError, "default_pay_to is required")
    end

    it "raises error when private_key is nil" do
      config.default_pay_to = "0x123"
      config.private_key = nil
      expect { config.validate! }.to raise_error(X402::Payments::ConfigurationError, "private_key is required")
    end

    it "raises error when private_key is empty" do
      config.default_pay_to = "0x123"
      config.private_key = ""
      expect { config.validate! }.to raise_error(X402::Payments::ConfigurationError, "private_key is required")
    end

    it "raises error when chain is empty" do
      config.default_pay_to = "0x123"
      config.private_key = "0xkey"
      config.chain = ""
      expect { config.validate! }.to raise_error(X402::Payments::ConfigurationError, "chain is required")
    end

    it "passes validation with all required fields" do
      config.default_pay_to = "0x123"
      config.private_key = "0xkey"
      expect { config.validate! }.not_to raise_error
    end
  end
end

RSpec.describe X402::Payments do
  after do
    X402::Payments.reset_configuration!
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(X402::Payments.configuration).to be_a(X402::Payments::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = X402::Payments.configuration
      config2 = X402::Payments.configuration
      expect(config1).to equal(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      expect { |b| X402::Payments.configure(&b) }.to yield_with_args(X402::Payments::Configuration)
    end

    it "allows setting configuration values" do
      X402::Payments.configure do |config|
        config.default_pay_to = "0xtest"
        config.private_key = "0xkey"
        config.chain = "base"
        config.max_timeout_seconds = 300
      end

      expect(X402::Payments.configuration.default_pay_to).to eq("0xtest")
      expect(X402::Payments.configuration.private_key).to eq("0xkey")
      expect(X402::Payments.configuration.chain).to eq("base")
      expect(X402::Payments.configuration.max_timeout_seconds).to eq(300)
    end
  end

  describe ".reset_configuration!" do
    it "creates a new configuration instance" do
      old_config = X402::Payments.configuration
      X402::Payments.reset_configuration!
      new_config = X402::Payments.configuration
      expect(new_config).not_to equal(old_config)
    end

    it "resets configuration to defaults" do
      X402::Payments.configure do |config|
        config.default_pay_to = "0xtest"
        config.private_key = "0xkey"
      end

      X402::Payments.reset_configuration!
      expect(X402::Payments.configuration.default_pay_to).to be_nil
      expect(X402::Payments.configuration.private_key).to be_nil
    end
  end
end
