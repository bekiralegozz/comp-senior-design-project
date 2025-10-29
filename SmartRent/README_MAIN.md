# 🏠 SmartRent - Blockchain-Enabled Rental Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue)](https://soliditylang.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104-green)](https://fastapi.tiangolo.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue)](https://flutter.dev/)

> A decentralized, blockchain-powered platform for property rental and fractional asset ownership with IoT integration.

## 🎯 Project Overview

SmartRent is a comprehensive ecosystem that addresses inefficiencies in traditional property rental and ownership systems. By leveraging blockchain technology, smart contracts, and IoT-based access control, we create a transparent, secure, and automated platform for short-term property management.

### ✨ Key Features

- 🔗 **Blockchain-Based**: Ethereum smart contracts for transparent and immutable transactions
- 🪙 **Fractional Ownership**: Tokenized asset shares (ERC20) for liquid investment opportunities
- 🔐 **IoT Integration**: ESP32-powered smart locks for automated access control
- 📱 **Mobile-First**: Cross-platform Flutter app with Web3 wallet integration
- ⚡ **Real-Time Updates**: Supabase Realtime for instant state synchronization
- 🏛️ **Dynamic Governance**: Largest shareholder automatically becomes decision-maker

## 🏗️ Architecture

SmartRent consists of four main components working in parallel:

1. **Blockchain** - Smart contracts (Solidity)
2. **Backend** - REST API & Event Listeners (FastAPI/Python)
3. **Mobile** - Cross-platform app (Flutter/Dart)
4. **IoT** - Smart lock controller (ESP32/MicroPython)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Mobile    │────▶│   Backend   │────▶│ Blockchain  │
│   Flutter   │◀────│   FastAPI   │◀────│  Ethereum   │
└─────────────┘     └──────┬──────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │     IoT     │
                    │    ESP32    │
                    └─────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ & npm
- Python 3.9+
- Flutter 3.0+
- PostgreSQL / Supabase account
- Infura/Alchemy API key
- ESP32 board (for IoT)

### 1. Clone Repository

```bash
git clone https://github.com/bekiralegozz/comp-senior-design-project.git
cd SmartRent
```

### 2. Blockchain Setup

```bash
cd blockchain
npm install
cp .env.example .env
# Edit .env with your configuration
npx hardhat compile
npx hardhat test
npx hardhat run scripts/deploy-asset-token.js --network sepolia
```

### 3. Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your configuration
uvicorn app.main:app --reload
```

### 4. Mobile Setup

```bash
cd mobile
flutter pub get
# Edit lib/constants/config.dart with your configuration
flutter run
```

### 5. IoT Setup

```bash
cd iot_device
# Edit src/main.py with your configuration
# Upload to ESP32 using Arduino IDE or PlatformIO
```

## 📚 Documentation

- **[Development Checklist](DEVELOPMENT_CHECKLIST.md)** - Comprehensive task list for all teams
- **[Project Structure](PROJECT_STRUCTURE.md)** - Detailed file organization
- **[Backend README](SmartRent/backend/README_DETAILED.md)** - Backend setup guide
- **[IoT README](SmartRent/iot_device/README_DETAILED.md)** - IoT device setup

## 🛠️ Technology Stack

### Blockchain
- Solidity 0.8.19
- Hardhat
- OpenZeppelin Contracts
- Ethers.js
- Sepolia Testnet

### Backend
- FastAPI (Python)
- Supabase (PostgreSQL)
- Web3.py
- Redis (Caching)
- Uvicorn (ASGI)

### Mobile
- Flutter 3.0+
- Riverpod (State Management)
- GoRouter (Navigation)
- WalletConnect v2
- Web3dart

### IoT
- ESP32
- MicroPython
- Supabase Realtime
- WiFi Manager

## 📋 Development Methodology

We follow an **Agile Parallel Development** approach:

### Phase 1: Foundational PoCs
- Blockchain: Deploy AssetToken & AssetShare contracts
- Backend: FastAPI server with Supabase integration
- Mobile: Login/Profile UI with API integration
- IoT: Remote lock control PoC

### Phase 2: Increased Complexity
- Blockchain: RentalManager contract
- Backend: Persistent event listener service
- Mobile: WalletConnect & transaction management
- IoT: Supabase Realtime integration

### Phase 3: Critical Integrations
- Blockchain: Governance system
- Backend: Dynamic Governance Listener
- Mobile: Conditional admin UI based on governance
- IoT: Complete unlock flow (Mobile → API → Database → ESP32)

## 👥 Team Structure

- **Blockchain Developer**: Smart contract development and deployment
- **Backend Developer**: API, database, and event listeners
- **Mobile Developer**: Flutter app and Web3 integration
- **IoT Developer**: ESP32 firmware and hardware integration

## 🔐 Security Considerations

- Smart contracts audited with automated tools
- JWT-based authentication
- Wallet signature verification
- Encrypted IoT communication
- Rate limiting on API endpoints
- Input validation and sanitization

## 🧪 Testing

```bash
# Blockchain tests
cd blockchain && npx hardhat test

# Backend tests
cd backend && pytest

# Mobile tests
cd mobile && flutter test

# IoT tests
cd iot_device && pytest
```

## 📊 Current Status

- ✅ Smart contract architecture designed
- ✅ Backend API structure implemented
- ✅ Mobile app skeleton created
- ✅ IoT basic functionality working
- 🚧 Full integration in progress
- 🚧 Testing and refinement ongoing

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

Bekir Alagöz - [@bekiralegozz](https://github.com/bekiralegozz)

Project Link: [https://github.com/bekiralegozz/comp-senior-design-project](https://github.com/bekiralegozz/comp-senior-design-project)

## 🙏 Acknowledgments

- Koç University COMP 491 Computer Engineering Design
- OpenZeppelin for secure smart contract libraries
- Flutter & Dart teams for excellent mobile framework
- Supabase for real-time database capabilities
- WalletConnect for Web3 wallet integration

---

**Built with ❤️ by the SmartRent Team**
