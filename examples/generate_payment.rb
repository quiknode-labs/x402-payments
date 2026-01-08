#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "optparse"
require "x402/payments"

options = { version: 2, chain: nil }

OptionParser.new do |opts|
  opts.banner = "Usage: ruby generate_payment.rb [options]"

  opts.on("-v", "--version VERSION", Integer, "Protocol version (1 or 2)") do |v|
    options[:version] = v
  end

  opts.on("-c", "--chain CHAIN", "Chain name (e.g., base-sepolia, polygon-amoy)") do |c|
    options[:chain] = c
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

version = options[:version]

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

CHAIN = options[:chain] || ENV.fetch("X402_CHAIN", "base-sepolia")
IS_SOLANA = %w[solana solana-devnet].include?(CHAIN)

if IS_SOLANA
  PRIVATE_KEY = ENV.fetch("X402_SOL_PRIVATE_KEY")
  DEFAULT_PAY_TO = ENV.fetch("X402_SOL_PAY_TO")
  RESOURCE_URL = "http://localhost:3000/api/v#{options[:version]}/weather/paywalled_info_sol"
else
  PRIVATE_KEY = ENV.fetch("X402_PRIVATE_KEY")
  DEFAULT_PAY_TO = ENV.fetch("X402_PAY_TO")
  RESOURCE_URL = "http://localhost:3000/api/v#{options[:version]}/weather/paywalled_info"
end

# Custom chain configurations (add more as needed)
CUSTOM_CHAINS = {
  "polygon-amoy" => {
    chain_id: 80002,
    usdc_address: "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582",
    usdc_name: "USDC",
    usdc_version: "2"
  },
  "polygon" => {
    chain_id: 137,
    usdc_address: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
    usdc_name: "USD Coin",
    usdc_version: "2"
  }
}.freeze

X402::Payments.configure do |config|
  config.default_pay_to = DEFAULT_PAY_TO
  config.private_key = PRIVATE_KEY
  config.max_timeout_seconds = 600
  config.protocol_version = version

  # Register custom chain if needed
  if CUSTOM_CHAINS.key?(CHAIN)
    custom = CUSTOM_CHAINS[CHAIN]
    config.register_chain(
      name: CHAIN,
      chain_id: custom[:chain_id],
      standard: "eip155"
    )
    config.register_token(
      chain: CHAIN,
      symbol: "USDC",
      address: custom[:usdc_address],
      decimals: 6,
      name: custom[:usdc_name],
      version: custom[:usdc_version]
    )
  end

  config.chain = CHAIN
  config.currency = "USDC"
end

chain_type = IS_SOLANA ? " (Solana)" : (CUSTOM_CHAINS.key?(CHAIN) ? " (custom)" : "")
puts "=== X402 Payment Generator (V#{version}) ==="
puts "Chain: #{CHAIN}#{chain_type}"
puts "CAIP-2: #{X402::Payments::Networks.to_caip2(CHAIN)}"
puts "Protocol Version: #{version}"
puts

amount = 0.001

link = X402::Payments.generate_link(
  amount: amount,
  resource: RESOURCE_URL,
  description: "Payment for weather API"
)

puts "Resource: #{RESOURCE_URL}"
puts "Amount: $#{amount} USD"
puts
puts "Header Name: #{link[:header_name]}"
puts
puts "Payment Header:"
puts link[:payment_header]
puts
puts "Curl Command:"
puts link[:curl_command]
