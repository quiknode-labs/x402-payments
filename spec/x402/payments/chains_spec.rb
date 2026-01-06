# frozen_string_literal: true

RSpec.describe X402::Payments do
  describe ".chain_config" do
    it "returns configuration for base-sepolia" do
      config = X402::Payments.chain_config("base-sepolia")
      expect(config[:chain_id]).to eq(84532)
      expect(config[:usdc_address]).to eq("0x036CbD53842c5426634e7929541eC2318f3dCF7e")
      expect(config[:rpc_url]).to eq("https://clean-snowy-hexagon.base-sepolia.quiknode.pro")
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
        .to raise_error(X402::Payments::ConfigurationError, /Unsupported chain: unknown/)
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
    before { X402::Payments.reset_configuration! }

    it "returns list of supported chain names" do
      chains = X402::Payments.supported_chains
      expect(chains).to include("base-sepolia", "base", "avalanche-fuji", "avalanche")
    end

    it "includes custom chains" do
      X402::Payments.configure do |config|
        config.register_chain(name: "polygon", chain_id: 137)
      end

      chains = X402::Payments.supported_chains
      expect(chains).to include("polygon")
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

  describe ".caip2_for" do
    before { X402::Payments.reset_configuration! }

    it "returns CAIP-2 for built-in chains" do
      expect(X402::Payments.caip2_for("base-sepolia")).to eq("eip155:84532")
      expect(X402::Payments.caip2_for("base")).to eq("eip155:8453")
    end

    it "returns CAIP-2 for custom chains" do
      X402::Payments.configure do |config|
        config.register_chain(name: "polygon", chain_id: 137)
      end

      expect(X402::Payments.caip2_for("polygon")).to eq("eip155:137")
    end
  end

  describe ".asset_address_for" do
    before { X402::Payments.reset_configuration! }

    it "returns USDC address for built-in chains by default" do
      expect(X402::Payments.asset_address_for("base-sepolia")).to eq("0x036CbD53842c5426634e7929541eC2318f3dCF7e")
    end

    it "returns custom token address when registered" do
      X402::Payments.configure do |config|
        config.register_token(
          chain: "base",
          symbol: "WETH",
          address: "0x4200000000000000000000000000000000000006",
          decimals: 18,
          name: "Wrapped Ether"
        )
        config.currency = "WETH"
      end

      expect(X402::Payments.asset_address_for("base")).to eq("0x4200000000000000000000000000000000000006")
    end

    it "allows specifying symbol explicitly" do
      X402::Payments.configure do |config|
        config.register_token(
          chain: "base",
          symbol: "WETH",
          address: "0x4200000000000000000000000000000000000006",
          decimals: 18,
          name: "Wrapped Ether"
        )
      end

      expect(X402::Payments.asset_address_for("base", "WETH")).to eq("0x4200000000000000000000000000000000000006")
      expect(X402::Payments.asset_address_for("base", "USDC")).to eq("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913")
    end

    it "raises error for unknown token" do
      expect { X402::Payments.asset_address_for("base", "UNKNOWN") }
        .to raise_error(X402::Payments::ConfigurationError, /Unknown token/)
    end
  end

  describe ".token_config_for" do
    before { X402::Payments.reset_configuration! }

    it "returns built-in USDC config by default" do
      config = X402::Payments.token_config_for("base-sepolia")
      expect(config[:symbol]).to eq("USDC")
      expect(config[:decimals]).to eq(6)
    end

    it "returns custom token config when registered" do
      X402::Payments.configure do |config|
        config.register_token(
          chain: "base",
          symbol: "WETH",
          address: "0x4200000000000000000000000000000000000006",
          decimals: 18,
          name: "Wrapped Ether",
          version: "1"
        )
        config.currency = "WETH"
      end

      config = X402::Payments.token_config_for("base")
      expect(config[:symbol]).to eq("WETH")
      expect(config[:decimals]).to eq(18)
      expect(config[:name]).to eq("Wrapped Ether")
    end

    it "raises error for unknown token" do
      expect { X402::Payments.token_config_for("base", "UNKNOWN") }
        .to raise_error(X402::Payments::ConfigurationError)
    end
  end

  describe "custom chain integration" do
    before { X402::Payments.reset_configuration! }

    it "allows using a fully custom chain and token" do
      X402::Payments.configure do |config|
        config.default_pay_to = "0x1234567890abcdef1234567890abcdef12345678"
        config.private_key = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        config.register_chain(name: "polygon-amoy", chain_id: 80002)
        config.register_token(
          chain: "polygon-amoy",
          symbol: "USDC",
          address: "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582",
          decimals: 6,
          name: "USD Coin",
          version: "2"
        )
        config.chain = "polygon-amoy"
        config.currency = "USDC"
      end

      expect(X402::Payments.caip2_for("polygon-amoy")).to eq("eip155:80002")
      expect(X402::Payments.asset_address_for("polygon-amoy")).to eq("0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582")
      expect(X402::Payments.chain_id_for("polygon-amoy")).to eq(80002)

      token_config = X402::Payments.token_config_for("polygon-amoy")
      expect(token_config[:decimals]).to eq(6)
      expect(token_config[:name]).to eq("USD Coin")
    end
  end
end
