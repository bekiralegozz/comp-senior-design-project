# Platform Detection - Web & Mobile Support

## ✅ Implemented Features

### Platform-Aware Wallet Connection

The wallet connection now automatically detects the platform and uses the appropriate method:

#### 🌐 Web (Chrome, Firefox, Edge)
```dart
if (kIsWeb) {
  // Show QR code for scanning with mobile wallet
}
```

**User Flow:**
1. User clicks "Connect Wallet" in browser
2. QR code dialog appears
3. User scans QR with Trust Wallet/MetaMask on phone
4. User approves in mobile wallet
5. Browser shows "✅ Connected"

#### 📱 Mobile (Android, iOS)
```dart
else {
  // Launch wallet app via deep link
}
```

**User Flow:**
1. User taps "Connect Wallet" in app
2. Trust Wallet/MetaMask opens automatically
3. User approves connection
4. Returns to SmartRent automatically
5. Shows "✅ Connected"

## 🎨 UI Differences

### Web UI
```
┌─────────────────────────────┐
│   Connect Your Wallet       │
├─────────────────────────────┤
│                             │
│  Scan with mobile wallet:   │
│                             │
│    ┌─────────────────┐      │
│    │                 │      │
│    │   [QR CODE]     │      │
│    │                 │      │
│    └─────────────────┘      │
│                             │
│  ℹ️  Waiting for approval   │
│     in your wallet app...   │
│                             │
│           [Cancel]          │
└─────────────────────────────┘
```

### Mobile UI
```
┌─────────────────────────────┐
│   Opening wallet app...     │
├─────────────────────────────┤
│                             │
│      ⏳ Loading...          │
│                             │
│  Please approve in wallet   │
│                             │
│  ℹ️  Make sure Trust Wallet │
│     or MetaMask installed   │
│                             │
└─────────────────────────────┘
```

## 🔧 Technical Implementation

### Service Layer (`wallet_service.dart`)

```dart
// Platform detection in connect()
if (kIsWeb) {
  // WEB: Return URI for QR code display
  print('📱 Web platform: Show QR code');
} else {
  // MOBILE: Launch wallet app via deep link
  print('📱 Mobile platform: Launching wallet app');
  await _launchWalletApp(wcUri);
}
```

### UI Layer (`wallet_connect_button.dart`)

```dart
// Platform-specific button handler
if (kIsWeb) {
  await _showWebConnectDialog(context, notifier);
} else {
  await _showMobileConnectDialog(context, notifier);
}
```

## 📊 Platform Support Matrix

| Feature | Web | Android | iOS |
|---------|-----|---------|-----|
| WalletConnect | ✅ | ✅ | ✅ |
| QR Code | ✅ | ❌ | ❌ |
| Deep Link | ❌ | ✅ | ✅ |
| Balance Display | ✅ | ✅ | ✅ |
| Transaction Signing | ✅ | ✅ | ✅ |
| Session Persistence | ✅ | ✅ | ✅ |

## 🧪 Testing

### Test on Web (Chrome)
```bash
flutter run -d chrome
```

**Expected:**
- [x] "Connect Wallet" button visible
- [x] Click → QR code dialog appears
- [x] QR code is scannable
- [x] After scanning with mobile wallet → "Connected" message
- [x] Address and balance displayed

### Test on Android
```bash
flutter run -d <android-device-id>
```

**Expected:**
- [x] "Connect Wallet" button visible
- [x] Tap → Trust Wallet opens automatically
- [x] Approve → Returns to SmartRent
- [x] "Connected" message appears
- [x] Address and balance displayed

### Test on iOS
```bash
flutter run -d <ios-device-id>
```

**Expected:**
- [x] Same as Android
- [x] Seamless app switching

## 🎯 Code Locations

### Modified Files
1. **`lib/services/wallet_service.dart`**
   - Line ~90: Platform detection added
   - Uses `kIsWeb` to determine platform

2. **`lib/widgets/wallet_connect_button.dart`**
   - Line ~40: Platform-specific button handler
   - Line ~50: Web connection flow (QR code)
   - Line ~100: Mobile connection flow (deep link)
   - Line ~150: QR code dialog for web

### Dependencies
```yaml
dependencies:
  flutter/foundation.dart  # for kIsWeb
  qr_flutter: ^4.1.0      # for QR code generation
  url_launcher: ^6.2.1     # for deep links
```

## 🔍 Debug Output

### Web Console
```
🔗 WalletConnect URI: wc:abc123...
📱 Web platform: Show QR code for scanning
⏳ Waiting for wallet approval...
✅ Wallet connected successfully
```

### Mobile Console
```
🔗 WalletConnect URI: wc:abc123...
📱 Mobile platform: Launching wallet app...
✅ Launched wallet with: https://link.trustwallet.com/wc?uri=...
⏳ Waiting for wallet approval...
✅ Wallet connected successfully
```

## ⚠️ Known Limitations

### Web
- **Browser Extensions:** Some users prefer MetaMask browser extension, but we only support WalletConnect (mobile wallet)
- **QR Code Size:** Fixed at 250x250, might be small on large screens
- **Cancel During QR:** Canceling while waiting for approval might leave WC session open

### Mobile
- **Wallet App Required:** User must have Trust Wallet or MetaMask installed
- **Deep Link Conflicts:** If multiple wallet apps installed, system might ask which to use
- **Background Return:** On some Android versions, app might not come to foreground after approval

## 🚀 Future Improvements

### Web
- [ ] Add "Copy Link" button for manual paste
- [ ] Support MetaMask browser extension detection
- [ ] Add wallet app download links if no app detected
- [ ] Make QR code size responsive

### Mobile
- [ ] Add wallet selection dialog (if multiple wallets)
- [ ] Show wallet app icons
- [ ] Add "Open Wallet" button if deep link fails
- [ ] Improve error messages for specific wallets

## 📝 Environment Variables

No additional environment variables needed. Platform detection uses:
- `kIsWeb` from `package:flutter/foundation.dart`
- Automatic at compile time
- No runtime configuration needed

## 🔗 Related Files

- `lib/services/wallet_service.dart` - Core wallet logic
- `lib/widgets/wallet_connect_button.dart` - UI component
- `lib/core/providers/wallet_provider.dart` - State management
- `lib/constants/blockchain_config.dart` - Chain configuration

## 📞 Troubleshooting

### Issue: QR code doesn't appear on web
**Solution:** Check console for errors, ensure `qr_flutter` is installed

### Issue: Deep link doesn't work on mobile
**Solution:** 
1. Verify AndroidManifest.xml has `<queries>` section
2. Verify Info.plist has `LSApplicationQueriesSchemes`
3. Ensure wallet app is installed

### Issue: "Platform not supported"
**Solution:** Code automatically detects platform, no manual configuration needed

## ✅ Testing Checklist

- [x] Web: QR code displays correctly
- [x] Web: QR code is scannable
- [x] Web: Connection works after scanning
- [x] Mobile: Deep link launches wallet
- [x] Mobile: Returns to app after approval
- [x] Both: Balance displays correctly
- [x] Both: Session persists after app restart
- [x] Both: Disconnect works properly

