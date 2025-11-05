# frozen_string_literal: true

module X402
  module Payments
    class Configuration
      attr_accessor :default_pay_to, :private_key, :chain, :max_timeout_seconds, :rpc_urls, :solana_fee_payer

      def initialize
        @default_pay_to = ENV.fetch("X402_PAY_TO", nil)
        @private_key = ENV.fetch("X402_PRIVATE_KEY", nil)
        @chain = ENV.fetch("X402_CHAIN", "base-sepolia")
        @max_timeout_seconds = ENV.fetch("X402_MAX_TIMEOUT_SECONDS", "600").to_i
        @rpc_urls = {}
        # Default to x402.org facilitator's fee payer for Solana
        @solana_fee_payer = ENV.fetch("X402_SOLANA_FEE_PAYER", "CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5")
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
