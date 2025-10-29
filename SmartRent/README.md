# 🏠 SmartRent

> **Blockchain-Enabled Rental and Asset-Sharing Platform**

SmartRent is a comprehensive, multi-module platform that revolutionizes asset rental through blockchain technology, IoT integration, and mobile accessibility. Rent anything, anywhere, anytime with complete security and transparency.

![SmartRent Architecture](https://via.placeholder.com/800x400/2196F3/FFFFFF?text=SmartRent+Architecture)

## ✨ Features

### 🔗 Blockchain-Powered
- **NFT Asset Tokenization**: Every asset is represented as a unique NFT
- **Smart Contracts**: Automated rental agreements with escrow functionality
- **Decentralized**: No single point of failure
- **Transparent**: All transactions recorded on blockchain
- **Secure**: Cryptographic security for all operations

### 📱 Mobile-First Experience
- **Cross-Platform**: Native Android and iOS apps built with Flutter
- **Real-Time**: Live updates on asset availability and rental status
- **Wallet Integration**: Connect Web3 wallets for seamless transactions
- **Push Notifications**: Stay informed about your rentals

### 🤖 IoT Integration
- **Smart Locks**: Remote lock/unlock control for physical assets
- **Asset Tracking**: Real-time location and status monitoring
- **Automated Operations**: Self-executing rental workflows
- **Security**: Tamper detection and alerts

### 🚀 Developer-Ready
- **Production-Grade**: Clean architecture with modern tech stack
- **API-First**: RESTful APIs for all operations
- **Containerized**: Docker-based development and deployment
- **Well-Documented**: Comprehensive documentation and examples

## 🏗️ Architecture

```
SmartRent/
├── 🔧 backend/          # FastAPI + Web3 + PostgreSQL
├── ⛓️  blockchain/       # Hardhat + Solidity Smart Contracts  
├── 📱 mobile/           # Flutter Mobile App (Android/iOS)
├── 🔌 iot_device/       # ESP32 MicroPython IoT Controller
├── 🐳 docker-compose.yml
└── 📚 README.md
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Backend** | FastAPI + Python | REST API, Web3 integration, business logic |
| **Database** | PostgreSQL + Redis | Data persistence and caching |
| **Blockchain** | Solidity + Hardhat | Smart contracts on Ethereum |
| **Mobile** | Flutter + Dart | Cross-platform mobile apps |
| **IoT** | ESP32 + MicroPython | Smart device control |
| **DevOps** | Docker + Docker Compose | Containerization and orchestration |

## 🚀 Quick Start

### Prerequisites

- **Docker & Docker Compose** (for backend services)
- **Node.js 16+** (for blockchain development)
- **Flutter SDK** (for mobile development)
- **Python 3.11+** (for backend development)

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/smartrent.git
cd smartrent
```

### 2. Environment Setup

Create environment file:
```bash
cp .env.example .env
# Edit .env with your configuration
```

Required environment variables:
```bash
# Blockchain
PRIVATE_KEY=your_ethereum_private_key
INFURA_PROJECT_ID=your_infura_project_id
ETHERSCAN_API_KEY=your_etherscan_api_key

# Database
DATABASE_URL=postgresql://smartrent:password@localhost:5432/smartrent_db

# Security
SECRET_KEY=your-secret-key-change-in-production
```

### 3. Start the Platform

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps
```

This starts:
- 📊 **Backend API**: http://localhost:8000
- 🗄️ **PostgreSQL**: localhost:5432
- 🚀 **Redis**: localhost:6379
- 📖 **API Docs**: http://localhost:8000/docs

### 4. Deploy Smart Contracts

```bash
# Navigate to blockchain directory
cd blockchain/

# Install dependencies
npm install

# Compile contracts
npm run compile

# Deploy to local network (Hardhat)
npm run deploy

# Or deploy to testnet
npm run deploy:testnet
```

### 5. Run Mobile App

```bash
# Navigate to mobile directory
cd mobile/

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run
```

### 6. Set up IoT Device (Optional)

```bash
# See iot_device/README.md for detailed setup
# Flash MicroPython firmware to ESP32
# Upload SmartRent IoT code
```

## 📖 Module Documentation

### 🔧 Backend API
- **Location**: `/backend/`
- **Tech**: FastAPI, SQLAlchemy, Web3.py, PostgreSQL
- **Features**: User management, asset CRUD, rental lifecycle, blockchain integration
- **Documentation**: [Backend README](./backend/README.md)
- **API Docs**: http://localhost:8000/docs (when running)

### ⛓️ Blockchain
- **Location**: `/blockchain/`
- **Tech**: Solidity, Hardhat, OpenZeppelin
- **Contracts**: AssetToken (ERC721), RentalAgreement (Escrow)
- **Documentation**: [Blockchain README](./blockchain/README.md)
- **Networks**: Ethereum, Polygon, BSC

### 📱 Mobile App
- **Location**: `/mobile/`
- **Tech**: Flutter, Riverpod, Web3Dart
- **Platforms**: Android, iOS
- **Features**: Asset browsing, rental management, wallet integration
- **Documentation**: [Mobile README](./mobile/README.md)

### 🔌 IoT Device
- **Location**: `/iot_device/`
- **Tech**: ESP32, MicroPython
- **Features**: Smart locks, asset tracking, remote control
- **Documentation**: [IoT README](./iot_device/README.md)

## 🔧 Development

### Backend Development

```bash
cd backend/

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run development server
python -m app.main

# Run tests
pytest
```

### Blockchain Development

```bash
cd blockchain/

# Install dependencies
npm install

# Run local blockchain
npm run node

# Test contracts
npm test

# Deploy contracts
npm run deploy
```

### Mobile Development

```bash
cd mobile/

# Get dependencies
flutter pub get

# Run code generation
flutter packages pub run build_runner build

# Run app
flutter run

# Build APK
flutter build apk
```

### IoT Development

```bash
cd iot_device/

# Install MicroPython tools
pip install esptool ampy

# Flash firmware (see IoT README for details)
esptool.py --chip esp32 erase_flash
esptool.py --chip esp32 write_flash -z 0x1000 esp32-micropython.bin

# Upload code
ampy --port /dev/ttyUSB0 put src/main.py main.py
```

## 🧪 Testing

### Backend Testing
```bash
cd backend/
pytest --cov=app tests/
```

### Blockchain Testing
```bash
cd blockchain/
npm test
npm run coverage
```

### Mobile Testing
```bash
cd mobile/
flutter test
flutter integration_test
```

### End-to-End Testing
```bash
# Start all services
docker-compose up -d

# Run E2E tests
npm run test:e2e
```

## 🚀 Deployment

### Development Environment
```bash
# All services with hot reload
docker-compose -f docker-compose.yml up -d
```

### Staging Environment
```bash
# Production-like environment
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

### Production Environment
```bash
# Production deployment
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Cloud Deployment

**AWS/GCP/Azure**:
- Use managed databases (RDS/Cloud SQL)
- Deploy backend via ECS/Cloud Run/Container Apps
- Use CDN for mobile app distribution
- Set up monitoring and alerting

**Blockchain Networks**:
- Mainnet: Ethereum, Polygon, BSC
- Testnet: Goerli, Mumbai, BSC Testnet

## 🔐 Security

### Best Practices Implemented
- ✅ **Input Validation**: All inputs validated and sanitized
- ✅ **Authentication**: JWT-based API authentication
- ✅ **Authorization**: Role-based access control
- ✅ **Encryption**: HTTPS/TLS for all communications
- ✅ **SQL Injection**: Prevention via ORM parameterized queries
- ✅ **XSS Protection**: Output encoding and CSP headers
- ✅ **Rate Limiting**: API rate limiting and throttling
- ✅ **Secrets Management**: Environment-based secret storage

### Blockchain Security
- ✅ **Smart Contract Audits**: Comprehensive testing
- ✅ **Reentrancy Protection**: ReentrancyGuard implementation
- ✅ **Access Control**: Owner and role-based permissions
- ✅ **Input Validation**: Extensive parameter checking
- ✅ **Emergency Controls**: Pause functionality

### Mobile Security
- ✅ **Certificate Pinning**: API communication security
- ✅ **Local Storage**: Secure encrypted storage
- ✅ **Biometric Auth**: Fingerprint/Face ID integration
- ✅ **Code Obfuscation**: Release build protection

### IoT Security
- ✅ **Device Authentication**: Unique device credentials
- ✅ **Encrypted Communication**: HTTPS for all API calls
- ✅ **Tamper Detection**: Physical security monitoring
- ✅ **Secure Boot**: Verified firmware integrity

## 📊 Monitoring & Analytics

### Application Monitoring
- **Health Checks**: Endpoint health monitoring
- **Performance**: Response time and throughput tracking
- **Errors**: Error rate and exception tracking
- **Uptime**: Service availability monitoring

### Blockchain Monitoring
- **Transaction Status**: Success/failure tracking
- **Gas Usage**: Cost optimization monitoring
- **Contract Events**: Smart contract event tracking
- **Network Health**: Blockchain network status

### Business Analytics
- **User Engagement**: App usage patterns
- **Rental Metrics**: Booking rates and revenue
- **Asset Performance**: Popular assets and categories
- **Geographic Distribution**: Usage by location

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Style
- **Backend**: Follow PEP 8, use Black formatter
- **Blockchain**: Follow Solidity style guide
- **Mobile**: Follow Dart/Flutter conventions
- **IoT**: Follow MicroPython best practices

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **OpenZeppelin**: Smart contract security standards
- **Flutter Team**: Amazing cross-platform framework
- **FastAPI**: Modern Python web framework
- **Hardhat**: Ethereum development environment
- **MicroPython**: Python for microcontrollers

## 📞 Support

### Documentation
- 📖 [API Documentation](http://localhost:8000/docs)
- 🔗 [Smart Contract Docs](./blockchain/README.md)
- 📱 [Mobile App Guide](./mobile/README.md)
- 🔌 [IoT Setup Guide](./iot_device/README.md)

### Community
- 💬 [Discord Community](https://discord.gg/smartrent)
- 📧 [Email Support](mailto:support@smartrent.com)
- 🐛 [Issue Tracker](https://github.com/smartrent/smartrent/issues)
- 💡 [Feature Requests](https://github.com/smartrent/smartrent/discussions)

### Professional Support
- 🏢 **Enterprise**: enterprise@smartrent.com
- 🛠️ **Integration**: developers@smartrent.com
- 🔒 **Security**: security@smartrent.com

---

**Built with ❤️ for the decentralized future**

*SmartRent - Rent anything, anywhere, anytime* 🚀








