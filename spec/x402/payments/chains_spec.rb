# frozen_string_literal: true

RSpec.describe X402::Payments do
  describe ".chain_config" do
    it "returns configuration for base-sepolia" do
      config = X402::Payments.chain_config("base-sepolia")
      expect(config[:chain_id]).to eq(84532)
      expect(config[:usdc_address]).to eq("0x036CbD53842c5426634e7929541eC2318f3dCF7e")
      expect(config[:rpc_url]).to eq("https://sepolia.base.org")
      expect(config[:explorer_url]).to eq("https://sepolia.basescan.org")
    end

    it "returns configuration for base mainnet" do
      config = X402::Payments.chain_config("base")
      expect(config[:chain_id]).to eq(8453)
      expect(config[:usdc_address]).to eq("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913")
    end

    it "returns configuration for avalanche-fuji" do
      config = X402::Payments.chain_config("avalanche-fuji")
      expect(config[:chain_id]).to eq(43113)
      expect(config[:usdc_address]).to eq("0x5425890298aed601595a70AB815c96711a31Bc65")
    end

    it "returns configuration for avalanche mainnet" do
      config = X402::Payments.chain_config("avalanche")
      expect(config[:chain_id]).to eq(43114)
      expect(config[:usdc_address]).to eq("0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E")
    end

    it "raises error for unsupported chain" do
      expect { X402::Payments.chain_config("unknown") }
        .to raise_error(X402::Payments::ConfigurationError, "Unsupported chain: unknown")
    end
  end

  describe ".currency_config_for_chain" do
    it "returns currency config for base-sepolia" do
      config = X402::Payments.currency_config_for_chain("base-sepolia")
      expect(config[:symbol]).to eq("USDC")
      expect(config[:decimals]).to eq(6)
      expect(config[:name]).to eq("USDC")
      expect(config[:version]).to eq("2")
    end

    it "returns currency config for base mainnet" do
      config = X402::Payments.currency_config_for_chain("base")
      expect(config[:name]).to eq("USD Coin")
    end

    it "raises error for unsupported chain" do
      expect { X402::Payments.currency_config_for_chain("unknown") }
        .to raise_error(X402::Payments::ConfigurationError, "Unsupported chain for currency: unknown")
    end
  end

  describe ".supported_chains" do
    it "returns list of supported chain names" do
      chains = X402::Payments.supported_chains
      expect(chains).to include("base-sepolia", "base", "avalanche-fuji", "avalanche")
      expect(chains.size).to eq(4)
    end
  end

  describe ".usdc_address_for" do
    it "returns USDC address for chain" do
      address = X402::Payments.usdc_address_for("base-sepolia")
      expect(address).to eq("0x036CbD53842c5426634e7929541eC2318f3dCF7e")
    end
  end

  describe ".chain_id_for" do
    it "returns chain ID for chain name" do
      chain_id = X402::Payments.chain_id_for("base-sepolia")
      expect(chain_id).to eq(84532)
    end
  end

  describe ".currency_decimals_for_chain" do
    it "returns decimals for chain" do
      decimals = X402::Payments.currency_decimals_for_chain("base-sepolia")
      expect(decimals).to eq(6)
    end
  end
end
