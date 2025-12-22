/**
 * Blockchain Server Configuration Template
 * 
 * Bu dosyayı kopyalayıp config.js olarak kaydedin ve değerleri doldurun
 * config.js dosyasını .gitignore'a ekleyin (güvenlik için)
 */

module.exports = {
  // Sepolia RPC Configuration
  sepolia: {
    rpcUrl: process.env.SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/e7KBw7Uhu7r1meEBJRPyZ',
    chainId: 11155111,
  },

  // Contract Addresses (Deploy sonrası doldurulacak)
  contracts: {
    building1122: process.env.BUILDING1122_ADDRESS || '0xeFbfFC198FfA373C26E64a426E8866B132d08ACB',
    rentalManager: process.env.RENTAL_MANAGER_ADDRESS || '0x57044386A0C5Fb623315Dd5b8eeEA6078Bb9193C',
    marketplace: process.env.MARKETPLACE_ADDRESS || '0x2fFCd104D50c99D24d76Acfc3Ef1dfb550127A1f',
  },

  // Blockchain Server Wallet (Hot Wallet)
  // ÖNEMLİ: Private key veya mnemonic phrase'i asla commit etmeyin!
  // İKİSİNDEN BİRİNİ KULLANIN (ikisini birden değil):
  // 1. privateKey: Daha kısa, direkt kullanım için
  // 2. mnemonic: 12 kelimelik seed phrase (daha güvenli, ama daha uzun)
  // 
  // Wallet Address: 0xA62de937ba75374408Ca6D06dfB66097CcC4526D (Sepolia ETH yüklü ✅)
  wallet: {
    // Seçenek 1: Private key kullan (önerilen - daha kısa)
    privateKey: process.env.SERVER_PRIVATE_KEY || '',
    
    // Seçenek 2: Mnemonic phrase kullan (12 kelime)
    // Trust Wallet'dan aldığınız 12 kelimeyi .env dosyasına ekleyin
    // Örnek: "word1 word2 word3 ... word12"
    // ÖNEMLİ: Mnemonic phrase'i ASLA bu dosyaya yazmayın! Sadece .env dosyasında saklayın!
    mnemonic: process.env.SERVER_MNEMONIC || '',
  },

  // Supabase Configuration
  // Backend'den alındı (SmartRent/backend/.env)
  supabase: {
    url: process.env.SUPABASE_URL || 'https://oajhrwleyhpeelbrdqdd.supabase.co',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hamhyd2xleWhwZWVsYnJkcWRkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MTc1NjM4MCwiZXhwIjoyMDc3MzMyMzgwfQ.E-L9olrQsFS3pzxu2VuPAqrtamezFk8GQBs1bsgiX-M',
  },

  // Payment Token
  // NOTE: Artık sadece ETH (native currency) kullanılıyor, USDT desteği kaldırıldı
  paymentToken: {
    address: '0x0000000000000000000000000000000000000000', // ETH için zero address
  },

  // Treasury and Fee Recipient
  // NOTE: Treasury artık kullanılmıyor (RentalManager'da kaldırıldı)
  // Rent direkt pay sahiplerine dağıtılıyor
  addresses: {
    feeRecipient: process.env.FEE_RECIPIENT_ADDRESS || '', // Marketplace için gerekli
  },

  // Polling Configuration
  polling: {
    interval: 5000, // 5 seconds - chain_actions tablosunu kontrol etme sıklığı
  },
};

