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

module X402
  module Payments

    class << self
      def generate_header(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil, version: nil)
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

      def generate_link(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil, version: nil)
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
