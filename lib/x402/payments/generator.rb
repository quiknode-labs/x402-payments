# frozen_string_literal: true

require "eth"
require "json"
require "base64"
require "securerandom"
require "time"

module X402
  module Payments
    class Generator
      attr_reader :config

      def initialize(config = X402::Payments.configuration)
        @config = config
      end

      def generate_header(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil, version: nil)
        config.validate!

        protocol_version = X402::Payments.normalize_version(version) || config.protocol_version
        chain_name = network || config.chain
        key = private_key || config.private_key
        recipient = pay_to || config.default_pay_to

        token_config = X402::Payments.token_config_for(chain_name)
        asset_address = X402::Payments.asset_address_for(chain_name)

        atomic_amount = convert_to_atomic(amount, token_config[:decimals])

        account = Eth::Key.new(priv: key)
        sender_address = account.address.to_s

        nonce_bytes = SecureRandom.random_bytes(32)
        nonce_hex = "0x#{nonce_bytes.unpack1('H*')}"

        valid_after = (Time.now.to_i - 60).to_s
        valid_before = (Time.now.to_i + config.max_timeout_seconds).to_s

        authorization = {
          from: sender_address,
          to: recipient,
          value: atomic_amount.to_s,
          valid_after: valid_after,
          valid_before: valid_before,
          nonce: nonce_hex
        }

        extra_data = extra || {
          name: token_config[:name],
          version: token_config[:version]
        }

        signature = sign_authorization(
          account: account,
          authorization: authorization,
          chain_name: chain_name,
          asset: asset_address,
          extra: extra_data,
          nonce_bytes: nonce_bytes
        )

        payload = build_payload(
          version: protocol_version,
          authorization: authorization,
          signature: signature,
          resource: resource,
          description: description,
          chain_name: chain_name,
          asset_address: asset_address,
          atomic_amount: atomic_amount,
          recipient: recipient,
          extra: extra_data
        )

        encode_payment(payload)
      end

      def generate_header_for(payment_required, private_key: nil)
        key = private_key || config.private_key
        raise ConfigurationError, "private_key is required" if key.nil? || key.empty?

        version = X402::Payments.normalize_version(payment_required[:version]) || 1
        accepts = payment_required[:accepts]&.first
        raise Error, "No payment requirements found" unless accepts

        resource_info = payment_required[:resource] || {}
        chain_name = resolve_chain_name(accepts[:network])
        token_config = X402::Payments.token_config_for(chain_name)

        account = Eth::Key.new(priv: key)
        sender_address = account.address.to_s

        nonce_bytes = SecureRandom.random_bytes(32)
        nonce_hex = "0x#{nonce_bytes.unpack1('H*')}"

        valid_after = (Time.now.to_i - 60).to_s
        valid_before = (Time.now.to_i + (accepts[:max_timeout_seconds] || config.max_timeout_seconds)).to_s

        authorization = {
          from: sender_address,
          to: accepts[:pay_to],
          value: accepts[:amount],
          valid_after: valid_after,
          valid_before: valid_before,
          nonce: nonce_hex
        }

        extra_data = accepts[:extra] || {}
        extra_data = {
          name: extra_data[:name] || extra_data["name"] || token_config[:name],
          version: extra_data[:version] || extra_data["version"] || token_config[:version]
        }

        signature = sign_authorization(
          account: account,
          authorization: authorization,
          chain_name: chain_name,
          asset: accepts[:asset],
          extra: extra_data,
          nonce_bytes: nonce_bytes
        )

        payload = case version
                  when 2
                    V2::PayloadBuilder.build(
                      authorization: authorization,
                      signature: signature,
                      resource: {
                        url: resource_info[:url],
                        description: resource_info[:description],
                        mime_type: resource_info[:mime_type]
                      },
                      accepted: {
                        scheme: accepts[:scheme],
                        network: accepts[:network],
                        amount: accepts[:amount],
                        asset: accepts[:asset],
                        pay_to: accepts[:pay_to],
                        max_timeout_seconds: accepts[:max_timeout_seconds],
                        extra: extra_data
                      },
                      extensions: payment_required[:extensions] || {}
                    )
                  else
                    V1::PayloadBuilder.build(
                      authorization: authorization,
                      signature: signature,
                      scheme: accepts[:scheme],
                      network: chain_name
                    )
                  end

        encode_payment(payload)
      end

      def generate_link(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil, version: nil)
        protocol_version = X402::Payments.normalize_version(version) || config.protocol_version
        header = generate_header(
          amount: amount,
          resource: resource,
          description: description,
          network: network,
          private_key: private_key,
          pay_to: pay_to,
          extra: extra,
          version: protocol_version
        )

        header_name = X402::Payments.payment_header_name(protocol_version)

        {
          payment_header: header,
          header_name: header_name,
          curl_command: "curl -s -H \"#{header_name}: #{header}\" #{resource} | jq ."
        }
      end

      private

      def resolve_chain_name(network)
        if Networks.caip2_format?(network)
          Networks.from_caip2(network)
        else
          network
        end
      end

      def convert_to_atomic(amount, decimals)
        (amount.to_f * (10**decimals)).round
      end

      def sign_authorization(account:, authorization:, chain_name:, asset:, extra:, nonce_bytes:)
        typed_data = {
          types: {
            EIP712Domain: [
              { name: "name", type: "string" },
              { name: "version", type: "string" },
              { name: "chainId", type: "uint256" },
              { name: "verifyingContract", type: "address" }
            ],
            TransferWithAuthorization: [
              { name: "from", type: "address" },
              { name: "to", type: "address" },
              { name: "value", type: "uint256" },
              { name: "validAfter", type: "uint256" },
              { name: "validBefore", type: "uint256" },
              { name: "nonce", type: "bytes32" }
            ]
          },
          primaryType: "TransferWithAuthorization",
          domain: {
            name: extra[:name] || extra["name"],
            version: extra[:version] || extra["version"],
            chainId: X402::Payments.chain_id_for(chain_name),
            verifyingContract: asset
          },
          message: {
            from: authorization[:from],
            to: authorization[:to],
            value: authorization[:value].to_i,
            validAfter: authorization[:valid_after].to_i,
            validBefore: authorization[:valid_before].to_i,
            nonce: nonce_bytes
          }
        }

        signature = account.sign_typed_data(typed_data)
        signature = "0x#{signature}" unless signature.start_with?("0x")
        signature
      end

      def build_payload(version:, authorization:, signature:, resource:, description:, chain_name:, asset_address:, atomic_amount:, recipient:, extra:)
        case version
        when 2
          V2::PayloadBuilder.build(
            authorization: authorization,
            signature: signature,
            resource: {
              url: resource,
              description: description || "Payment required for #{resource}",
              mime_type: "application/json"
            },
            accepted: {
              scheme: "exact",
              network: Networks.to_caip2(chain_name),
              amount: atomic_amount.to_s,
              asset: asset_address,
              pay_to: recipient,
              max_timeout_seconds: config.max_timeout_seconds,
              extra: extra
            }
          )
        else
          V1::PayloadBuilder.build(
            authorization: authorization,
            signature: signature,
            scheme: "exact",
            network: chain_name
          )
        end
      end

      def encode_payment(payment_payload)
        json_str = JSON.generate(payment_payload)
        Base64.strict_encode64(json_str)
      end
    end
  end
end
