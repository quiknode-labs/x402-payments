# frozen_string_literal: true

require_relative "lib/x402/payments/version"

Gem::Specification.new do |spec|
  spec.name = "x402-payments"
  spec.version = X402::Payments::VERSION
  spec.authors = ["QuickNode"]
  spec.email = ["zach+402@quiknode.io"]

  spec.summary = "Generate x402 payment signatures and links for blockchain micropayments with Solana and EVM chains. (supports x402 v2)"
  spec.description = "Ruby gem for generating signed payment headers and links using the x402 protocol with Solana and EVM chains. (supports x402 v2)"
  spec.homepage = "https://github.com/quiknode-labs/x402-payments"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/quiknode-labs/x402-payments"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies for EIP-712 signing and Ethereum interactions
  spec.add_dependency "eth", "~> 0.5.11"

  # Dependencies for Solana SPL token transfers
  spec.add_dependency "solana-ruby-web3js", "~> 2.1"

  # Ruby 3.4+ compatibility
  spec.add_dependency "base64"
  spec.add_dependency "ostruct"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
