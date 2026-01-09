# X402 Payments Examples

This directory contains example scripts demonstrating how to use the x402-payments gem.

## generate_payment.rb

Generates a signed payment header and curl command for testing x402 payments on EVM chains and Solana.

### Setup

First, create a `.env` file in the `examples/` directory with your credentials:

```bash
cd examples
cp .env.example .env
# Edit .env with your actual values
```

### Usage

```bash
# From the gem root directory
cd /path/to/x402-payments

# Load environment variables and run
export $(cat examples/.env | xargs)
ruby examples/generate_payment.rb

# Or set variables inline (EVM)
X402_PRIVATE_KEY="0xYourPrivateKey" \
X402_PAY_TO="0xYourRecipientAddress" \
ruby examples/generate_payment.rb

# Or set variables inline (Solana)
X402_SOL_PRIVATE_KEY="YourBase58PrivateKey" \
X402_SOL_PAY_TO="YourSolanaWalletAddress" \
ruby examples/generate_payment.rb -c solana-devnet
```

### Command Line Options

```bash
ruby examples/generate_payment.rb [options]

Options:
  -v, --version VERSION    Protocol version (1 or 2, default: 2)
  -c, --chain CHAIN        Chain name (e.g., base-sepolia, solana-devnet)
  -h, --help               Show help
```

### Examples

```bash
# EVM: Use v2 protocol on Base Sepolia (default)
ruby examples/generate_payment.rb -v 2

# EVM: Use Polygon Amoy testnet (custom chain)
ruby examples/generate_payment.rb -c polygon-amoy -v 2

# EVM: Use built-in Base Sepolia with v1
ruby examples/generate_payment.rb -c base-sepolia -v 1

# Solana: Use Solana devnet
ruby examples/generate_payment.rb -c solana-devnet -v 2

# Solana: Use Solana mainnet
ruby examples/generate_payment.rb -c solana -v 2
```

### Environment Variables

**EVM chains:**
- `X402_PRIVATE_KEY` - EVM private key for signing (required for EVM)
- `X402_PAY_TO` - EVM recipient wallet address (required for EVM)

**Solana chains:**
- `X402_SOL_PRIVATE_KEY` - Solana private key in base58 or JSON array format (required for Solana)
- `X402_SOL_PAY_TO` - Solana recipient wallet address (required for Solana)
- `X402_SOLANA_FEE_PAYER` - Facilitator fee payer (optional, defaults to x402.org facilitator)
- `X402_SOLANA_COMPUTE_UNIT_LIMIT` - Compute unit limit (optional, default: 200000)
- `X402_SOLANA_COMPUTE_UNIT_PRICE` - Priority fee in micro-lamports (optional, default: 1000)

**General:**
- `X402_CHAIN` - Network to use (default: `base-sepolia`, can be overridden with `-c`)

### Supported Chains

**EVM chains (built-in):**
- `base-sepolia` (testnet) - default
- `base` (mainnet)
- `avalanche-fuji` (testnet)
- `avalanche` (mainnet)

**Solana chains (built-in):**
- `solana-devnet` (testnet)
- `solana` (mainnet)

**Custom EVM chains (pre-configured in example):**
- `polygon-amoy` (Polygon testnet, chain ID: 80002)
- `polygon` (Polygon mainnet, chain ID: 137)

### Example Output (EVM)

```
=== X402 Payment Generator (V2) ===
Chain: base-sepolia
CAIP-2: eip155:84532
Protocol Version: 2

Resource: http://localhost:3000/api/v2/weather/paywalled_info
Amount: $0.001 USD

Header Name: PAYMENT-SIGNATURE

Payment Header:
eyJ4NDAyVmVyc2lvbiI6Miwic...

Curl Command:
curl -s -H "PAYMENT-SIGNATURE: eyJ4NDAyVmVyc2lvbiI6Miwic..." http://localhost:3000/api/v2/weather/paywalled_info | jq .
```

### Example Output (Solana)

```
=== X402 Payment Generator (V2) ===
Chain: solana-devnet (Solana)
CAIP-2: solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1
Protocol Version: 2

Resource: http://localhost:3000/api/v2/weather/paywalled_info_sol
Amount: $0.001 USD

Header Name: PAYMENT-SIGNATURE

Payment Header:
eyJ4NDAyVmVyc2lvbiI6Miwic...

Curl Command:
curl -s -H "PAYMENT-SIGNATURE: eyJ4NDAyVmVyc2lvbiI6Miwic..." http://localhost:3000/api/v2/weather/paywalled_info_sol | jq .
```

You can copy and paste the curl command to test your x402-enabled API endpoint.

## Customizing the Script

You can modify `generate_payment.rb` to:

- Change the amount (e.g., `amount = 0.005` for $0.005)
- Target different resources (e.g., `resource_url = "https://api.example.com/data"`)
- Use different networks (set `X402_CHAIN` environment variable or `-c` flag)
- Add custom descriptions
- Override the fee payer for Solana transactions

### Example: Generate EVM Payment Programmatically

```ruby
require 'x402/payments'

X402::Payments.configure do |config|
  config.private_key = ENV['X402_PRIVATE_KEY']
  config.default_pay_to = ENV['X402_PAY_TO']
  config.chain = 'base-sepolia'
end

link = X402::Payments.generate_link(
  amount: 0.005,
  resource: "http://localhost:3000/api/premium/data",
  description: "Premium API access"
)

puts link[:curl_command]
```

### Example: Generate Solana Payment Programmatically

```ruby
require 'x402/payments'

X402::Payments.configure do |config|
  config.private_key = ENV['X402_SOL_PRIVATE_KEY']
  config.default_pay_to = ENV['X402_SOL_PAY_TO']
  config.chain = 'solana-devnet'
end

link = X402::Payments.generate_link(
  amount: 0.001,
  resource: "http://localhost:3000/api/sol/data",
  description: "Solana payment",
  # fee_payer: "CustomFeePayerAddress"  # Optional: override default facilitator
)

puts link[:curl_command]
```

### Solana Notes

- Both sender and receiver must have a USDC Associated Token Account (ATA)
- The sender must have USDC in their wallet
- Transactions are partially signed by the sender; the facilitator adds the fee payer signature
- Default facilitator is x402.org (`CKPKJWNdJEqa81x7CkZ14BVPiY6y16Sxs7owznqtWYp5`)
