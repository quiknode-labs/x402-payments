# frozen_string_literal: true

module X402
  module Payments
    # Chain configurations for supported networks
    CHAINS = {
      "base-sepolia" => {
        chain_id: 84532,
        rpc_url: "https://clean-snowy-hexagon.base-sepolia.quiknode.pro",
        usdc_address: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        explorer_url: "https://sepolia.basescan.org"
      },
      "base" => {
        chain_id: 8453,
        rpc_url: "https://snowy-compatible-ensemble.base-mainnet.quiknode.pro",
        usdc_address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        explorer_url: "https://basescan.org"
      },
      "avalanche-fuji" => {
        chain_id: 43113,
        rpc_url: "https://muddy-sly-field.avalanche-testnet.quiknode.pro/ext/bc/C/rpc",
        usdc_address: "0x5425890298aed601595a70AB815c96711a31Bc65",
        explorer_url: "https://testnet.snowtrace.io"
      },
      "avalanche" => {
        chain_id: 43114,
        rpc_url: "https://floral-patient-panorama.avalanche-mainnet.quiknode.pro/ext/bc/C/rpc",
        usdc_address: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
        explorer_url: "https://snowtrace.io"
      },
      "solana-devnet" => {
        chain_id: 103,
        rpc_url: "https://bitter-twilight-vineyard.solana-devnet.quiknode.pro",
        usdc_address: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
        explorer_url: "https://explorer.solana.com/?cluster=devnet",
        fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5"
      },
      "solana" => {
        chain_id: 101,
        rpc_url: "https://alien-burned-energy.solana-mainnet.quiknode.pro/",
        usdc_address: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        explorer_url: "https://explorer.solana.com",
        fee_payer: "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5"
      }
    }.freeze

    SOLANA_CHAINS = %w[solana solana-devnet].freeze

    # Currency configurations by chain
    CURRENCY_BY_CHAIN = {
      "base-sepolia" => {
        symbol: "USDC",
        decimals: 6,
        name: "USDC",
        version: "2"
      },
      "base" => {
        symbol: "USDC",
        decimals: 6,
        name: "USD Coin",
        version: "2"
      },
      "avalanche-fuji" => {
        symbol: "USDC",
        decimals: 6,
        name: "USD Coin",
        version: "2"
      },
      "avalanche" => {
        symbol: "USDC",
        decimals: 6,
        name: "USDC",
        version: "2"
      },
      "solana-devnet" => {
        symbol: "USDC",
        decimals: 6,
        name: "USDC",
        version: nil
      },
      "solana" => {
        symbol: "USDC",
        decimals: 6,
        name: "USD Coin",
        version: nil
      }
    }.freeze

    class << self
      def chain_config(chain_name)
        custom = X402::Payments.configuration.chain_config(chain_name)
        return custom if custom

        CHAINS[chain_name] || raise(ConfigurationError, "Unsupported chain: #{chain_name}. Register with config.register_chain()")
      end

      def currency_config_for_chain(chain_name)
        CURRENCY_BY_CHAIN[chain_name] || raise(ConfigurationError, "Unsupported chain for currency: #{chain_name}")
      end

      def supported_chains
        CHAINS.keys + X402::Payments.configuration.custom_chains.keys
      end

      def usdc_address_for(chain_name)
        builtin = CHAINS[chain_name]
        builtin ? builtin[:usdc_address] : nil
      end

      def asset_address_for(chain_name, symbol = nil)
        symbol ||= X402::Payments.configuration.currency

        custom = X402::Payments.configuration.token_config(chain_name, symbol)
        return custom[:address] if custom

        if symbol.upcase == "USDC"
          builtin = CHAINS[chain_name]
          return builtin[:usdc_address] if builtin && builtin[:usdc_address]
        end

        raise ConfigurationError, "Unknown token #{symbol} for chain #{chain_name}. Register with config.register_token()"
      end

      def token_config_for(chain_name, symbol = nil)
        symbol ||= X402::Payments.configuration.currency

        custom = X402::Payments.configuration.token_config(chain_name, symbol)
        return custom if custom

        if symbol.upcase == "USDC" && CURRENCY_BY_CHAIN[chain_name]
          currency_config_for_chain(chain_name)
        else
          raise ConfigurationError, "Unknown token #{symbol} for chain #{chain_name}. Register with config.register_token()"
        end
      end

      def chain_id_for(chain_name)
        custom = X402::Payments.configuration.chain_config(chain_name)
        return custom[:chain_id] if custom

        chain_config(chain_name)[:chain_id]
      end

      def currency_decimals_for_chain(chain_name)
        currency_config_for_chain(chain_name)[:decimals]
      end

      def caip2_for(chain_name)
        Networks.to_caip2(chain_name)
      end

      def rpc_url_for(chain_name)
        # Priority: 1) Programmatic config, 2) ENV variable, 3) Default from CHAINS
        config = X402::Payments.configuration

        # Check programmatic configuration
        return config.rpc_urls[chain_name] if config.rpc_urls[chain_name]

        # Check environment variable
        env_var_name = "X402_#{chain_name.upcase.gsub('-', '_')}_RPC_URL"
        env_rpc = ENV[env_var_name]
        return env_rpc if env_rpc && !env_rpc.empty?

        # Fall back to default (only for built-in chains)
        builtin = CHAINS[chain_name]
        builtin ? builtin[:rpc_url] : nil
      end

      def solana_chain?(chain_name)
        SOLANA_CHAINS.include?(chain_name)
      end

      def fee_payer_for(chain_name)
        return nil unless solana_chain?(chain_name)

        # Priority: 1) ENV variable, 2) Default from CHAINS
        env_fee_payer = ENV["X402_SOLANA_FEE_PAYER"]
        return env_fee_payer if env_fee_payer && !env_fee_payer.empty?

        chain_config(chain_name)[:fee_payer]
      end
    end
  end
end
