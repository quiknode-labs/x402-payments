# frozen_string_literal: true

require_relative "payments/version"
require_relative "payments/configuration"
require_relative "payments/chains"
require_relative "payments/generator"

module X402
  module Payments
    class Error < StandardError; end

    class << self
      def generate_header(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil)
        generator = Generator.new
        generator.generate_header(
          amount: amount,
          resource: resource,
          description: description,
          network: network,
          private_key: private_key,
          pay_to: pay_to,
          extra: extra
        )
      end

      def generate_link(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil)
        generator = Generator.new
        generator.generate_link(
          amount: amount,
          resource: resource,
          description: description,
          network: network,
          private_key: private_key,
          pay_to: pay_to,
          extra: extra
        )
      end
    end
  end
end
