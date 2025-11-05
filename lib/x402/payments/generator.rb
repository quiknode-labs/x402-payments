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

      def generate_header(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil)
        config.validate!

        chain_name = network || config.chain
        key = private_key || config.private_key
        recipient = pay_to || config.default_pay_to

        # Route to appropriate chain handler
        if X402::Payments.svm_chain?(chain_name)
          generate_solana_header(
            amount: amount,
            resource: resource,
            description: description,
            chain_name: chain_name,
            key: key,
            recipient: recipient,
            extra: extra
          )
        else
          generate_evm_header(
            amount: amount,
            resource: resource,
            description: description,
            chain_name: chain_name,
            key: key,
            recipient: recipient,
            extra: extra
          )
        end
      end

      def generate_link(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, extra: nil)
        header = generate_header(
          amount: amount,
          resource: resource,
          description: description,
          network: network,
          private_key: private_key,
          pay_to: pay_to,
          extra: extra
        )

        {
          payment_header: header,
          curl_command: "curl -s -H \"X-PAYMENT: #{header}\" #{resource} | jq ."
        }
      end

      private

      def generate_evm_header(amount:, resource:, description:, chain_name:, key:, recipient:, extra:)
        chain_config = X402::Payments.chain_config(chain_name)
        currency_config = X402::Payments.currency_config_for_chain(chain_name)

        # Convert amount to atomic units
        atomic_amount = convert_to_atomic(amount, currency_config[:decimals])

        # Get the Ethereum account from private key
        account = Eth::Key.new(priv: key)
        sender_address = account.address.to_s

        # Create nonce (32 random bytes)
        nonce = SecureRandom.random_bytes(32)

        # Build payment requirements
        payment_requirements = {
          scheme: "exact",
          network: chain_name,
          max_amount_required: atomic_amount.to_s,
          asset: chain_config[:usdc_address],
          pay_to: recipient,
          resource: resource,
          description: description || "Payment required for #{resource}",
          max_timeout_seconds: config.max_timeout_seconds,
          mime_type: "application/json",
          extra: extra || {
            name: currency_config[:name],
            version: currency_config[:version]
          }
        }

        # Prepare unsigned payment header
        valid_after = (Time.now.to_i - 60).to_s
        valid_before = (Time.now.to_i + config.max_timeout_seconds).to_s

        header = {
          x402Version: 1,
          scheme: "exact",
          network: chain_name,
          payload: {
            signature: nil,
            authorization: {
              from: sender_address,
              to: recipient,
              value: atomic_amount.to_s,
              validAfter: valid_after,
              validBefore: valid_before,
              nonce: "0x#{nonce.unpack1('H*')}"
            }
          }
        }

        # Sign the payment header
        signature = sign_payment(account, header, payment_requirements, nonce)
        header[:payload][:signature] = signature

        # Encode to base64
        encode_payment(header)
      end

      def generate_solana_header(amount:, resource:, description:, chain_name:, key:, recipient:, extra:)
        chain_config = X402::Payments.chain_config(chain_name)
        currency_config = X402::Payments.currency_config_for_chain(chain_name)

        # Convert amount to atomic units
        atomic_amount = convert_to_atomic(amount, currency_config[:decimals])

        # Get fee payer from config or extra
        fee_payer = config.solana_fee_payer

        # Get RPC URL
        rpc_url = X402::Payments.rpc_url_for(chain_name)

        # Generate Solana transaction
        transaction_base64 = X402::Payments::Solana.generate_payment_transaction(
          private_key: key,
          pay_to: recipient,
          amount: atomic_amount,
          decimals: currency_config[:decimals],
          token_mint: chain_config[:usdc_address],
          fee_payer: fee_payer,
          rpc_url: rpc_url
        )

        # Build Solana payment header
        header = {
          x402Version: 1,
          scheme: "exact",
          network: chain_name,
          payload: {
            transaction: transaction_base64
          }
        }

        # Encode to base64
        encode_payment(header)
      end

      def convert_to_atomic(amount, decimals)
        (amount.to_f * (10**decimals)).to_i
      end

      def sign_payment(account, header, payment_requirements, nonce_bytes)
        auth = header[:payload][:authorization]
        extra = payment_requirements[:extra]
        chain_name = payment_requirements[:network]
        asset = payment_requirements[:asset]

        # Build EIP-712 typed data
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
            name: extra[:name],
            version: extra[:version],
            chainId: X402::Payments.chain_id_for(chain_name),
            verifyingContract: asset
          },
          message: {
            from: auth[:from],
            to: auth[:to],
            value: auth[:value].to_i,
            validAfter: auth[:validAfter].to_i,
            validBefore: auth[:validBefore].to_i,
            nonce: nonce_bytes
          }
        }

        # Sign using eth gem
        signature = account.sign_typed_data(typed_data)

        # Ensure signature has 0x prefix
        signature = "0x#{signature}" unless signature.start_with?("0x")
        signature
      end

      def encode_payment(payment_payload)
        json_str = JSON.generate(payment_payload)
        Base64.strict_encode64(json_str)
      end
    end
  end
end
