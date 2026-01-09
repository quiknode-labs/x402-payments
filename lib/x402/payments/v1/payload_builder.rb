# frozen_string_literal: true

module X402
  module Payments
    module V1
      class PayloadBuilder
        attr_reader :authorization, :signature, :scheme, :network

        def initialize(authorization:, signature:, scheme:, network:)
          @authorization = authorization
          @signature = signature
          @scheme = scheme
          @network = network
        end

        def build
          {
            x402Version: 1,
            scheme: scheme,
            network: network,
            payload: {
              signature: signature,
              authorization: {
                from: authorization[:from],
                to: authorization[:to],
                value: authorization[:value],
                validAfter: authorization[:valid_after],
                validBefore: authorization[:valid_before],
                nonce: authorization[:nonce]
              }
            }
          }
        end

        class << self
          def build(authorization:, signature:, scheme:, network:)
            new(
              authorization: authorization,
              signature: signature,
              scheme: scheme,
              network: network
            ).build
          end
        end
      end
    end
  end
end
