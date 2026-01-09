# frozen_string_literal: true

require "solana_ruby"
require "base64"

module X402
  module Payments
    module Solana
      COMPUTE_BUDGET_PROGRAM_ID = "ComputeBudget111111111111111111111111111111"

      class Generator
        attr_reader :config

        def initialize(config = X402::Payments.configuration)
          @config = config
        end

        def generate_header(amount:, resource:, description: nil, network: nil, private_key: nil, pay_to: nil, version: nil, fee_payer: nil)
          chain_name = network || config.chain
          raise ConfigurationError, "Solana chain required" unless X402::Payments.solana_chain?(chain_name)

          key = private_key || ENV["X402_SOL_PRIVATE_KEY"] || config.private_key
          raise ConfigurationError, "Solana private key is required (X402_SOL_PRIVATE_KEY)" if key.nil? || key.empty?

          recipient = pay_to || ENV["X402_SOL_PAY_TO"] || config.default_pay_to
          raise ConfigurationError, "Recipient address is required (X402_SOL_PAY_TO)" if recipient.nil? || recipient.empty?

          facilitator_fee_payer = fee_payer || X402::Payments.fee_payer_for(chain_name)
          raise ConfigurationError, "Facilitator fee payer is required for Solana" if facilitator_fee_payer.nil? || facilitator_fee_payer.empty?

          protocol_version = X402::Payments.normalize_version(version) || config.protocol_version
          token_config = X402::Payments.token_config_for(chain_name)
          mint_address = X402::Payments.asset_address_for(chain_name)
          decimals = token_config[:decimals]

          atomic_amount = convert_to_atomic(amount, decimals)

          keypair = load_keypair(key)
          sender_pubkey = keypair[:public_key]

          rpc_url = X402::Payments.rpc_url_for(chain_name)
          client = SolanaRuby::HttpClient.new(rpc_url)

          recent_blockhash = client.get_latest_blockhash["blockhash"]

          source_ata = derive_associated_token_address(mint_address, sender_pubkey)
          destination_ata = derive_associated_token_address(mint_address, recipient)

          serialized_tx = build_transfer_transaction(
            source_ata: source_ata,
            destination_ata: destination_ata,
            mint_address: mint_address,
            owner: sender_pubkey,
            amount: atomic_amount,
            decimals: decimals,
            recent_blockhash: recent_blockhash,
            keypair: keypair,
            fee_payer: facilitator_fee_payer
          )

          payload = build_payload(
            version: protocol_version,
            chain_name: chain_name,
            serialized_transaction: serialized_tx,
            resource: resource,
            description: description,
            mint_address: mint_address,
            recipient: recipient,
            atomic_amount: atomic_amount,
            fee_payer: facilitator_fee_payer
          )

          encode_payment(payload)
        end

        private

        def convert_to_atomic(amount, decimals)
          (amount.to_f * (10**decimals)).round
        end

        def load_keypair(private_key_input)
          if private_key_input.is_a?(Array)
            private_key_hex = private_key_input[0, 32].pack("C*").unpack1("H*")
            SolanaRuby::Keypair.from_private_key(private_key_hex)
          elsif private_key_input.start_with?("[")
            bytes = JSON.parse(private_key_input)
            private_key_hex = bytes[0, 32].pack("C*").unpack1("H*")
            SolanaRuby::Keypair.from_private_key(private_key_hex)
          elsif private_key_input.length == 64 && private_key_input.match?(/\A[0-9a-fA-F]+\z/)
            SolanaRuby::Keypair.from_private_key(private_key_input)
          else
            decoded_bytes = SolanaRuby::Utils.base58_to_bytes(private_key_input)
            private_key_hex = decoded_bytes[0, 32].pack("C*").unpack1("H*")
            SolanaRuby::Keypair.from_private_key(private_key_hex)
          end
        end

        ASSOCIATED_TOKEN_PROGRAM_ID = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
        TOKEN_PROGRAM_ID = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        ED25519_PRIME = (2**255) - 19

        def derive_associated_token_address(mint, owner)
          mint_bytes = SolanaRuby::Utils.base58_to_bytes(mint)
          owner_bytes = SolanaRuby::Utils.base58_to_bytes(owner)
          token_program_bytes = SolanaRuby::Utils.base58_to_bytes(TOKEN_PROGRAM_ID)
          ata_program_bytes = SolanaRuby::Utils.base58_to_bytes(ASSOCIATED_TOKEN_PROGRAM_ID)

          nonce = 255
          loop do
            buffer = owner_bytes.pack("C*") +
                     token_program_bytes.pack("C*") +
                     mint_bytes.pack("C*") +
                     [nonce].pack("C") +
                     ata_program_bytes.pack("C*") +
                     "ProgramDerivedAddress"

            hashed = RbNaCl::Hash.sha256(buffer)

            unless ed25519_on_curve?(hashed)
              return SolanaRuby::Utils.bytes_to_base58(hashed.bytes)
            end

            nonce -= 1
            raise "Unable to find valid PDA" if nonce < 0
          end
        end

        def ed25519_on_curve?(bytes)
          return false if bytes.length != 32

          y_bytes = bytes.bytes.dup
          y_bytes[31] &= 0x7f

          y = y_bytes.reverse.map { |b| b.to_s(16).rjust(2, "0") }.join.to_i(16)
          return false if y >= ED25519_PRIME

          d = (-121665 * mod_inverse(121666, ED25519_PRIME)) % ED25519_PRIME
          y2 = (y * y) % ED25519_PRIME
          numerator = (y2 - 1) % ED25519_PRIME
          denominator = (d * y2 + 1) % ED25519_PRIME
          x2 = (numerator * mod_inverse(denominator, ED25519_PRIME)) % ED25519_PRIME

          is_quadratic_residue?(x2, ED25519_PRIME)
        end

        def mod_inverse(a, m)
          a.pow(m - 2, m)
        end

        def is_quadratic_residue?(a, p)
          return true if a.zero?

          exp = (p - 1) / 2
          a.pow(exp, p) == 1
        end

        def build_transfer_transaction(source_ata:, destination_ata:, mint_address:, owner:, amount:, decimals:, recent_blockhash:, keypair:, fee_payer:)
          transaction = SolanaRuby::Transaction.new
          transaction.set_fee_payer(fee_payer)
          transaction.set_recent_blockhash(recent_blockhash)

          transaction.add_instruction(build_set_compute_unit_limit_instruction(config.solana_compute_unit_limit))
          transaction.add_instruction(build_set_compute_unit_price_instruction(config.solana_compute_unit_price))
          transaction.add_instruction(build_transfer_checked_instruction(
            source_ata: source_ata,
            mint_address: mint_address,
            destination_ata: destination_ata,
            owner: owner,
            amount: amount,
            decimals: decimals
          ))

          partial_sign_transaction(transaction, keypair, fee_payer)
        end

        def partial_sign_transaction(transaction, keypair, fee_payer)
          message = transaction.send(:compile_message)
          message_bytes = message.serialize

          owner_pubkey = keypair[:public_key]
          owner_privkey = keypair[:private_key]

          signing_key = RbNaCl::Signatures::Ed25519::SigningKey.new([owner_privkey].pack("H*"))
          owner_signature = signing_key.sign(message_bytes.pack("C*")).bytes

          num_signers = message.header[:num_required_signatures]
          signatures = []

          num_signers.times do |i|
            account_key = message.account_keys[i]
            if account_key == fee_payer
              signatures << Array.new(64, 0)
            elsif account_key == owner_pubkey
              signatures << owner_signature
            else
              signatures << Array.new(64, 0)
            end
          end

          signature_count = [signatures.length]
          wire_transaction = signature_count + signatures.flatten + message_bytes
          Base64.strict_encode64(wire_transaction.pack("C*"))
        end

        def build_set_compute_unit_limit_instruction(units)
          data = ([2].pack("C") + [units].pack("V")).bytes

          SolanaRuby::TransactionInstruction.new(
            program_id: COMPUTE_BUDGET_PROGRAM_ID,
            keys: [],
            data: data
          )
        end

        def build_set_compute_unit_price_instruction(micro_lamports)
          data = ([3].pack("C") + [micro_lamports].pack("Q<")).bytes

          SolanaRuby::TransactionInstruction.new(
            program_id: COMPUTE_BUDGET_PROGRAM_ID,
            keys: [],
            data: data
          )
        end

        def build_transfer_checked_instruction(source_ata:, mint_address:, destination_ata:, owner:, amount:, decimals:)
          data = ([12].pack("C") + [amount].pack("Q<") + [decimals].pack("C")).bytes

          SolanaRuby::TransactionInstruction.new(
            program_id: SolanaRuby::TransactionHelper::TOKEN_PROGRAM_ID,
            keys: [
              { pubkey: source_ata, is_signer: false, is_writable: true },
              { pubkey: mint_address, is_signer: false, is_writable: false },
              { pubkey: destination_ata, is_signer: false, is_writable: true },
              { pubkey: owner, is_signer: true, is_writable: false }
            ],
            data: data
          )
        end

        def build_payload(version:, chain_name:, serialized_transaction:, resource:, description:, mint_address:, recipient:, atomic_amount:, fee_payer:)
          network = version == 2 ? Networks.to_caip2(chain_name) : chain_name

          case version
          when 2
            {
              x402Version: 2,
              resource: {
                url: resource,
                description: description || "Payment required for #{resource}",
                mimeType: "application/json"
              },
              accepted: {
                scheme: "exact",
                network: network,
                amount: atomic_amount.to_s,
                asset: mint_address,
                payTo: recipient,
                maxTimeoutSeconds: config.max_timeout_seconds,
                extra: {
                  feePayer: fee_payer
                }.compact
              },
              payload: {
                transaction: serialized_transaction
              },
              extensions: {}
            }
          else
            {
              x402Version: 1,
              scheme: "exact",
              network: network,
              payload: {
                transaction: serialized_transaction
              }
            }
          end
        end

        def encode_payment(payment_payload)
          json_str = JSON.generate(payment_payload)
          Base64.strict_encode64(json_str)
        end
      end
    end
  end
end
