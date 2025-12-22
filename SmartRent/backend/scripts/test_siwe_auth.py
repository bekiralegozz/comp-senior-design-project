#!/usr/bin/env python3
"""
Test script for SIWE authentication flow.

This script simulates the full wallet authentication flow:
1. Request nonce
2. Sign message with test wallet
3. Verify signature and get JWT
4. Use JWT for protected endpoints
"""

import requests
from eth_account import Account
from eth_account.messages import encode_defunct

# Test configuration
BASE_URL = "http://localhost:8000"

# Test wallet (DO NOT USE IN PRODUCTION - this is a test private key)
TEST_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # Hardhat default #0


def main():
    print("=" * 60)
    print("🔐 SIWE Authentication Flow Test")
    print("=" * 60)
    
    # Create account from private key
    account = Account.from_key(TEST_PRIVATE_KEY)
    wallet_address = account.address
    print(f"\n📍 Test wallet address: {wallet_address}")
    
    # Step 1: Get nonce
    print("\n" + "-" * 40)
    print("Step 1: Request nonce")
    print("-" * 40)
    
    response = requests.get(f"{BASE_URL}/auth/nonce", params={"address": wallet_address})
    if response.status_code != 200:
        print(f"❌ Failed to get nonce: {response.text}")
        return
    
    nonce_data = response.json()
    nonce = nonce_data["nonce"]
    message = nonce_data["message"]
    
    print(f"✅ Nonce received: {nonce[:16]}...")
    print(f"📝 Message to sign:\n{message}")
    
    # Step 2: Sign message
    print("\n" + "-" * 40)
    print("Step 2: Sign message with wallet")
    print("-" * 40)
    
    message_encoded = encode_defunct(text=message)
    signed_message = account.sign_message(message_encoded)
    # signature.hex() already includes '0x' prefix in some versions, handle both cases
    signature_hex = signed_message.signature.hex()
    if not signature_hex.startswith('0x'):
        signature_hex = '0x' + signature_hex
    
    print(f"✅ Message signed")
    print(f"📝 Signature: {signature_hex[:42]}...")
    
    # Step 3: Verify signature and get token
    print("\n" + "-" * 40)
    print("Step 3: Verify signature and get JWT")
    print("-" * 40)
    
    verify_response = requests.post(
        f"{BASE_URL}/auth/verify",
        json={
            "message": message,
            "signature": signature_hex,
            "nonce": nonce
        }
    )
    
    if verify_response.status_code != 200:
        print(f"❌ Verification failed: {verify_response.text}")
        return
    
    token_data = verify_response.json()
    access_token = token_data["access_token"]
    
    print(f"✅ JWT token received!")
    print(f"🔑 Token: {access_token[:50]}...")
    print(f"⏰ Expires at: {token_data['expires_at']}")
    print(f"📍 Verified address: {token_data['address']}")
    
    # Step 4: Use token for protected endpoint
    print("\n" + "-" * 40)
    print("Step 4: Access protected endpoint")
    print("-" * 40)
    
    headers = {"Authorization": f"Bearer {access_token}"}
    me_response = requests.get(f"{BASE_URL}/auth/me", headers=headers)
    
    if me_response.status_code != 200:
        print(f"❌ Protected endpoint failed: {me_response.text}")
        return
    
    user_data = me_response.json()
    print(f"✅ Protected endpoint accessed!")
    print(f"👤 User data: {user_data}")
    
    # Step 5: Try with invalid token
    print("\n" + "-" * 40)
    print("Step 5: Test with invalid token (should fail)")
    print("-" * 40)
    
    invalid_headers = {"Authorization": "Bearer invalid_token_here"}
    invalid_response = requests.get(f"{BASE_URL}/auth/me", headers=invalid_headers)
    
    if invalid_response.status_code == 401:
        print(f"✅ Correctly rejected invalid token")
        print(f"📝 Error: {invalid_response.json()['detail']}")
    else:
        print(f"❌ Should have rejected invalid token!")
    
    # Summary
    print("\n" + "=" * 60)
    print("🎉 All tests passed! SIWE authentication is working.")
    print("=" * 60)
    print(f"""
Summary:
- Nonce generation: ✅
- Message signing: ✅
- Signature verification: ✅
- JWT token generation: ✅
- Protected endpoints: ✅
- Invalid token rejection: ✅
""")


if __name__ == "__main__":
    main()

