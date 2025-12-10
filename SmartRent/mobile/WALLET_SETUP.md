# Wallet Integration Setup Guide

## ✅ Completed Setup

### 1. Deep Link Integration
- WalletConnect deep link support added
- Automatic wallet app launching (Trust Wallet, MetaMask)
- Mobile-optimized flow (no QR codes needed)

## 🔧 Platform Configuration

### Android Setup

#### Step 1: Update `AndroidManifest.xml`

File: `SmartRent/mobile/android/app/src/main/AndroidManifest.xml`

Add the following inside `<manifest>` tag (before `<application>`):

```xml
<!-- Add this for Android 11+ (API 30+) to allow querying wallet apps -->
<queries>
    <!-- Trust Wallet -->
    <package android:name="com.wallet.crypto.trustapp" />
    
    <!-- MetaMask -->
    <package android:name="io.metamask" />
    
    <!-- Rainbow Wallet -->
    <package android:name="me.rainbow" />
    
    <!-- Generic WalletConnect support -->
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="wc" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
</queries>
```

#### Step 2: Internet Permission (Already exists, verify)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

#### Step 3: Deep Link Return (Optional - if you want app to return automatically)

Add inside `<activity android:name=".MainActivity">`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <!-- Deep link scheme for returning to SmartRent -->
    <data
        android:scheme="smartrent"
        android:host="wallet" />
</intent-filter>
```

### iOS Setup

#### Step 1: Update `Info.plist`

File: `SmartRent/mobile/ios/Runner/Info.plist`

Add before the closing `</dict>` tag:

```xml
<!-- WalletConnect Deep Links -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <!-- Trust Wallet -->
    <string>trust</string>
    <string>trustwallet</string>
    
    <!-- MetaMask -->
    <string>metamask</string>
    
    <!-- Rainbow -->
    <string>rainbow</string>
    
    <!-- Generic WalletConnect -->
    <string>wc</string>
</array>

<!-- Deep Link Return (Optional) -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.smartrent.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>smartrent</string>
        </array>
    </dict>
</array>
```

## 📱 User Flow

### Connection Flow

```
1. User opens SmartRent app
2. User taps "Connect Wallet" button
3. Loading dialog appears: "Opening your wallet app..."
4. SmartRent launches Trust Wallet/MetaMask via deep link
5. Wallet app opens with connection request
6. User taps "Approve" in wallet
7. SmartRent automatically comes back to foreground
8. Success message: "✅ Wallet connected"
9. User sees their address and balance
```

### Transaction Flow

```
1. User taps "Pay Rent" (or any transaction button)
2. SmartRent prepares transaction
3. Trust Wallet/MetaMask opens automatically
4. User sees transaction details:
   - To: 0x5704...9193C (RentalManager)
   - Value: 0.1 ETH
   - Gas: ~0.002 ETH
5. User taps "Confirm"
6. Transaction signed in wallet
7. SmartRent receives transaction hash
8. Success dialog shows with transaction hash
```

## 🧪 Testing Checklist

### Prerequisites
- [ ] Trust Wallet installed on test device
- [ ] OR MetaMask installed on test device
- [ ] Test wallet has Sepolia ETH

### Test Cases

#### 1. Wallet Connection
- [ ] Tap "Connect Wallet"
- [ ] Loading dialog appears
- [ ] Trust Wallet opens automatically
- [ ] Connection request visible
- [ ] Tap "Approve"
- [ ] SmartRent comes back
- [ ] Address and balance displayed
- [ ] No errors in console

#### 2. Wallet Disconnection
- [ ] Tap disconnect button
- [ ] Confirmation dialog appears
- [ ] Tap "Disconnect"
- [ ] Wallet info cleared
- [ ] "Connect Wallet" button visible again

#### 3. Session Persistence
- [ ] Connect wallet
- [ ] Close SmartRent app completely
- [ ] Reopen SmartRent app
- [ ] Wallet still connected (no need to reconnect)
- [ ] Balance updated

#### 4. Transaction (Optional - if implemented)
- [ ] Connect wallet
- [ ] Navigate to rent payment screen
- [ ] Enter payment details
- [ ] Tap "Pay Rent"
- [ ] Trust Wallet opens
- [ ] Transaction details correct
- [ ] Tap "Confirm"
- [ ] Transaction hash received
- [ ] Success message shown

## ⚠️ Common Issues & Solutions

### Issue 1: "No compatible wallet found"
**Cause:** Wallet app not installed
**Solution:** Install Trust Wallet or MetaMask from app store

### Issue 2: Wallet app doesn't open
**Cause:** Missing platform configuration
**Solution:** 
- Android: Add `<queries>` to AndroidManifest.xml
- iOS: Add `LSApplicationQueriesSchemes` to Info.plist

### Issue 3: Connection timeout
**Cause:** User didn't approve in wallet within 5 minutes
**Solution:** Increase timeout or retry connection

### Issue 4: Session not restored
**Cause:** SharedPreferences not working
**Solution:** Check permissions and storage access

## 🔐 Security Notes

1. **Private Keys Never Leave Wallet**
   - All signing happens in Trust Wallet/MetaMask
   - SmartRent never sees or stores private keys

2. **User Control**
   - User must approve every transaction
   - User can disconnect anytime
   - No auto-approve functionality

3. **Session Security**
   - Session stored in secure SharedPreferences
   - Session topic used to reconnect
   - No sensitive data in session storage

## 📚 Wallet App Links

### For Testing
- **Trust Wallet (Recommended)**
  - Android: https://play.google.com/store/apps/details?id=com.wallet.crypto.trustapp
  - iOS: https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409

- **MetaMask**
  - Android: https://play.google.com/store/apps/details?id=io.metamask
  - iOS: https://apps.apple.com/app/metamask/id1438144202

### Get Test ETH (Sepolia)
1. https://sepoliafaucet.com
2. https://www.alchemy.com/faucets/ethereum-sepolia
3. https://faucet.quicknode.com/ethereum/sepolia

## 🎯 Next Steps

After completing wallet setup:

1. ✅ Test connection on physical device (emulator might have issues)
2. ✅ Test transaction flow
3. ✅ Move to Phase 3: Backend Read-Only conversion
4. ✅ Implement event listening for blockchain → database sync

## 📝 Environment Variables

Already configured in `wallet_service.dart`:
- ✅ WalletConnect Project ID: `17a60844bceaf7f347f653e3ead1c165`
- ✅ Sepolia RPC URL: From `blockchain_config.dart`
- ✅ Contract Addresses: From `blockchain_config.dart`

## 🔄 Deep Link Format Reference

```
Trust Wallet:   https://link.trustwallet.com/wc?uri={wcUri}
MetaMask:       https://metamask.app.link/wc?uri={wcUri}
Rainbow:        https://rnbwapp.com/wc?uri={wcUri}
Generic:        wc:{topic}@{version}?relay-protocol=...
```

## 📞 Support Resources

- WalletConnect Docs: https://docs.walletconnect.com
- Trust Wallet Developer: https://developer.trustwallet.com
- MetaMask Developer: https://docs.metamask.io
- web3dart Package: https://pub.dev/packages/web3dart

