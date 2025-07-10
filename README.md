# HarvestHub 🌾

A decentralized farm-to-table supply chain management platform built on Stacks blockchain, connecting farmers directly with consumers through transparent, secure transactions.

## Overview

HarvestHub eliminates intermediaries in the agricultural supply chain by providing a direct marketplace where farmers can list their produce and consumers can purchase fresh, traceable food items. Built with Clarity smart contracts, it ensures transparency, security, and fair pricing.

## Features

### For Farmers
- **Farmer Registration**: Register with name, location, and certification details
- **Produce Listing**: List fresh produce with detailed information (category, quantity, price, harvest/expiry dates)
- **Order Management**: Confirm deliveries and track sales
- **Reputation System**: Build trust through verified transactions

### For Consumers
- **Browse Produce**: View available fresh produce from local farmers
- **Place Orders**: Order directly from farmers with delivery details
- **Traceability**: Track produce from farm to table
- **Quality Assurance**: Access to organic certification and farmer reputation

### Platform Features
- **Smart Contract Security**: All transactions secured by Stacks blockchain
- **Automatic Inventory Management**: Real-time quantity updates
- **Reputation Scoring**: Transparent farmer rating system
- **Emergency Controls**: Platform stability and security measures

## Smart Contract Functions

### Public Functions
- `register-farmer`: Register as a farmer on the platform
- `list-produce`: List new produce for sale
- `place-order`: Purchase produce from farmers
- `confirm-delivery`: Confirm order completion (farmers only)
- `update-reputation`: Update farmer reputation (admin only)
- `toggle-contract-status`: Emergency pause/resume (admin only)

### Read-Only Functions
- `get-farmer`: Retrieve farmer information
- `get-farmer-by-principal`: Find farmer by wallet address
- `get-produce`: Get produce listing details
- `get-order`: Retrieve order information
- `get-contract-status`: Check platform status

## Getting Started

### Prerequisites
- Clarinet installed
- Stacks wallet
- Basic understanding of Clarity smart contracts

### Installation
1. Clone the repository
2. Run `clarinet check` to verify contract syntax
3. Deploy to Stacks testnet or mainnet
4. Interact with the contract through your preferred interface

## Contract Architecture

The contract maintains three main data structures:
- **Farmers**: Registered producers with reputation scores
- **Produce Listings**: Available items with pricing and expiry
- **Orders**: Purchase records with delivery status

## Security Features

- Input validation on all parameters
- Principal-based access control
- Expiry date verification
- Inventory management
- Emergency pause functionality

## Future Roadmap

See the project issues for planned enhancements including automated payments, multi-token support, and expanded farmer tools.

