# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in x402-payments.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "eth", "~> 0.5.15"

# Solana support via bitzlato's ruby-solana
gem "solana", git: "https://github.com/bitzlato/ruby-solana"

group :development, :test do
  gem 'simplecov', require: false
  gem 'simplecov-formatter-badge', require: false
end