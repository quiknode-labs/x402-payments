# frozen_string_literal: true

module X402
  module Payments
    class Configuration
      attr_accessor :default_pay_to, :private_key, :chain, :max_timeout_seconds, :rpc_urls,
                    :protocol_version, :custom_chains, :custom_tokens, :currency,
                    :solana_compute_unit_limit, :solana_compute_unit_price

      def initialize
        @default_pay_to = ENV.fetch("X402_PAY_TO", nil)
        @private_key = ENV.fetch("X402_PRIVATE_KEY", nil)
        @chain = ENV.fetch("X402_CHAIN", "base-sepolia")
        @currency = ENV.fetch("X402_CURRENCY", "USDC")
        @max_timeout_seconds = ENV.fetch("X402_MAX_TIMEOUT_SECONDS", "600").to_i
        @protocol_version = ENV.fetch("X402_PROTOCOL_VERSION", "2").to_i
        @rpc_urls = {}
        @custom_chains = {}
        @custom_tokens = {}
        @solana_compute_unit_limit = ENV.fetch("X402_SOLANA_COMPUTE_UNIT_LIMIT", 200_000).to_i
        @solana_compute_unit_price = ENV.fetch("X402_SOLANA_COMPUTE_UNIT_PRICE", 1_000).to_i
      end

      def register_chain(name:, chain_id:, standard: "eip155")
        unless standard == "eip155"
          raise ConfigurationError, "Only eip155 (EVM) chains are supported for custom registration"
        end

        @custom_chains[name] = {
          chain_id: chain_id,
          standard: standard
        }
      end

      def register_token(chain:, symbol:, address:, decimals:, name:, version: "1")
        key = "#{chain}:#{symbol}"
        @custom_tokens[key] = {
          symbol: symbol,
          address: address,
          decimals: decimals,
          name: name,
          version: version
        }
      end

      def chain_config(name)
        @custom_chains[name]
      end

      def token_config(chain, symbol)
        key = "#{chain}:#{symbol}"
        @custom_tokens[key]
      end

      def validate!
        raise ConfigurationError, "default_pay_to is required" if default_pay_to.nil? || default_pay_to.empty?
        raise ConfigurationError, "private_key is required" if private_key.nil? || private_key.empty?
        raise ConfigurationError, "chain is required" if chain.nil? || chain.empty?
      end
    end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = Configuration.new
      end
    end

    class ConfigurationError < StandardError; end
  end
end
