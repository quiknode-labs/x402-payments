#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "x402/payments"

# Load .env file if it exists in the examples directory
env_file = File.join(__dir__, ".env")
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    key, value = line.split("=", 2)
    ENV[key] = value if key && value
  end
end

# Configuration
# NOTE: Replace these with your actual credentials via environment variables
PRIVATE_KEY = ENV.fetch("X402_PRIVATE_KEY")
DEFAULT_PAY_TO = ENV.fetch("X402_PAY_TO")
CHAIN = ENV.fetch("X402_CHAIN", "base-sepolia")
RESOURCE_URL = "http://localhost:3000/api/weather/paywalled_info"

# Configure the gem
X402::Payments.configure do |config|
  config.default_pay_to = DEFAULT_PAY_TO
  config.private_key = PRIVATE_KEY
  config.chain = CHAIN
  config.max_timeout_seconds = 600
end

puts "=== X402 Payment Generator ==="
puts "Default Pay To: #{DEFAULT_PAY_TO}"
puts "Chain: #{CHAIN}"

# Generate payment for a resource
amount = 0.001  # $0.001 USD

puts "Generating payment for:"
puts "  Resource: #{RESOURCE_URL}"
puts "  Amount: $#{amount} USD"
puts

# Generate the payment link with curl command
link = X402::Payments.generate_link(
  amount: amount,
  resource: RESOURCE_URL,
  description: "Payment required for #{RESOURCE_URL}",
  # pay_to: "0xDifferentRecipientAddress"  # Optional: override recipient
)

puts "Payment Header (X-PAYMENT):"
puts link[:payment_header]
puts
puts "Curl Command:"
puts link[:curl_command]
