# X402 Payments Examples

This directory contains example scripts demonstrating how to use the x402-payments gem.

## generate_payment.rb

Generates a signed payment header and curl command for testing x402 payments.

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
cd /Users/zachp/Dev/gems/x402-payments

# Load environment variables and run
export $(cat examples/.env | xargs)
ruby examples/generate_payment.rb

# Or set variables inline
X402_PRIVATE_KEY="0xYourPrivateKey" \
X402_PAY_TO="0xYourRecipientAddress" \
ruby examples/generate_payment.rb
```

### Command Line Options

```bash
ruby examples/generate_payment.rb [options]

Options:
  -v, --version VERSION    Protocol version (1 or 2, default: 2)
  -c, --chain CHAIN        Chain name (e.g., base-sepolia, polygon-amoy)
  -h, --help               Show help
```

### Examples

```bash
# Use v2 protocol
ruby examples/generate_payment.rb -v 2

# Use Polygon Amoy testnet (custom chain)
ruby examples/generate_payment.rb -c polygon-amoy -v 2

# Use Polygon mainnet (custom chain)
ruby examples/generate_payment.rb -c polygon -v 2

# Use built-in Base Sepolia
ruby examples/generate_payment.rb -c base-sepolia -v 1
```

### Environment Variables

- `X402_PRIVATE_KEY` - Private key for signing (required)
- `X402_PAY_TO` - Default recipient wallet address for payments (required)
- `X402_CHAIN` - Network to use (default: `base-sepolia`, can be overridden with `-c`)

### Supported Chains

**Built-in chains:**
- `base-sepolia` (testnet)
- `base` (mainnet)
- `avalanche-fuji` (testnet)
- `avalanche` (mainnet)

**Custom chains (pre-configured in example):**
- `polygon-amoy` (Polygon testnet, chain ID: 80002)
- `polygon` (Polygon mainnet, chain ID: 137)

### Example Output

```
=== X402 Payment Generator ===
Default Pay To: 0xYourRecipientAddress
Chain: base-sepolia

Generating payment for:
  Resource: http://localhost:3000/api/weather/current
  Amount: $0.001 USD

Payment Header (X-PAYMENT):
eyJ4NDAyVmVyc2lvbiI6MSwic2NoZW1lIjoiZXhhY3QiLCJuZXR3b3JrIjoi...

Curl Command:
curl -i -H "X-PAYMENT: eyJ4NDAyVmVyc2lvbiI6..." http://localhost:3000/api/weather/current

To test the payment, run:
  curl -i -H "X-PAYMENT: eyJ4NDAyVmVyc2lvbiI6..." http://localhost:3000/api/weather/current
```

You can copy and paste the curl command to test your x402-enabled API endpoint.

## Customizing the Script

You can modify `generate_payment.rb` to:

- Change the amount (e.g., `amount = 0.005` for $0.005)
- Target different resources (e.g., `resource_url = "https://api.example.com/data"`)
- Use different networks (set `X402_CHAIN` environment variable)
- Add custom descriptions

### Example: Generate Payment for Different Resource

```ruby
# At the end of generate_payment.rb, add:

puts "\n=== Custom Payment ==="
custom_link = X402::Payments.generate_link(
  amount: 0.005,
  resource: "http://localhost:3000/api/premium/data",
  description: "Premium API access"
)

puts "Custom Curl Command:"
puts custom_link[:curl_command]
```
