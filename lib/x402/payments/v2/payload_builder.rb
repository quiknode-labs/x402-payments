# frozen_string_literal: true

module X402
  module Payments
    module V2
      class PayloadBuilder
        attr_reader :authorization, :signature, :resource, :accepted, :extensions

        def initialize(authorization:, signature:, resource:, accepted:, extensions: {})
          @authorization = authorization
          @signature = signature
          @resource = resource
          @accepted = accepted
          @extensions = extensions || {}
        end

        def build
          {
            x402Version: 2,
            resource: build_resource,
            accepted: build_accepted,
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
            },
            extensions: extensions
          }
        end

        private

        def build_resource
          {
            url: resource[:url],
            description: resource[:description],
            mimeType: resource[:mime_type] || "application/json"
          }
        end

        def build_accepted
          {
            scheme: accepted[:scheme],
            network: accepted[:network],
            amount: accepted[:amount],
            asset: accepted[:asset],
            payTo: accepted[:pay_to],
            maxTimeoutSeconds: accepted[:max_timeout_seconds],
            extra: accepted[:extra]
          }.compact
        end

        class << self
          def build(authorization:, signature:, resource:, accepted:, extensions: {})
            new(
              authorization: authorization,
              signature: signature,
              resource: resource,
              accepted: accepted,
              extensions: extensions
            ).build
          end
        end
      end
    end
  end
end
