# frozen_string_literal: true

module X402
  module Payments
    class Error < StandardError; end
  end
end

require_relative "payments/version"
require_relative "payments/configuration"
require_relative "payments/chains"
require_relative "payments/networks"
require_relative "payments/v1/headers"
require_relative "payments/v1/payload_builder"
require_relative "payments/v2/headers"
require_relative "payments/v2/payload_builder"
require_relative "payments/response_parser"
require_relative "payments/generator"
require_relative "payments/solana/generator"

module X402
  module Payments

    class << self
      def generate_header(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil, version: nil, fee_payer: nil)
        chain_name = network || configuration.chain

        if solana_chain?(chain_name)
          generator = Solana::Generator.new
          generator.generate_header(
            amount: amount,
            resource: resource,
            description: description,
            network: network,
            private_key: private_key,
            pay_to: pay_to,
            version: version,
            fee_payer: fee_payer
          )
        else
          generator = Generator.new
          generator.generate_header(
            amount: amount,
            resource: resource,
            description: description,
            network: network,
            private_key: private_key,
            pay_to: pay_to,
            extra: extra,
            version: version
          )
        end
      end

      def generate_link(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil, version: nil, fee_payer: nil)
        chain_name = network || configuration.chain
        protocol_version = version || configuration.protocol_version
        header_name = payment_header_name(protocol_version)

        if solana_chain?(chain_name)
          generator = Solana::Generator.new
          header = generator.generate_header(
            amount: amount,
            resource: resource,
            description: description,
            network: network,
            private_key: private_key,
            pay_to: pay_to,
            version: protocol_version,
            fee_payer: fee_payer
          )
          {
            payment_header: header,
            header_name: header_name,
            curl_command: "curl -s -H \"#{header_name}: #{header}\" #{resource} | jq ."
          }
        else
          generator = Generator.new
          generator.generate_link(
            amount: amount,
            resource: resource,
            description: description,
            network: network,
            private_key: private_key,
            pay_to: pay_to,
            extra: extra,
            version: version
          )
        end
      end

      def generate_header_for(payment_required, private_key: nil)
        generator = Generator.new
        generator.generate_header_for(payment_required, private_key: private_key)
      end

      def parse_402_response(response)
        ResponseParser.parse(response)
      end

      def detect_version(response)
        ResponseParser.detect_version(response)
      end

      def payment_header_name(version = nil)
        version ||= configuration.protocol_version
        case version
        when 2
          V2::Headers::PAYMENT_HEADER
        else
          V1::Headers::PAYMENT_HEADER
        end
      end

      def payment_response_header_name(version = nil)
        version ||= configuration.protocol_version
        case version
        when 2
          V2::Headers::PAYMENT_RESPONSE_HEADER
        else
          V1::Headers::PAYMENT_RESPONSE_HEADER
        end
      end

      def payment_required_header_name(version = nil)
        version ||= configuration.protocol_version
        case version
        when 2
          V2::Headers::PAYMENT_REQUIRED_HEADER
        else
          nil
        end
      end

    end
  end
end
