# 📂 SmartRent Project Structure

Complete file structure for the SmartRent blockchain-enabled rental platform.

```
SmartRent/
│
├── README.md                           # Main project documentation
├── DEVELOPMENT_CHECKLIST.md            # Comprehensive development checklist
├── docker-compose.yml                  # Docker services configuration
│
├── blockchain/                         # 🔗 Blockchain Smart Contracts
│   ├── README.md
│   ├── package.json
│   ├── hardhat.config.js              # Hardhat configuration
│   ├── .env.example                   # Environment variables template
│   │
│   ├── contracts/                     # Solidity smart contracts
│   │   ├── AssetToken.sol            # ERC721 NFT for assets
│   │   ├── RentalAgreement.sol       # Rental management contract
│   │   └── AssetShare.sol            # ERC20 for fractional ownership
│   │
│   ├── scripts/                       # Deployment scripts
│   │   ├── deploy-asset-token.js
│   │   ├── deploy-rental-agreement.js
│   │   └── deploy-asset-share.js
│   │
│   ├── test/                          # Contract tests
│   │   ├── AssetToken.test.js
│   │   ├── RentalAgreement.test.js
│   │   └── AssetShare.test.js
│   │
│   └── artifacts/                     # Compiled contracts (gitignored)
│
├── backend/                           # 🔧 FastAPI Backend Server
│   ├── README.md
│   ├── README_DETAILED.md            # Detailed backend documentation
│   ├── requirements.txt              # Python dependencies
│   ├── .env.example                  # Environment variables template
│   │
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                   # FastAPI application entry point
│   │   │
│   │   ├── api/                      # API routes
│   │   │   ├── __init__.py
│   │   │   └── routes/
│   │   │       ├── __init__.py
│   │   │       ├── users.py          # User management endpoints
│   │   │       ├── assets.py         # Asset management endpoints
│   │   │       └── rentals.py        # Rental management endpoints
│   │   │
│   │   ├── core/                     # Core utilities
│   │   │   ├── __init__.py
│   │   │   ├── config.py             # Configuration management
│   │   │   ├── security.py           # Authentication & security
│   │   │   └── web3_utils.py         # Web3 blockchain utilities
│   │   │
│   │   ├── db/                       # Database layer
│   │   │   ├── __init__.py
│   │   │   ├── database.py           # Database connection
│   │   │   ├── models.py             # SQLAlchemy models
│   │   │   └── schema.py             # Pydantic schemas
│   │   │
│   │   ├── services/                 # Business logic services
│   │   │   ├── __init__.py
│   │   │   ├── blockchain_listener.py # Event listener service
│   │   │   ├── governance_listener.py # Governance tracker
│   │   │   └── iot_service.py        # IoT device management
│   │   │
│   │   └── utils/                    # Helper functions
│   │       ├── __init__.py
│   │       └── helpers.py
│   │
│   └── tests/                        # Backend tests
│       ├── __init__.py
│       ├── test_users.py
│       ├── test_assets.py
│       └── test_rentals.py
│
├── mobile/                            # 📱 Flutter Mobile Application
│   ├── README.md
│   ├── pubspec.yaml                  # Flutter dependencies
│   ├── analysis_options.yaml         # Linting rules
│   │
│   ├── lib/
│   │   ├── main.dart                 # Application entry point
│   │   │
│   │   ├── core/                     # Core app infrastructure
│   │   │   ├── router/
│   │   │   │   └── app_router.dart   # GoRouter configuration
│   │   │   │
│   │   │   ├── providers/            # Riverpod state management
│   │   │   │   ├── auth_provider.dart
│   │   │   │   ├── asset_provider.dart
│   │   │   │   ├── rental_provider.dart
│   │   │   │   └── wallet_provider.dart
│   │   │   │
│   │   │   └── theme/
│   │   │       └── app_theme.dart    # Material 3 theme
│   │   │
│   │   ├── screens/                  # UI screens
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── wallet_connect_screen.dart
│   │   │   │
│   │   │   ├── assets/
│   │   │   │   ├── create_asset_screen.dart
│   │   │   │   └── my_assets_screen.dart
│   │   │   │
│   │   │   ├── rentals/
│   │   │   │   ├── rental_details_screen.dart
│   │   │   │   └── create_rental_screen.dart
│   │   │   │
│   │   │   ├── wallet/
│   │   │   │   └── wallet_screen.dart
│   │   │   │
│   │   │   ├── settings/
│   │   │   │   └── settings_screen.dart
│   │   │   │
│   │   │   ├── home_screen.dart
│   │   │   ├── asset_details.dart
│   │   │   ├── rental_screen.dart
│   │   │   └── profile_screen.dart
│   │   │
│   │   ├── components/               # Reusable UI components
│   │   │   ├── asset_card.dart
│   │   │   └── rental_card.dart
│   │   │
│   │   ├── services/                 # API and blockchain services
│   │   │   ├── api_service.dart      # REST API client
│   │   │   ├── wallet_service.dart   # WalletConnect integration
│   │   │   ├── blockchain_service.dart # Web3 blockchain service
│   │   │   └── models.dart           # Data models
│   │   │
│   │   └── constants/                # App constants
│   │       └── config.dart           # Configuration constants
│   │
│   ├── assets/                       # Static assets
│   │   ├── images/
│   │   ├── icons/
│   │   └── animations/
│   │
│   ├── fonts/                        # Custom fonts
│   │
│   ├── android/                      # Android configuration
│   ├── ios/                          # iOS configuration
│   └── web/                          # Web configuration
│
├── iot_device/                        # 🔌 ESP32 IoT Smart Lock
│   ├── README.md
│   ├── README_DETAILED.md            # Detailed IoT documentation
│   ├── platformio.ini                # PlatformIO configuration
│   │
│   ├── src/
│   │   ├── main.py                   # Main ESP32 program
│   │   ├── main_basic.py             # Basic polling version
│   │   ├── wifi_manager.py           # WiFi connection handler
│   │   ├── lock_controller.py        # Lock hardware control
│   │   ├── api_client.py             # Backend API client
│   │   └── supabase_client.py        # Supabase realtime client
│   │
│   ├── lib/                          # Libraries
│   └── test/                         # IoT tests
│
├── docs/                              # 📚 Documentation
│   ├── architecture.md               # System architecture
│   ├── api_documentation.md          # API docs
│   ├── smart_contracts.md            # Contract documentation
│   ├── deployment_guide.md           # Deployment instructions
│   └── user_guide.md                 # End-user documentation
│
└── .github/                          # GitHub configuration
    └── workflows/                    # CI/CD pipelines
        ├── blockchain-tests.yml
        ├── backend-tests.yml
        ├── mobile-build.yml
        └── deploy.yml
```

## 📝 File Descriptions

### Root Level
- **README.md**: Main project overview and quick start guide
- **DEVELOPMENT_CHECKLIST.md**: Comprehensive checklist for all 4 teams
- **docker-compose.yml**: Local development environment setup

### Blockchain (`blockchain/`)
- Smart contracts for asset tokenization and rental management
- Hardhat development environment
- Deployment scripts and tests

### Backend (`backend/`)
- FastAPI REST API server
- Database models and schemas
- Blockchain event listeners
- IoT device management

### Mobile (`mobile/`)
- Flutter cross-platform mobile app
- Riverpod state management
- WalletConnect and Web3 integration
- Material 3 UI design

### IoT Device (`iot_device/`)
- ESP32 firmware for smart lock
- WiFi and API communication
- Realtime database synchronization

## 🔑 Key Integration Points

1. **Blockchain ↔ Backend**: Event listeners track on-chain activity
2. **Backend ↔ Mobile**: REST API for CRUD operations
3. **Mobile ↔ Blockchain**: Direct Web3 transactions via WalletConnect
4. **Backend ↔ IoT**: API endpoints for lock control
5. **IoT ↔ Database**: Realtime synchronization via Supabase

## 🚀 Getting Started

See individual README files in each directory for setup instructions.

## 📄 License

MIT
