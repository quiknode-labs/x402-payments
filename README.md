# X402::Payments

Ruby gem for generating signed payment headers and links using the x402 protocol. Supports USDC payments on Base, Avalanche, and other EVM networks with EIP-712 signing.

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
```

### Supported Networks

- `base-sepolia` (testnet) - Default
- `base` (mainnet)
- `avalanche-fuji` (testnet)
- `avalanche` (mainnet)

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

### Generate Payment Link

```ruby
# Generate payment header with curl command
link = X402::Payments.generate_link(
  amount: 0.001,
  resource: "http://localhost:3000/api/weather",
  description: "Weather API access"
)

puts link[:payment_header]  # Base64-encoded payment header
puts link[:curl_command]     # Ready-to-use curl command
```

### Advanced Configuration

```ruby
# Configure programmatically
X402::Payments.configure do |config|
  config.default_pay_to = "0xYourDefaultRecipient"  # Default payment recipient
  config.private_key = "0xYourKey"
  config.chain = "base"  # Use mainnet
  config.max_timeout_seconds = 300
end

# Override configuration per request
header = X402::Payments.generate_header(
  amount: 0.005,
  resource: "https://api.example.com/data",
  network: "avalanche",                    # Override default network
  private_key: "0xDifferentKey",          # Override default key
  pay_to: "0xRecipientWalletAddress",     # Override recipient address
  extra: {                                 # Override EIP-712 domain
    name: "Custom Token",
    version: "1"
  }
)
```

### Using in Rails

The gem works seamlessly in Rails applications:

```ruby
# config/initializers/x402.rb
X402::Payments.configure do |config|
  config.default_pay_to = ENV['X402_PAY_TO']
  config.private_key = ENV['X402_PRIVATE_KEY']
  config.chain = Rails.env.production? ? 'base' : 'base-sepolia'
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
end

# Generate payment
header = X402::Payments.generate_header(
  amount: 0.001,
  resource: "http://localhost:3000/api/data"
)

puts "Payment Header:"
puts header
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

## Troubleshooting

### Native Extension Build Failures

If you encounter errors installing the `rbsecp256k1` native extension:

**Error: `bad interpreter: /usr/bin/perl5.30: No such file or directory`**

This happens when autoreconf has a hardcoded perl version that doesn't match your system. Fix options:

1. Create a symlink to your current perl (macOS):
   ```bash
   # Find your perl location
   which perl
   # Create symlink (requires admin password)
   sudo ln -sf /opt/homebrew/bin/perl /usr/bin/perl5.30
   ```

2. Reinstall autoconf to get the correct perl path:
   ```bash
   brew reinstall autoconf
   ```

3. Use system libsecp256k1 if available:
   ```bash
   gem install rbsecp256k1 -- --with-system-libraries
   bundle install
   ```

4. Ensure Xcode Command Line Tools are installed (macOS):
   ```bash
   xcode-select --install
   ```

After fixing the perl issue, run `bundle install` again.

### Configuration Errors

**Error: `default_pay_to is required`**
- Set `X402_PAY_TO` environment variable or configure programmatically

**Error: `private_key is required`**
- Set `X402_PRIVATE_KEY` environment variable or configure programmatically

**Error: `Unsupported chain: xyz`**
- Use one of the supported networks: `base-sepolia`, `base`, `avalanche-fuji`, or `avalanche`

## Development

After checking out the repo, run:

```bash
bin/setup        # Install dependencies
bundle exec rake spec   # Run tests
bin/console      # Interactive prompt for experimentation
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/x402-payments.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
