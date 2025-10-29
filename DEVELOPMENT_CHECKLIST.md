# 🚀 SmartRent Development Checklist
**Agile Parallel Development Methodology**  
**4-Person Team: Blockchain, Backend, IoT, Mobile**

---

## 📋 PHASE 1: FOUNDATIONAL PoCs (Proof of Concepts)
**Goal: Build simple, standalone proofs-of-concept for each component**

### 🔗 BLOCKCHAIN TEAM

#### Sprint 1.1: Smart Contract Development
- [ ] Set up Hardhat development environment
  - [ ] Install dependencies: `cd blockchain && npm install`
  - [ ] Configure `hardhat.config.js` for Sepolia testnet
  - [ ] Create `.env` file with private key and Infura API key
  - [ ] Test Hardhat connection: `npx hardhat compile`

- [ ] Complete AssetToken (ERC721) Contract
  - [ ] Review and test `AssetToken.sol`
  - [ ] Add comprehensive tests in `test/AssetToken.test.js`
  - [ ] Test minting, transfer, and rental availability functions
  - [ ] Verify gas optimization

- [ ] Deploy AssetToken to Sepolia Testnet
  - [ ] Create deployment script: `scripts/deploy-asset-token.js`
  - [ ] Deploy contract: `npx hardhat run scripts/deploy-asset-token.js --network sepolia`
  - [ ] Verify contract on Etherscan
  - [ ] Save deployed contract address

- [ ] Create AssetShare (ERC20) Contract
  - [ ] Implement ERC20 token for fractional ownership
  - [ ] Add minting and burning functions
  - [ ] Test fractional ownership mechanics
  - [ ] Deploy to testnet

#### Sprint 1.2: AssetFactory Contract
- [ ] Build AssetFactory contract
  - [ ] Implement factory pattern for creating AssetShare tokens
  - [ ] Add asset registration and management
  - [ ] Test asset creation flow
  - [ ] Deploy to testnet

#### Documentation
- [ ] Document all contract functions with NatSpec comments
- [ ] Create contract interaction guide
- [ ] Update README.md with deployment addresses
- [ ] Create ABI files for frontend integration

---

### 🔧 BACKEND TEAM

#### Sprint 1.1: FastAPI Server Setup
- [ ] Set up Python virtual environment
  - [ ] `cd backend`
  - [ ] `python -m venv venv`
  - [ ] `source venv/bin/activate` (macOS/Linux) or `venv\Scripts\activate` (Windows)
  - [ ] Install dependencies: `pip install -r requirements.txt`

- [ ] Database Configuration
  - [ ] Set up Supabase project
  - [ ] Create database schema in `db/schema.py`
  - [ ] Implement database models in `db/models.py`
  - [ ] Test database connection
  - [ ] Run migrations

- [ ] Implement Core API Endpoints
  - [ ] **Users API** (`api/routes/users.py`)
    - [ ] POST `/api/v1/users` - Create user
    - [ ] GET `/api/v1/users/{id}` - Get user by ID
    - [ ] GET `/api/v1/users/wallet/{address}` - Get user by wallet
    - [ ] PUT `/api/v1/users/{id}` - Update user
    - [ ] Test all endpoints

  - [ ] **Assets API** (`api/routes/assets.py`)
    - [ ] POST `/api/v1/assets` - Create asset
    - [ ] GET `/api/v1/assets` - List assets (with filters)
    - [ ] GET `/api/v1/assets/{id}` - Get asset details
    - [ ] PUT `/api/v1/assets/{id}` - Update asset
    - [ ] POST `/api/v1/assets/{id}/toggle-availability` - Toggle rental status
    - [ ] Test all endpoints

  - [ ] **Rentals API** (`api/routes/rentals.py`)
    - [ ] POST `/api/v1/rentals` - Create rental
    - [ ] GET `/api/v1/rentals` - List rentals (with filters)
    - [ ] GET `/api/v1/rentals/{id}` - Get rental details
    - [ ] POST `/api/v1/rentals/{id}/activate` - Start rental
    - [ ] POST `/api/v1/rentals/{id}/complete` - Complete rental
    - [ ] POST `/api/v1/rentals/{id}/cancel` - Cancel rental
    - [ ] Test all endpoints

#### Sprint 1.2: Authentication & Web3 Integration
- [ ] Implement Supabase Authentication
  - [ ] Set up authentication middleware
  - [ ] Implement JWT token validation
  - [ ] Add wallet-based authentication
  - [ ] Test authentication flow

- [ ] Web3 Integration (`core/web3_utils.py`)
  - [ ] Connect to Ethereum node (Infura/Alchemy)
  - [ ] Implement contract interaction utilities
  - [ ] Add event listening capabilities
  - [ ] Test blockchain read operations

#### Documentation
- [ ] Generate API documentation (FastAPI auto-docs)
- [ ] Create Postman collection for API testing
- [ ] Document database schema
- [ ] Update README.md with setup instructions

---

### 📱 MOBILE TEAM

#### Sprint 1.1: Flutter App Foundation
- [ ] Set up Flutter project
  - [ ] `cd mobile`
  - [ ] Install dependencies: `flutter pub get`
  - [ ] Test app runs: `flutter run`
  - [ ] Configure iOS and Android platforms

- [ ] State Management Setup
  - [ ] Verify Riverpod providers are working
  - [ ] Test provider hot-reload
  - [ ] Review provider architecture

- [ ] Routing Configuration
  - [ ] Test GoRouter navigation
  - [ ] Verify route guards and redirects
  - [ ] Test deep linking (optional for Phase 1)

- [ ] API Service Integration
  - [ ] Update `constants/config.dart` with backend URL
  - [ ] Test API service initialization
  - [ ] Implement error handling
  - [ ] Test API connectivity with backend

#### Sprint 1.2: Authentication UI
- [ ] **Login Screen** (`screens/auth/login_screen.dart`)
  - [ ] Design login form (email/password)
  - [ ] Implement form validation
  - [ ] Connect to backend login API
  - [ ] Add loading states and error handling
  - [ ] Test login flow

- [ ] **Register Screen** (`screens/auth/register_screen.dart`)
  - [ ] Design registration form
  - [ ] Implement form validation
  - [ ] Connect to backend registration API
  - [ ] Add success/error feedback
  - [ ] Test registration flow

- [ ] **WalletConnect Integration** (`screens/auth/wallet_connect_screen.dart`)
  - [ ] Integrate WalletConnect SDK
  - [ ] Implement wallet connection flow
  - [ ] Handle connection errors
  - [ ] Save wallet address
  - [ ] Test with MetaMask mobile

- [ ] **Profile Screen** (`screens/profile_screen.dart`)
  - [ ] Display user information
  - [ ] Show wallet address
  - [ ] Add edit profile functionality
  - [ ] Implement logout
  - [ ] Test profile updates

#### Documentation
- [ ] Document app architecture
- [ ] Create UI/UX guidelines
- [ ] Update README.md with build instructions
- [ ] Document state management patterns

---

### 🔌 IoT TEAM

#### Sprint 1.1: Hardware Setup
- [ ] Set up ESP32 development environment
  - [ ] Install Arduino IDE or PlatformIO
  - [ ] Install ESP32 board support
  - [ ] Test basic ESP32 program upload

- [ ] Remote Lock Control PoC
  - [ ] Connect lock mechanism to ESP32
  - [ ] Implement basic lock/unlock functions
  - [ ] Test physical lock control
  - [ ] Add status LEDs for feedback

#### Sprint 1.2: WiFi & API Communication
- [ ] WiFi Connection
  - [ ] Implement WiFi connection code
  - [ ] Add connection retry logic
  - [ ] Test stable connection

- [ ] Backend API Integration
  - [ ] Implement HTTP client
  - [ ] Test API authentication
  - [ ] Implement lock status polling
  - [ ] Test remote lock/unlock command

#### Documentation
- [ ] Document hardware setup and wiring
- [ ] Create circuit diagrams
- [ ] Document API endpoints used
- [ ] Update README.md with IoT setup

---

## 📋 PHASE 2: INCREASED COMPLEXITY

### 🔗 BLOCKCHAIN TEAM

#### Sprint 2.1: RentalManager Contract
- [ ] Design RentalManager smart contract
  - [ ] Define rental agreement structure
  - [ ] Implement rental creation logic
  - [ ] Add escrow functionality
  - [ ] Implement rental state machine (created, active, completed, cancelled)

- [ ] Complete RentalAgreement Contract
  - [ ] Review and enhance `RentalAgreement.sol`
  - [ ] Add comprehensive tests
  - [ ] Test rental lifecycle
  - [ ] Deploy to Sepolia testnet

#### Sprint 2.2: Advanced Features
- [ ] Implement security deposit logic
- [ ] Add dispute resolution mechanism
- [ ] Implement platform fee calculation
- [ ] Test edge cases and security
- [ ] Deploy and verify contracts

---

### 🔧 BACKEND TEAM

#### Sprint 2.1: Blockchain Listener Service
- [ ] Create Persistent Listener Service
  - [ ] Design event listener architecture
  - [ ] Implement async WebSocket connection to blockchain
  - [ ] Listen for AssetToken Transfer events
  - [ ] Listen for RentalAgreement events (Created, Started, Completed)
  - [ ] Test event detection

- [ ] Database Synchronization
  - [ ] Update database on blockchain events
  - [ ] Implement data consistency checks
  - [ ] Add retry mechanisms for failed updates
  - [ ] Test event-to-database flow

#### Sprint 2.2: Advanced API Features
- [ ] Implement pagination for all list endpoints
- [ ] Add filtering and sorting
- [ ] Implement caching (Redis)
- [ ] Add rate limiting
- [ ] Optimize query performance

---

### 📱 MOBILE TEAM

#### Sprint 2.1: WalletConnect & Blockchain Integration
- [ ] Implement WalletConnect SDK
  - [ ] Complete wallet connection flow
  - [ ] Implement session management
  - [ ] Add account switching
  - [ ] Test multi-wallet support

- [ ] Transaction Management
  - [ ] Create transaction state management
  - [ ] Implement "awaiting signature" UI
  - [ ] Add transaction pending state
  - [ ] Show transaction confirmation
  - [ ] Handle transaction errors
  - [ ] Test full transaction flow

- [ ] Wallet Screen Enhancement
  - [ ] Display ETH balance
  - [ ] Show transaction history
  - [ ] Add network switching (Sepolia/Mainnet)
  - [ ] Test wallet features

#### Sprint 2.2: Asset & Rental Screens
- [ ] **Home Screen** (`screens/home_screen.dart`)
  - [ ] Display available assets list
  - [ ] Implement pull-to-refresh
  - [ ] Add category filters
  - [ ] Implement infinite scroll
  - [ ] Test asset loading

- [ ] **Asset Details Screen** (`screens/asset_details.dart`)
  - [ ] Display full asset information
  - [ ] Show asset images
  - [ ] Display price and availability
  - [ ] Add "Rent Now" button
  - [ ] Test asset details

- [ ] **Create Rental Flow** (`screens/rentals/create_rental_screen.dart`)
  - [ ] Design rental booking form
  - [ ] Implement date picker
  - [ ] Calculate total price
  - [ ] Integrate with blockchain (create rental transaction)
  - [ ] Handle transaction states
  - [ ] Test rental creation

- [ ] **My Rentals Screen** (`screens/rental_screen.dart`)
  - [ ] List user's rentals (as renter and owner)
  - [ ] Show rental status badges
  - [ ] Implement filters (active, completed, etc.)
  - [ ] Test rental list

---

### 🔌 IoT TEAM

#### Sprint 2.1: Supabase Realtime Integration
- [ ] Set up Supabase client on ESP32
  - [ ] Implement authentication
  - [ ] Subscribe to database changes
  - [ ] Test realtime updates

- [ ] Lock Status Database Listener
  - [ ] Listen for `lock_status` table updates
  - [ ] Filter by device ID
  - [ ] Trigger lock action on update
  - [ ] Test end-to-end flow

#### Sprint 2.2: Security & Reliability
- [ ] Implement OTA (Over-The-Air) updates
- [ ] Add device authentication
- [ ] Implement local logging
- [ ] Add failsafe mechanisms
- [ ] Test network interruption scenarios

---

## 📋 PHASE 3: CRITICAL INTEGRATIONS

### 🔗 BLOCKCHAIN TEAM

#### Sprint 3.1: Governance & Fractional Ownership
- [ ] Implement ERC20 Transfer event monitoring
- [ ] Add shareholder calculation logic
- [ ] Test governance rights updates
- [ ] Deploy finalized contracts to testnet

#### Sprint 3.2: Testing & Security
- [ ] Comprehensive contract testing
- [ ] Security audit (automated tools)
- [ ] Gas optimization
- [ ] Prepare for mainnet deployment

---

### 🔧 BACKEND TEAM

#### Sprint 3.1: Dynamic Governance Listener
- [ ] Create Governance Listener Service
  - [ ] Listen for ERC20 Transfer events
  - [ ] Calculate largest shareholder
  - [ ] Update Supabase `governance_rights` table
  - [ ] Test governance updates

- [ ] Business Logic Enforcement
  - [ ] Add middleware to check governance rights
  - [ ] Restrict actions to decision-makers
  - [ ] Implement price change authorization
  - [ ] Test authorization logic

#### Sprint 3.2: IoT Integration
- [ ] Create IoT Lock API
  - [ ] POST `/api/v1/iot/unlock` - Unlock door
  - [ ] Verify user is current renter
  - [ ] Update `lock_status` in database
  - [ ] Test IoT API

- [ ] Add device management
  - [ ] Register IoT devices
  - [ ] Manage device access
  - [ ] Test device control

---

### 📱 MOBILE TEAM

#### Sprint 3.1: Asset Management
- [ ] **Create Asset Screen** (`screens/assets/create_asset_screen.dart`)
  - [ ] Design asset creation form
  - [ ] Add image upload
  - [ ] Integrate with blockchain (mint NFT)
  - [ ] Handle transaction flow
  - [ ] Test asset creation

- [ ] **My Assets Screen** (`screens/assets/my_assets_screen.dart`)
  - [ ] List user's owned assets
  - [ ] Add edit and delete functionality
  - [ ] Show rental history per asset
  - [ ] Test asset management

#### Sprint 3.2: Governance & IoT Integration
- [ ] Dynamic UI based on Governance Rights
  - [ ] Listen to governance state changes
  - [ ] Conditionally render admin UI
  - [ ] Show/hide price editing
  - [ ] Show/hide asset management features
  - [ ] Test conditional rendering

- [ ] **IoT Lock Control**
  - [ ] Add "Unlock" button in Rental Details
  - [ ] Verify user is current renter
  - [ ] Call backend unlock API
  - [ ] Show unlock status feedback
  - [ ] Test end-to-end unlock flow

- [ ] **Rental Details Screen** (`screens/rentals/rental_details_screen.dart`)
  - [ ] Display full rental information
  - [ ] Show timeline (created, active, completed)
  - [ ] Add action buttons (activate, complete, cancel)
  - [ ] Integrate IoT unlock button
  - [ ] Test rental actions

---

### 🔌 IoT TEAM

#### Sprint 3.1: Complete Integration
- [ ] Test full unlock flow
  - [ ] Mobile app → Backend API → Database → ESP32 → Lock
  - [ ] Test various scenarios
  - [ ] Add error handling

#### Sprint 3.2: Production Readiness
- [ ] Implement device monitoring
- [ ] Add battery status reporting (if applicable)
- [ ] Test long-term stability
- [ ] Document deployment procedures

---

## 🧪 TESTING & QUALITY ASSURANCE

### All Teams
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Perform manual testing
- [ ] Fix critical bugs
- [ ] Code review and refactoring

---

## 📦 DEPLOYMENT PREPARATION

### Blockchain
- [ ] Final testnet deployment
- [ ] Security audit
- [ ] Prepare mainnet deployment plan

### Backend
- [ ] Set up production environment (AWS/GCP/Heroku)
- [ ] Configure environment variables
- [ ] Set up CI/CD pipeline
- [ ] Deploy to staging

### Mobile
- [ ] Prepare app store listings
- [ ] Create app icons and screenshots
- [ ] Test on physical devices
- [ ] Prepare beta release (TestFlight/Play Store Beta)

### IoT
- [ ] Flash production firmware
- [ ] Test in real-world environment
- [ ] Document device setup for users

---

## 📚 DOCUMENTATION

### All Teams
- [ ] Update README.md files
- [ ] Create user documentation
- [ ] Create developer documentation
- [ ] Create deployment guides
- [ ] Record demo videos

---

## 🎯 FINAL INTEGRATION TEST

- [ ] Test complete user journey:
  1. User registers and connects wallet
  2. User creates an asset (mints NFT)
  3. Another user rents the asset
  4. Rental payment is processed
  5. Renter unlocks IoT device
  6. Rental is completed
  7. Funds are distributed

---

## 🚀 LAUNCH

- [ ] Deploy contracts to mainnet
- [ ] Deploy backend to production
- [ ] Release mobile app to stores
- [ ] Deploy IoT devices
- [ ] Monitor for issues
- [ ] Celebrate! 🎉

---

## 📝 NOTES

- **Daily Stand-ups**: Each team should sync daily
- **Weekly Cross-Team Meeting**: All teams sync on integration points
- **Use Git branching strategy**: feature branches → develop → main
- **Document everything**: Code, APIs, contracts, hardware setup
- **Test early and often**: Don't wait until the end

---

## 🆘 COMMON ISSUES & SOLUTIONS

### Blockchain
- **Issue**: Insufficient funds for gas
- **Solution**: Get testnet ETH from Sepolia faucet

### Backend
- **Issue**: CORS errors
- **Solution**: Configure CORS in `main.py`

### Mobile
- **Issue**: WalletConnect not connecting
- **Solution**: Check project ID and app configuration

### IoT
- **Issue**: ESP32 can't connect to WiFi
- **Solution**: Check WiFi credentials and network settings

---

**Good luck with your SmartRent development! 🚀**
