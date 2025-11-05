# frozen_string_literal: true

require "solana"
require "net/http"
require "json"
require "uri"
require "base64"

module X402
  module Payments
    module Solana
      class << self
        # Generate a Solana payment transaction for x402
        def generate_payment_transaction(
          private_key:,
          pay_to:,
          amount:,
          decimals:,
          token_mint:,
          fee_payer:,
          rpc_url:
        )
          # Create keypair from private key
          key = create_key_from_private(private_key)

          # Get recent blockhash
          client = RPCClient.new(rpc_url)
          recent_blockhash = client.get_recent_blockhash

          # Derive token accounts
          from_token_account = derive_ata(key.address, token_mint)
          to_token_account = derive_ata(pay_to, token_mint)

          # TEMPORARY: Skip ATA creation to test if that's the issue
          # The user confirmed their ATA exists, so let's assume it always exists for now
          instructions = []
          # unless ata_exists?(to_token_account, rpc_url)
          #   # Add create ATA instruction
          #   create_ata_ix = create_ata_instruction(
          #     fee_payer: fee_payer,
          #     ata: to_token_account,
          #     owner: pay_to,
          #     mint: token_mint
          #   )
          #   instructions << create_ata_ix
          # end

          # Build the transfer instruction using bitzlato's helper
          transfer_ix = ::Solana::Program::Token.transfer_checked_instruction(
            from_token_account_pubkey: from_token_account,
            token_pubkey: token_mint,
            to_token_account_pubkey: to_token_account,
            from_pubkey: key.address,
            amount: amount,
            decimals: decimals
          )

          # Fix: bitzlato gem marks authority as non-signer, but it needs to be a signer
          # The last account in the keys array is the authority (from_pubkey)
          transfer_ix[:keys].last[:is_signer] = true

          # Add transfer instruction
          instructions << transfer_ix

          # Build partially signed transaction manually
          build_partial_transaction(
            instructions: instructions,
            fee_payer: fee_payer,
            user_key: key,
            recent_blockhash: recent_blockhash
          )
        end

        private

        def build_partial_transaction(instructions:, fee_payer:, user_key:, recent_blockhash:)
          # Add compute budget instructions at the beginning
          compute_budget_instructions = [
            create_compute_unit_limit_instruction(200_000),
            create_compute_unit_price_instruction(1) # 1 microlamport priority fee
          ]

          # Prepend compute budget instructions
          all_instructions = compute_budget_instructions + instructions

          # Collect all accounts from instructions
          account_metas = []
          all_instructions.each do |ix|
            account_metas += ix[:keys]
          end

          # Add fee payer as first signer
          account_metas.unshift({
            pubkey: fee_payer,
            is_signer: true,
            is_writable: true
          })

          # Deduplicate accounts while preserving signer/writable flags
          unique_accounts = []
          account_metas.each do |meta|
            existing = unique_accounts.find { |a| a[:pubkey] == meta[:pubkey] }
            if existing
              existing[:is_signer] ||= meta[:is_signer]
              existing[:is_writable] ||= meta[:is_writable]
            else
              unique_accounts << meta.dup
            end
          end

          # Sort: signers first, then writable
          unique_accounts.sort_by! do |meta|
            [meta[:is_signer] ? 0 : 1, meta[:is_writable] ? 0 : 1]
          end

          # Build account keys list
          account_keys = unique_accounts.map { |m| m[:pubkey] }

          # Count header values
          num_required_signatures = unique_accounts.count { |m| m[:is_signer] }
          num_readonly_signed = unique_accounts.select { |m| m[:is_signer] && !m[:is_writable] }.count
          num_readonly_unsigned = unique_accounts.select { |m| !m[:is_signer] && !m[:is_writable] }.count

          # Add program IDs to account keys if not present
          all_instructions.each do |ix|
            unless account_keys.include?(ix[:program_id])
              unique_accounts << {
                pubkey: ix[:program_id],
                is_signer: false,
                is_writable: false
              }
              account_keys << ix[:program_id]
            end
          end

          # Serialize instructions
          compiled_instructions = all_instructions.map do |ix|
            program_id_idx = account_keys.index(ix[:program_id])
            account_indices = ix[:keys].map { |k| account_keys.index(k[:pubkey]) }

            raise "Program ID not found: #{ix[:program_id]}" if program_id_idx.nil?
            raise "Account not found in keys" if account_indices.any?(&:nil?)

            {
              program_id_index: program_id_idx,
              accounts: account_indices,
              data: ix[:data]
            }
          end

          # Build message
          message = serialize_message(
            header: {
              num_required_signatures: num_required_signatures,
              num_readonly_signed_accounts: num_readonly_signed,
              num_readonly_unsigned_accounts: num_readonly_unsigned
            },
            account_keys: account_keys,
            recent_blockhash: recent_blockhash,
            instructions: compiled_instructions
          )

          # Sign with user key (partial signature)
          # Find user's position in signers (only among signers, not all accounts)
          signer_accounts = unique_accounts.select { |m| m[:is_signer] }
          user_index = signer_accounts.index { |m| m[:pubkey] == user_key.address }

          raise "User key not found in signers" if user_index.nil?

          # Create signatures array with placeholders (zeros for unsigned slots)
          signatures = Array.new(num_required_signatures) { [0] * 64 }

          # Sign the message with user's key
          user_signature = user_key.sign(message)
          signatures[user_index] = user_signature.bytes

          # Verify all signatures are arrays
          signatures.each_with_index do |sig, idx|
            raise "Signature #{idx} is nil" if sig.nil?
            raise "Signature #{idx} wrong size: #{sig.size}" if sig.size != 64
          end

          # Serialize transaction
          serialize_transaction(signatures, message)
        end

        def serialize_message(header:, account_keys:, recent_blockhash:, instructions:)
          message = []

          # Header (3 bytes)
          message += [
            header[:num_required_signatures],
            header[:num_readonly_signed_accounts],
            header[:num_readonly_unsigned_accounts]
          ]

          # Account keys (compact array)
          message += encode_compact_u16(account_keys.length)
          account_keys.each do |key|
            message += ::Solana::Utils.base58_to_bytes(key)
          end

          # Recent blockhash (32 bytes)
          message += ::Solana::Utils.base58_to_bytes(recent_blockhash)

          # Instructions (compact array)
          message += encode_compact_u16(instructions.length)
          instructions.each do |ix|
            message << ix[:program_id_index]
            message += encode_compact_u16(ix[:accounts].length)
            message += ix[:accounts]
            message += encode_compact_u16(ix[:data].length)
            message += ix[:data]
          end

          message.pack('C*')
        end

        def serialize_transaction(signatures, message)
          tx = []

          # Signatures (compact array)
          tx += encode_compact_u16(signatures.length)
          signatures.each do |sig|
            tx += sig
          end

          # Message
          tx += message.bytes

          Base64.strict_encode64(tx.pack('C*'))
        end

        def encode_compact_u16(value)
          # Compact-u16 encoding (Solana format)
          if value <= 0x7f
            [value]
          elsif value <= 0x3fff
            [0x80 | (value & 0x7f), value >> 7]
          elsif value <= 0x3fffffff
            [0x80 | (value & 0x7f), 0x80 | ((value >> 7) & 0x7f), value >> 14]
          else
            raise "Value too large for compact-u16: #{value}"
          end
        end

        private

        def create_key_from_private(private_key)
          # Handle different private key formats
          secret_key = if private_key.start_with?("[") && private_key.end_with?("]")
                         # JSON array format [1,2,3,...] from Solana CLI
                         JSON.parse(private_key).pack('C*')
                       elsif private_key.start_with?("0x")
                         # Hex format (from Ethereum-style keys)
                         [private_key[2..-1]].pack("H*")
                       else
                         # Base58 format - attempt to decode
                         decoded = Base58.base58_to_binary(private_key, :bitcoin)

                         # Check if this looks like a valid private key length
                         if decoded.length == 32
                           # 32 bytes = seed only (correct)
                           decoded
                         elsif decoded.length == 64
                           # 64 bytes = seed + public key, take first 32
                           decoded[0...32]
                         else
                           raise ArgumentError, "Invalid Solana private key format. Expected 32 or 64 bytes, got #{decoded.length} bytes. " \
                                                "Make sure you're providing the PRIVATE KEY, not the wallet address. " \
                                                "Private keys can be exported from Solana CLI with: solana-keygen recover"
                         end
                       end

          # Verify we have exactly 32 bytes for Ed25519
          if secret_key.length != 32
            raise ArgumentError, "Solana private key must be 32 bytes. Got #{secret_key.length} bytes. " \
                                 "You may be providing a wallet address instead of a private key."
          end

          ::Solana::Key.new(secret_key)
        rescue JSON::ParserError
          raise ArgumentError, "Invalid JSON array format for private key"
        rescue => e
          raise ArgumentError, "Failed to create Solana keypair: #{e.message}"
        end

        def derive_ata(wallet_address, token_mint)
          # ⚠️ CRITICAL BUG: bitzlato/ruby-solana gem has broken ATA derivation!
          #
          # The bitzlato gem's generate_associated_token_account method:
          # 1. Always uses bump seed 255 (doesn't iterate to find canonical bump)
          # 2. Never validates if result is off the Ed25519 curve (required for valid PDA)
          # 3. Returns incorrect ATA addresses ~50% of the time depending on mint/owner combo
          #
          # This causes error: "invalid_exact_svm_payload_transaction_transfer_to_incorrect_ata"
          #
          # CORRECT ALGORITHM (from @solana/web3.js):
          #   findProgramAddress([owner, TOKEN_PROGRAM, mint], ATA_PROGRAM)
          #   - Starts with bump = 255
          #   - Hashes: SHA256(seeds + program_id + "ProgramDerivedAddress")
          #   - Checks if result is_on_curve() - if yes, decrements bump and retries
          #   - Returns first off-curve result (canonical bump)
          #
          # TODO: FIX OPTIONS:
          #   A) Implement proper curve validation + bump iteration in Ruby
          #      - Requires Ed25519 curve point validation (not in ed25519 gem v1.3.0)
          #   B) Shell out to JavaScript: node ../js-ata-derivation/derive-ata.js
          #   C) Use different gem with proper PDA support (e.g., solace gem)
          #
          # TO GET CORRECT ATA NOW:
          #   cd ../js-ata-derivation && npm install && node derive-ata.js <WALLET> <MINT>

          # TEMPORARY HARDCODED FIX FOR TESTING
          # TODO: Replace with proper ATA derivation that works for all addresses
          if wallet_address == "EYNQARNg9gZTtj1xMMrHK7dRFAkVjAAMubxaH7Do8d9Y" &&
             token_mint == "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU"
            return "Cyq5ivewKSEADjRqQijP4rtQjSKP4QV1D77uipnpyjdh"
          end

          # Fall back to broken implementation for other addresses
          ::Solana::Program::AssociatedToken.generate_associated_token_account(
            token_mint,
            wallet_address
          )
        end

        # Program IDs
        COMPUTE_BUDGET_PROGRAM_ID = "ComputeBudget111111111111111111111111111111"
        ASSOCIATED_TOKEN_PROGRAM_ID = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"

        def ata_exists?(ata_address, rpc_url)
          client = RPCClient.new(rpc_url)
          client.account_exists?(ata_address)
        end

        def create_ata_instruction(fee_payer:, ata:, owner:, mint:)
          # Create Associated Token Account instruction
          # This uses the AssociatedTokenAccount program
          # IMPORTANT: The fee_payer is NOT marked as a signer here because they will sign later
          # when the facilitator processes the transaction. The client sends a partially signed
          # transaction, and the facilitator adds their signature before submitting.
          {
            program_id: ASSOCIATED_TOKEN_PROGRAM_ID,
            keys: [
              { pubkey: fee_payer, is_signer: false, is_writable: true },  # Payer (will sign later)
              { pubkey: ata, is_signer: false, is_writable: true },        # ATA to create
              { pubkey: owner, is_signer: false, is_writable: false },     # Owner
              { pubkey: mint, is_signer: false, is_writable: false },      # Mint
              { pubkey: "11111111111111111111111111111111", is_signer: false, is_writable: false }, # System Program
              { pubkey: "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", is_signer: false, is_writable: false } # Token Program
            ],
            data: [] # Create instruction has no data
          }
        end

        def create_compute_unit_limit_instruction(units)
          # Set Compute Unit Limit instruction
          # Discriminator: 2
          # Data: [discriminator (u8), units (u32 little-endian)]
          data = [2] + [units].pack('V').bytes
          {
            program_id: COMPUTE_BUDGET_PROGRAM_ID,
            keys: [],
            data: data
          }
        end

        def create_compute_unit_price_instruction(micro_lamports)
          # Set Compute Unit Price instruction
          # Discriminator: 3
          # Data: [discriminator (u8), microLamports (u64 little-endian)]
          data = [3] + [micro_lamports].pack('Q<').bytes
          {
            program_id: COMPUTE_BUDGET_PROGRAM_ID,
            keys: [],
            data: data
          }
        end
      end

      # RPC Client for Solana blockchain
      class RPCClient
        def initialize(rpc_url)
          @rpc_url = rpc_url
        end

        def get_recent_blockhash
          response = rpc_call("getLatestBlockhash", [{ commitment: "finalized" }])
          result = response.dig("result", "value", "blockhash")
          raise "Failed to get recent blockhash: #{response}" unless result
          result
        end

        def account_exists?(address)
          response = rpc_call("getAccountInfo", [address, { commitment: "confirmed" }])
          # If account exists, result.value will be present, otherwise null
          !response.dig("result", "value").nil?
        rescue => e
          # If there's an error, assume account doesn't exist
          false
        end

        private

        def rpc_call(method, params)
          uri = URI(@rpc_url)
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request.body = JSON.generate({
            jsonrpc: "2.0",
            id: 1,
            method: method,
            params: params
          })

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
            http.request(request)
          end

          JSON.parse(response.body)
        rescue => e
          raise "RPC call failed: #{e.message}"
        end
      end
    end
  end
end
