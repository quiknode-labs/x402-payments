# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-01-08

### Added

- **Solana support** - Full support for Solana payments on `solana-devnet` and `solana` mainnet
  - SPL Token `TransferChecked` transactions with partial signing
  - Custom ATA (Associated Token Account) derivation with correct Ed25519 curve checking
  - Facilitator fee payer model (uses x402.org facilitator by default)
  - Inline `fee_payer:` override for different facilitators
  - Configurable compute budget via `X402_SOLANA_COMPUTE_UNIT_LIMIT` and `X402_SOLANA_COMPUTE_UNIT_PRICE`
- **Protocol v1 and v2 support** - Both protocol versions fully supported
  - v1: `X-PAYMENT` header, human-readable network names
  - v2: `PAYMENT-SIGNATURE` header, CAIP-2 network identifiers
  - Override protocol version per-request with `version:` parameter
- **Custom EVM chain registration** - `config.register_chain()` for adding custom EVM networks
- **Custom token registration** - `config.register_token()` for adding tokens beyond USDC
- **Networks module** - CAIP-2 network identifier conversion

### Changed

- Default protocol version is v2
- Solana uses CAIP-2 format: `solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1` (devnet)
- Improved error messages for configuration issues

### Fixed

- ATA derivation now uses correct Ed25519 curve equation (fixes `recipient_mismatch` errors)

## [0.1.0] - Initial Release

- Initial release with v1 protocol support
- EIP-712 signing for USDC payments
- Support for Base and Avalanche networks
