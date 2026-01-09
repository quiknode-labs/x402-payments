# frozen_string_literal: true

require "spec_helper"

RSpec.describe X402::Payments::Networks do
  describe ".to_caip2" do
    it "converts base-sepolia to CAIP-2 format" do
      expect(described_class.to_caip2("base-sepolia")).to eq("eip155:84532")
    end

    it "converts base to CAIP-2 format" do
      expect(described_class.to_caip2("base")).to eq("eip155:8453")
    end

    it "converts avalanche-fuji to CAIP-2 format" do
      expect(described_class.to_caip2("avalanche-fuji")).to eq("eip155:43113")
    end

    it "converts avalanche to CAIP-2 format" do
      expect(described_class.to_caip2("avalanche")).to eq("eip155:43114")
    end

    it "converts solana-devnet to CAIP-2 format" do
      expect(described_class.to_caip2("solana-devnet")).to eq("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")
    end

    it "converts solana mainnet to CAIP-2 format" do
      expect(described_class.to_caip2("solana")).to eq("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
    end

    it "returns input unchanged if already in CAIP-2 format" do
      expect(described_class.to_caip2("eip155:84532")).to eq("eip155:84532")
    end

    it "raises error for unknown network" do
      expect { described_class.to_caip2("unknown") }.to raise_error(X402::Payments::Error)
    end
  end

  describe ".from_caip2" do
    it "converts CAIP-2 base-sepolia to human-readable" do
      expect(described_class.from_caip2("eip155:84532")).to eq("base-sepolia")
    end

    it "converts CAIP-2 base to human-readable" do
      expect(described_class.from_caip2("eip155:8453")).to eq("base")
    end

    it "converts CAIP-2 avalanche-fuji to human-readable" do
      expect(described_class.from_caip2("eip155:43113")).to eq("avalanche-fuji")
    end

    it "converts CAIP-2 avalanche to human-readable" do
      expect(described_class.from_caip2("eip155:43114")).to eq("avalanche")
    end

    it "converts CAIP-2 solana-devnet to human-readable" do
      expect(described_class.from_caip2("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")).to eq("solana-devnet")
    end

    it "converts CAIP-2 solana mainnet to human-readable" do
      expect(described_class.from_caip2("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")).to eq("solana")
    end

    it "returns input unchanged if already in human-readable format" do
      expect(described_class.from_caip2("base-sepolia")).to eq("base-sepolia")
    end

    it "raises error for unknown CAIP-2 network" do
      expect { described_class.from_caip2("eip155:99999") }.to raise_error(X402::Payments::Error)
    end
  end

  describe ".caip2_format?" do
    it "returns true for EIP-155 CAIP-2 format" do
      expect(described_class.caip2_format?("eip155:84532")).to be true
    end

    it "returns true for Solana CAIP-2 format" do
      expect(described_class.caip2_format?("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1")).to be true
    end

    it "returns false for human-readable format" do
      expect(described_class.caip2_format?("base-sepolia")).to be false
      expect(described_class.caip2_format?("solana-devnet")).to be false
    end
  end

  describe ".chain_id_from_caip2" do
    it "extracts chain ID from CAIP-2 format" do
      expect(described_class.chain_id_from_caip2("eip155:84532")).to eq(84532)
    end

    it "returns nil for non-EIP155 namespaces" do
      expect(described_class.chain_id_from_caip2("solana:mainnet")).to be_nil
    end

    it "returns nil for non-CAIP-2 format" do
      expect(described_class.chain_id_from_caip2("base-sepolia")).to be_nil
    end
  end

  describe ".supported_networks" do
    it "returns all supported human-readable network names" do
      expect(described_class.supported_networks).to include("base-sepolia", "base", "avalanche-fuji", "avalanche")
      expect(described_class.supported_networks).to include("solana-devnet", "solana")
    end
  end

  describe ".supported_caip2_networks" do
    it "returns all supported CAIP-2 network identifiers" do
      expect(described_class.supported_caip2_networks).to include("eip155:84532", "eip155:8453", "eip155:43113", "eip155:43114")
      expect(described_class.supported_caip2_networks).to include("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
    end
  end

  describe "custom chain support" do
    before { X402::Payments.reset_configuration! }
    after { X402::Payments.reset_configuration! }

    it "converts custom chain to CAIP-2" do
      X402::Payments.configure do |config|
        config.register_chain(name: "polygon-amoy", chain_id: 80002)
      end

      expect(described_class.to_caip2("polygon-amoy")).to eq("eip155:80002")
    end

    it "converts custom chain CAIP-2 back to human-readable" do
      X402::Payments.configure do |config|
        config.register_chain(name: "polygon-amoy", chain_id: 80002)
      end

      expect(described_class.from_caip2("eip155:80002")).to eq("polygon-amoy")
    end
  end
end
