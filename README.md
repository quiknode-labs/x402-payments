# X402::Payments

![Coverage](./coverage/coverage.svg)

Ruby gem for generating signed payment HTTP headers and links using the [x402 protocol](https://www.x402.org/).

Supports USDC payments on Base, Avalanche, and other EVM networks with EIP-712 signing.

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

### Supported Networks

- `base-sepolia` (testnet) - Default
- `base` (mainnet)
- `avalanche-fuji` (testnet)
- `avalanche` (mainnet)

### Custom Chains and Tokens

You can register custom EVM chains and tokens beyond the built-in options.

#### Register a Custom Chain

```ruby
X402::Payments.configure do |config|
  config.default_pay_to = ENV['X402_PAY_TO']
  config.private_key = ENV['X402_PRIVATE_KEY']

  # Register Polygon Amoy testnet
  config.register_chain(
    name: "polygon-amoy",
    chain_id: 80002,
    standard: "eip155"
  )

  # Register the token for that chain
  config.register_token(
    chain: "polygon-amoy",
    symbol: "USDC",
    address: "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582",
    decimals: 6,
    name: "USD Coin",
    version: "2"
  )

  config.chain = "polygon-amoy"
  config.currency = "USDC"
end
```

#### Register a Custom Token on a Built-in Chain

```ruby
X402::Payments.configure do |config|
  config.default_pay_to = ENV['X402_PAY_TO']
  config.private_key = ENV['X402_PRIVATE_KEY']

  # Accept WETH on Base instead of USDC
  config.register_token(
    chain: "base",
    symbol: "WETH",
    address: "0x4200000000000000000000000000000000000006",
    decimals: 18,
    name: "Wrapped Ether",
    version: "1"
  )

  config.chain = "base"
  config.currency = "WETH"
end
```

#### Token Registration Parameters

| Parameter  | Required | Description                                     |
| ---------- | -------- | ----------------------------------------------- |
| `chain`    | Yes      | Chain name (built-in or custom registered)      |
| `symbol`   | Yes      | Token symbol (e.g., "USDC", "WETH")             |
| `address`  | Yes      | Token contract address                          |
| `decimals` | Yes      | Token decimals (e.g., 6 for USDC, 18 for WETH)  |
| `name`     | Yes      | Token name for EIP-712 domain                   |
| `version`  | No       | EIP-712 version (default: "1")                  |

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

1. **Payment Requirements**: The gem creates a payment requirement specifying the amount (in USDC atomic units), network, and resource
2. **EIP-712 Signing**: Uses EIP-3009 `TransferWithAuthorization` to create a signature that authorizes the payment
3. **Header Encoding**: Encodes the signed payment data as a base64 string for the `X-PAYMENT` HTTP header
4. **Server Validation**: The server validates the signature and settles the payment on-chain

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
