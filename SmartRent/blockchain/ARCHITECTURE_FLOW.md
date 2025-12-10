# SmartRent Blockchain Mimari Akışı

## 🎯 Temel Soru: Database mi Blockchain'i Güncelliyor, Blockchain mi Database'i?

**Cevap: İkisi de değil! Blockchain Server her ikisini de yönetiyor.**

---

## 📊 İki Yönlü Akış

### 1️⃣ Database → Blockchain (Transaction Gönderme)

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐         ┌──────────────┐
│ Mobile App  │ ──────> │   Backend    │ ──────> │  Supabase   │ <────── │ Blockchain   │
│  (Flutter)  │  HTTP   │   (FastAPI)  │  SQL    │  (Postgres) │  Poll   │   Server     │
└─────────────┘         └──────────────┘         └─────────────┘         └──────────────┘
                                                                                  │
                                                                                  │ Web3
                                                                                  │ Transaction
                                                                                  ▼
                                                                          ┌──────────────┐
                                                                          │   Sepolia    │
                                                                          │  Testnet     │
                                                                          └──────────────┘
```

**Adım Adım:**

1. **Mobile App** → Backend'e HTTP isteği atar
   - Örnek: `POST /api/v1/assets/create`
   - Örnek: `POST /api/v1/rent/pay`
   - Örnek: `POST /api/v1/marketplace/buy-share`

2. **Backend** → `chain_actions` tablosuna kayıt ekler
   ```sql
   INSERT INTO chain_actions (type, payload, status) 
   VALUES ('MINT_ASSET', '{"tokenId": 1, "totalSupply": 1000, ...}', 'PENDING');
   ```
   - Status: `PENDING`
   - Hemen response döner (async pattern)

3. **Blockchain Server** → `chain_actions` tablosunu poll eder (her 5 saniyede bir)
   - `status = 'PENDING'` olan kayıtları bulur
   - Web3/ethers.js ile contract fonksiyonunu çağırır
   - Transaction'ı sign edip Sepolia'ya gönderir

4. **Blockchain Server** → `chain_actions` tablosunu günceller
   ```sql
   UPDATE chain_actions 
   SET status = 'SENT', tx_hash = '0x...' 
   WHERE id = '...';
   ```

5. **Sepolia** → Transaction'ı işler ve onaylar

6. **Blockchain Server** → Transaction onaylandıktan sonra
   ```sql
   UPDATE chain_actions 
   SET status = 'CONFIRMED' 
   WHERE tx_hash = '0x...';
   ```

---

### 2️⃣ Blockchain → Database (Event Listening)

```
┌──────────────┐         ┌──────────────┐         ┌─────────────┐
│   Sepolia    │ ──────> │ Blockchain   │ ──────> │  Supabase   │
│  Testnet     │  Event  │   Server     │  SQL    │  (Postgres) │
└──────────────┘         └──────────────┘         └─────────────┘
```

**Adım Adım:**

1. **Sepolia** → Contract event emit eder
   - `RentPaid(assetId, payer, amount, timestamp)`
   - `ShareTraded(tokenId, buyer, seller, shareAmount, ethAmount)`
   - `Transfer(from, to, tokenId, amount)` (ERC-1155)

2. **Blockchain Server** → Event'leri dinler (WebSocket veya polling)
   - Event'leri parse eder
   - Database'i günceller:
     - `assets` tablosu
     - `ownerships` tablosu (pay sahipliği)
     - `rentals` tablosu (kira ödemeleri)
     - `chain_actions.status = 'CONFIRMED'` (eğer ilgili action varsa)

---

## 🔄 Tam Döngü Örneği: Rent Ödeme

### Senaryo: Kullanıcı kira ödüyor

1. **Mobile App** → `POST /api/v1/rent/pay`
   ```json
   {
     "assetId": 1,
     "amount": "0.1",
     "owners": ["0xABC...", "0xDEF..."]
   }
   ```

2. **Backend** → `chain_actions` tablosuna yazar
   ```sql
   INSERT INTO chain_actions (type, payload, status) VALUES (
     'PAY_RENT',
     '{"assetId": 1, "amount": "0.1", "owners": ["0xABC...", "0xDEF..."]}',
     'PENDING'
   );
   ```
   → Hemen response: `{"status": "pending", "actionId": "..."}`

3. **Blockchain Server** → Poll eder, `PENDING` bulur
   - `RentalManager.payRent(assetId, owners)` fonksiyonunu çağırır
   - `msg.value = 0.1 ETH` ile transaction gönderir
   - `chain_actions.status = 'SENT'`, `tx_hash = '0x...'`

4. **Sepolia** → Transaction onaylanır
   - `RentPaid` event emit edilir
   - ETH pay sahiplerine dağıtılır

5. **Blockchain Server** → Event'i dinler
   - `RentPaid` event'ini yakalar
   - `rentals` tablosuna kayıt ekler
   - `chain_actions.status = 'CONFIRMED'` yapar

6. **Mobile App** → Status'u kontrol eder
   - `GET /api/v1/rent/payment-status/{actionId}`
   - Response: `{"status": "confirmed", "txHash": "0x..."}`

---

## 🎯 Önemli Noktalar

### ❌ Database Blockchain'i Güncellemez
- Database sadece **istek** yazar (`chain_actions` tablosuna)
- Blockchain Server bu istekleri okuyup blockchain'e transaction gönderir

### ❌ Blockchain Database'i Güncellemez
- Blockchain sadece **event** emit eder
- Blockchain Server bu event'leri dinleyip database'i günceller

### ✅ Blockchain Server Her İkisini de Yönetir
- **Transaction Gönderme:** Database'den okuyup blockchain'e gönderir
- **Event Listening:** Blockchain'den event dinleyip database'i günceller

---

## 📋 Blockchain Server'ın İki Ana Görevi

### 1. Action Worker (Transaction Gönderme)
```javascript
// Her 5 saniyede bir çalışır
async function processPendingActions() {
  // 1. chain_actions tablosundan PENDING olanları al
  const pendingActions = await db
    .from('chain_actions')
    .select('*')
    .eq('status', 'PENDING');
  
  // 2. Her biri için blockchain'e transaction gönder
  for (const action of pendingActions) {
    if (action.type === 'MINT_ASSET') {
      await mintAsset(action.payload);
    } else if (action.type === 'PAY_RENT') {
      await payRent(action.payload);
    }
    // ...
    
    // 3. chain_actions'ı güncelle
    await db
      .from('chain_actions')
      .update({ status: 'SENT', tx_hash: txHash })
      .eq('id', action.id);
  }
}
```

### 2. Event Listener (Database Güncelleme)
```javascript
// Sürekli çalışır (WebSocket veya polling)
async function listenToEvents() {
  // 1. Contract event'lerini dinle
  rentalManager.on('RentPaid', async (assetId, payer, amount, timestamp) => {
    // 2. Database'i güncelle
    await db.from('rentals').insert({
      asset_id: assetId,
      payer: payer,
      amount: amount,
      timestamp: timestamp,
      tx_hash: event.transactionHash
    });
    
    // 3. İlgili chain_action'ı CONFIRMED yap
    await db
      .from('chain_actions')
      .update({ status: 'CONFIRMED' })
      .eq('tx_hash', event.transactionHash);
  });
}
```

---

## 🔐 Güvenlik Notları

1. **Hot Wallet:** Blockchain Server'ın kendi wallet'ı var (private key)
   - Bu wallet tüm transaction'ları sign eder
   - Sadece Sepolia ETH'si olmalı (test amaçlı)

2. **Service Role Key:** Blockchain Server Supabase'e yazabilmek için
   - `SUPABASE_SERVICE_ROLE_KEY` kullanır
   - Bu key tüm database işlemlerini yapabilir

3. **Async Pattern:** Mobile app transaction'ı beklemek zorunda değil
   - Backend hemen response döner
   - Status'u sonra kontrol edebilir

---

## 📊 Özet Tablo

| Yön | Kaynak | Hedef | Nasıl? | Ne Zaman? |
|-----|--------|-------|--------|-----------|
| **DB → Blockchain** | `chain_actions` (PENDING) | Sepolia Transaction | Blockchain Server poll eder | Her 5 saniye |
| **Blockchain → DB** | Sepolia Event | `rentals`, `ownerships`, etc. | Blockchain Server event dinler | Sürekli (real-time) |

---

**Sonuç:** Database ve Blockchain birbirini direkt güncellemez. Blockchain Server arada köprü görevi görür! 🌉

