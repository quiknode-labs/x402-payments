# X402::Payments

![Coverage](./coverage/coverage.svg)

Ruby gem for generating signed payment HTTP headers and links using the [x402 protocol](https://www.x402.org/).

Supports USDC payments on:
- **EVM networks**: Base, Avalanche with EIP-712 signing
- **Solana**: Devnet and Mainnet with SPL token transfers

## Installation

### System Requirements

This gem depends on the `eth` gem which requires native extensions for cryptographic operations. You'll need to install system dependencies first:

#### macOS

```bash
brew install automake openssl libtool pkg-config gmp libffi
```

#### Ubuntu/Debian

```bash
sudo apt-get install build-essential libgmp-dev libssl-dev
```

#### Alpine Linux

```bash
apk add build-base gmp-dev openssl-dev autoconf automake libtool
```

### Installing the Gem

Add this line to your application's Gemfile:

```ruby
gem 'x402-payments'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install x402-payments
```

## Configuration

The gem uses environment variables for configuration with sensible defaults:

### EVM Chains (Base, Avalanche)

```bash
# Required
export X402_PAY_TO="0xYourWalletAddress"          # Default address to receive payments
export X402_PRIVATE_KEY="0xYourPrivateKey"        # Private key for signing

# Optional (with defaults shown)
export X402_CHAIN="base-sepolia"                  # Network to use
export X402_MAX_TIMEOUT_SECONDS="600"             # Payment validity timeout

# Optional: Custom RPC URLs (override default RPC endpoints)
export X402_BASE_RPC_URL="https://your-custom-rpc.com"
export X402_BASE_SEPOLIA_RPC_URL="https://your-sepolia-rpc.com"
export X402_AVALANCHE_RPC_URL="https://your-avax-rpc.com"
export X402_AVALANCHE_FUJI_RPC_URL="https://your-avax-testnet-rpc.com"
```

### Solana Chains

```bash
# Required
export X402_PAY_TO="YourSolanaWalletAddress"              # Solana wallet address to receive payments
export X402_PRIVATE_KEY="YourSolanaPrivateKeyBase58"      # Solana private key (base58 or hex)

# Optional
export X402_CHAIN="solana-devnet"                         # Or "solana" for mainnet (defaults to base-sepolia)
export X402_MAX_TIMEOUT_SECONDS="600"                     # Payment validity timeout
export X402_SOLANA_FEE_PAYER="FacilitatorAddress"        # Facilitator's fee payer (defaults to x402.org)

# Optional: Custom RPC URLs
export X402_SOLANA_DEVNET_RPC_URL="https://your-solana-devnet-rpc.com"
export X402_SOLANA_RPC_URL="https://your-solana-mainnet-rpc.com"
```

### Supported Networks

#### EVM Networks
- `base-sepolia` (testnet) - Default
- `base` (mainnet)
- `avalanche-fuji` (testnet)
- `avalanche` (mainnet)

#### Solana Networks
- `solana-devnet` (testnet)
- `solana` (mainnet)

## Usage

### Basic Usage

```ruby
require 'x402/payments'

# Generate a signed payment header
header = X402::Payments.generate_header(
  amount: 0.001,                                    # Amount in USD
  resource: "http://localhost:3000/api/weather",   # Protected resource URL
  description: "Payment for weather API access",   # Optional description
  pay_to: "0xRecipientAddress"                     # Optional: override recipient (defaults to config)
)

# Use the header in an HTTP request
# curl -H "X-PAYMENT: #{header}" http://localhost:3000/api/weather
```

**Note**: The `pay_to` parameter allows you to specify a different recipient wallet address per payment. If not provided, it uses the configured `default_pay_to`.

### Solana Usage

Using Solana is just as easy - simply configure for a Solana network:

```ruby
require 'x402/payments'

# Configure for Solana
X402::Payments.configure do |config|
  config.default_pay_to = "YourSolanaWalletAddress"
  config.private_key = "YourSolanaPrivateKeyBase58"
  config.chain = "solana-devnet"  # or "solana" for mainnet
  # config.solana_fee_payer = "CustomFacilitatorAddress"  # Optional: defaults to x402.org facilitator
end

# Generate a Solana payment header (API is identical!)
header = X402::Payments.generate_header(
  amount: 0.001,
  resource: "http://localhost:3000/api/weather",
  description: "Payment for weather API access"
)

# Use the header in an HTTP request
# curl -H "X-PAYMENT: #{header}" http://localhost:3000/api/weather
```

**Key Differences for Solana:**
- `private_key`: Base58-encoded Solana private key (or hex format)
- `default_pay_to`: Solana wallet address (base58)
- `solana_fee_payer`: Optional - defaults to x402.org facilitator (only needed for custom facilitators)
- The gem automatically detects Solana chains and generates SPL token transfers

### Using in Rails

The gem works seamlessly in Rails applications:

```ruby
# config/initializers/x402.rb
X402::Payments.configure do |config|
  config.default_pay_to = ENV['X402_PAY_TO']
  config.private_key = ENV['X402_PRIVATE_KEY']
  config.chain = Rails.env.production? ? 'base' : 'base-sepolia'

  # Optional: Override RPC URLs programmatically
  # config.rpc_urls = {
  #   'base' => 'https://your-custom-base-rpc.com',
  #   'base-sepolia' => 'https://your-sepolia-rpc.com'
  # }
end

# In your controller or service
class PaymentService
  def self.generate_payment_for(resource_url, amount)
    X402::Payments.generate_header(
      amount: amount,
      resource: resource_url,
      description: "Payment for #{resource_url}"
    )
  end
end
```

### Using Standalone (Non-Rails)

```ruby
#!/usr/bin/env ruby
require 'x402/payments'

# Set environment variables or configure directly
X402::Payments.configure do |config|
  config.default_pay_to = "0xYourDefaultRecipient"
  config.private_key = "0xYourPrivateKeyHere"
  config.chain = "base-sepolia"
  # config.rpc_urls = { 'base-sepolia' => 'https://your-custom-rpc.com' }
end

# Generate payment
header = X402::Payments.generate_header(
  amount: 0.001,
  resource: "http://localhost:3000/api/data",
  # network: "avalanche",                    # Override default network
  # private_key: "0xDifferentKey",          # Override default key
  # pay_to: "0xRecipientWalletAddress",     # Override recipient address
  # extra: {                                 # Override EIP-712 domain
  #   name: "Custom Token",
  #   version: "1"
  # }
)

puts "Payment Header:"
puts header

HTTParty.get("http://localhost:3000/api/data", headers: { "X-PAYMENT" => header })
```

## How It Works

### EVM Chains (Base, Avalanche)

1. **Payment Requirements**: The gem creates a payment requirement specifying the amount (in USDC atomic units), network, and resource
2. **EIP-712 Signing**: Uses EIP-3009 `TransferWithAuthorization` to create a signature that authorizes the payment
3. **Header Encoding**: Encodes the signed payment data as a base64 string for the `X-PAYMENT` HTTP header
4. **Server Validation**: The server validates the signature and settles the payment on-chain

### Solana Chains

1. **Transaction Creation**: Creates an SPL token `TransferChecked` instruction for USDC
2. **Partial Signing**: Signs the transaction with the user's private key (fee payer signature added by facilitator)
3. **Header Encoding**: Encodes the partially-signed transaction as base64 for the `X-PAYMENT` header
4. **Facilitator Settlement**: Facilitator verifies, co-signs with fee payer, and submits to Solana

## Example Script

A complete example script is provided in `examples/generate_payment.rb`:

```bash
# Create your .env file in examples directory
cd examples
cp .env.example .env
# Edit .env with your credentials

# Run the example
cd ..
export $(cat examples/.env | xargs)
ruby examples/generate_payment.rb
```

This will generate a signed payment header and provide a ready-to-use curl command for testing. See `examples/README.md` for more details.

## Development

After checking out the repo, run:

```bash
bin/setup        # Install dependencies
bundle exec rake spec   # Run tests
bin/console      # Interactive prompt for experimentation
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/x402-payments.

## Requirements

- Ruby 3.0+

## Resources

- [x402 Protocol Docs](https://docs.cdp.coinbase.com/x402)
- [GitHub Repository](https://github.com/coinbase/x402)
- [Facilitator API](https://x402.org/facilitator)

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
