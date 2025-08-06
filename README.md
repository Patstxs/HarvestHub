# HarvestHub 🌾

A decentralized farm-to-table supply chain management platform built on Stacks blockchain, connecting farmers directly with consumers through transparent, secure transactions with automated STX payments and escrow.

## Overview

HarvestHub eliminates intermediaries in the agricultural supply chain by providing a direct marketplace where farmers can list their produce and consumers can purchase fresh, traceable food items. Built with Clarity smart contracts, it ensures transparency, security, and fair pricing with automatic payment processing and fund protection through escrow.

## Features

### For Farmers
- **Farmer Registration**: Register with name, location, and certification details
- **Produce Listing**: List fresh produce with detailed information (category, quantity, price, harvest/expiry dates)
- **Order Management**: Confirm deliveries and automatically receive STX payments
- **Reputation System**: Build trust through verified transactions
- **Automatic Payment Release**: Secure payment upon delivery confirmation

### For Consumers
- **Browse Produce**: View available fresh produce from local farmers
- **Secure Orders**: Order directly with automatic STX payment escrow
- **Payment Protection**: Funds held in escrow until delivery confirmed
- **Order Cancellation**: Cancel pending orders with automatic refunds
- **Traceability**: Track produce from farm to table
- **Quality Assurance**: Access to organic certification and farmer reputation

### Platform Features
- **Automated STX Payments**: Secure payment processing with escrow protection
- **Smart Contract Security**: All transactions secured by Stacks blockchain
- **Automatic Inventory Management**: Real-time quantity updates
- **Reputation Scoring**: Transparent farmer rating system
- **Platform Fee Management**: Configurable platform fees (default 2.5%)
- **Emergency Controls**: Platform stability and security measures
- **Refund System**: Automatic refunds for cancelled orders

## Smart Contract Functions

### Public Functions
- `register-farmer`: Register as a farmer on the platform
- `list-produce`: List new produce for sale
- `place-order`: Purchase produce with automatic STX payment and escrow
- `confirm-delivery`: Confirm order completion and release payment (farmers only)
- `cancel-order`: Cancel pending orders with automatic refund (buyers only)
- `update-reputation`: Update farmer reputation (admin only)
- `update-platform-fee`: Adjust platform fee rate (admin only)
- `toggle-contract-status`: Emergency pause/resume (admin only)

### Read-Only Functions
- `get-farmer`: Retrieve farmer information
- `get-farmer-by-principal`: Find farmer by wallet address
- `get-produce`: Get produce listing details
- `get-order`: Retrieve order information
- `get-escrow-balance`: Check escrow status for an order
- `get-contract-status`: Check platform status
- `get-platform-fee-rate`: Get current platform fee rate
- `calculate-order-amounts`: Calculate payment breakdown for an order

## Payment System

### How It Works
1. **Order Placement**: Buyers pay the full amount in STX when placing an order
2. **Escrow Protection**: Funds are held securely in the smart contract
3. **Payment Breakdown**: Platform fee (default 2.5%) is calculated automatically
4. **Delivery Confirmation**: Farmers confirm delivery to release funds
5. **Automatic Distribution**: Farmer receives their portion, platform gets fee
6. **Refund Protection**: Buyers can cancel pending orders for full refunds

### Fee Structure
- **Platform Fee**: 2.5% of order total (configurable by admin)
- **Farmer Payment**: 97.5% of order total after platform fee
- **Gas Costs**: Standard Stacks network transaction fees apply

## Getting Started

### Prerequisites
- Clarinet installed
- Stacks wallet with STX balance
- Basic understanding of Clarity smart contracts

### Installation
1. Clone the repository
2. Run `clarinet check` to verify contract syntax
3. Deploy to Stacks testnet or mainnet
4. Interact with the contract through your preferred interface

## Contract Architecture

The contract maintains four main data structures:
- **Farmers**: Registered producers with reputation scores
- **Produce Listings**: Available items with pricing and expiry
- **Orders**: Purchase records with delivery status and payment details
- **Escrow Balances**: Secure fund storage with release tracking

## Security Features

- **Input validation** on all parameters with range checks
- **Principal-based access control** for farmer and admin functions
- **Expiry date verification** to prevent stale produce orders
- **Inventory management** with automatic quantity updates
- **Escrow protection** with secure fund holding and release
- **Balance verification** before payment processing
- **Emergency pause functionality** for platform security
- **Proper error handling** with comprehensive error codes

## Error Codes

- `u100`: Owner only operation
- `u101`: Resource not found
- `u102`: Resource already exists
- `u103`: Invalid input parameters
- `u104`: Insufficient funds
- `u105`: Unauthorized operation
- `u106`: Expired produce
- `u107`: Invalid status
- `u108`: Payment failed
- `u109`: Escrow operation failed
- `u110`: Refund failed

## Future Roadmap

- Multi-Farm Cooperatives: Allow farmers to form cooperatives for bulk sales and shared logistics
- Quality Assurance Photos: Enable farmers to upload harvest photos and consumers to rate received produce
- Dynamic Pricing Algorithm: Implement supply/demand-based pricing with seasonal adjustments
- Delivery Tracking Integration: Add GPS tracking and estimated delivery times with courier partnerships
- Subscription Box Service: Allow consumers to set up recurring orders from preferred farmers
- Carbon Footprint Calculator: Track and display environmental impact of each purchase and delivery route
- Weather-Based Insurance: Integrate oracle data for automatic crop insurance payouts during adverse weather
- NFT Certification System: Create unique NFT certificates for organic, fair-trade, and sustainable farming practices
- Cross-Chain Bridge Support: Enable payments in Bitcoin and other cryptocurrencies through bridge protocols

## Contributing

We welcome contributions! Please see our contributing guidelines and submit pull requests for any improvements.