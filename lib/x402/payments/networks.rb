# frozen_string_literal: true

module X402
  module Payments
    module Networks
      NETWORK_MAPPING = {
        "base-sepolia" => "eip155:84532",
        "base" => "eip155:8453",
        "avalanche-fuji" => "eip155:43113",
        "avalanche" => "eip155:43114",
        "solana-devnet" => "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
        "solana" => "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"
      }.freeze

      CAIP2_MAPPING = NETWORK_MAPPING.invert.freeze

      class << self
        def to_caip2(network)
          return network if caip2_format?(network)

          # Check custom chains first
          custom = X402::Payments.configuration.chain_config(network)
          if custom
            return "#{custom[:standard]}:#{custom[:chain_id]}"
          end

          NETWORK_MAPPING[network] || raise(Error, "Unknown network: #{network}")
        end

        def from_caip2(network)
          return network unless caip2_format?(network)

          # Check custom chains first
          X402::Payments.configuration.custom_chains.each do |name, config|
            caip2 = "#{config[:standard]}:#{config[:chain_id]}"
            return name if caip2 == network
          end

          CAIP2_MAPPING[network] || raise(Error, "Unknown CAIP-2 network: #{network}")
        end

        def caip2_format?(network)
          network.to_s.include?(":")
        end

        def normalize(network, format: :human)
          case format
          when :human
            from_caip2(network)
          when :caip2
            to_caip2(network)
          else
            raise ArgumentError, "Unknown format: #{format}. Use :human or :caip2"
          end
        end

        def chain_id_from_caip2(caip2_network)
          return nil unless caip2_format?(caip2_network)

          namespace, reference = caip2_network.split(":")
          return nil unless namespace == "eip155"

          reference.to_i
        end

        def supported_networks
          NETWORK_MAPPING.keys
        end

        def supported_caip2_networks
          CAIP2_MAPPING.keys
        end
      end
    end
  end
end
