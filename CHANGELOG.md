# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-01-06

### Added
- **Protocol v2 support** - Now supports x402 protocol v2 with CAIP-2 network identifiers and `PAYMENT-SIGNATURE` header
- **Custom chain and token registration** - `config.register_chain()` and `config.register_token()` for custom EVM networks

### Changed
- Default protocol version is now v2
- v2 payments use `PAYMENT-SIGNATURE` header (v1 uses `X-PAYMENT`)
- v2 uses CAIP-2 network format (e.g., `eip155:84532` instead of `base-sepolia`)

## [0.1.0] - Previous Release

- Initial release with v1 protocol support
- EIP-712 signing for USDC payments
- Support for Base and Avalanche networks
