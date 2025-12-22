import logging
from typing import Any, Dict, List, Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


def _parse_token_id(token_id: Any) -> Optional[int]:
    if token_id is None:
        return None
    if isinstance(token_id, int):
        return token_id
    if isinstance(token_id, str):
        try:
            s = token_id.strip()
            if s.startswith("0x") or s.startswith("0X"):
                return int(s, 16)
            return int(s)
        except Exception:
            return None
    return None


def _pick_image_url(nft: Dict[str, Any]) -> Optional[str]:
    # Alchemy returns image in multiple shapes depending on endpoint/version.
    # Prefer cachedUrl for speed, otherwise originalUrl.
    img = nft.get("image") or {}
    if isinstance(img, dict):
        return img.get("cachedUrl") or img.get("pngUrl") or img.get("thumbnailUrl") or img.get("originalUrl")
    return None


class AlchemyService:
    """
    Minimal Alchemy NFT API client.
    Docs: https://docs.alchemy.com/reference/nft-api-quickstart
    """

    def __init__(self) -> None:
        self.api_key = settings.ALCHEMY_API_KEY

    def _base_url(self) -> str:
        # Polygon mainnet NFT API base
        return f"https://polygon-mainnet.g.alchemy.com/nft/v3/{self.api_key}"

    async def get_nfts_for_owner(
        self,
        owner_address: str,
        contract_address: str,
        page_size: int = 100,
        page_key: Optional[str] = None,
        with_metadata: bool = True,
    ) -> Dict[str, Any]:
        if not self.api_key:
            raise RuntimeError("Alchemy API key is not configured (ALCHEMY_API_KEY).")

        params: Dict[str, Any] = {
            "owner": owner_address,
            "withMetadata": "true" if with_metadata else "false",
            "pageSize": str(page_size),
            "contractAddresses[]": contract_address,
        }
        if page_key:
            params["pageKey"] = page_key

        url = f"{self._base_url()}/getNFTsForOwner"

        # verify=False for dev environment SSL issues (macOS certificate problem)
        async with httpx.AsyncClient(timeout=20.0, verify=False) as client:
            r = await client.get(url, params=params)
            r.raise_for_status()
            return r.json()

    async def owner_assets_smartrent_shape(
        self,
        owner_address: str,
        contract_address: str,
        limit: int = 20,
        page_key: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Convert Alchemy response into SmartRent's current /nft/assets response shape.
        """
        data = await self.get_nfts_for_owner(
            owner_address=owner_address,
            contract_address=contract_address,
            page_size=max(1, min(limit, 100)),
            page_key=page_key,
            with_metadata=True,
        )

        owned = data.get("ownedNfts") or []
        assets: List[Dict[str, Any]] = []
        for nft in owned:
            token_id = _parse_token_id(nft.get("tokenId"))
            if token_id is None:
                continue

            balance_raw = nft.get("balance")
            try:
                balance = int(balance_raw) if balance_raw is not None else 0
            except Exception:
                balance = 0

            name = nft.get("name") or f"Asset #{token_id}"
            description = nft.get("description") or "Fractional Real Estate NFT"
            image_url = _pick_image_url(nft) or ""

            # Best-effort metadata URI
            token_uri = nft.get("tokenUri") or {}
            metadata_uri = ""
            if isinstance(token_uri, dict):
                metadata_uri = token_uri.get("raw") or token_uri.get("gateway") or ""

            assets.append(
                {
                    "token_id": token_id,
                    "name": name,
                    "description": description,
                    "image_url": image_url,
                    "balance": balance,
                    "metadata_uri": metadata_uri,
                    "contract_address": contract_address,
                    "opensea_url": f"https://opensea.io/assets/matic/{contract_address}/{token_id}",
                }
            )

        return {
            "assets": assets,
            "total": len(assets),
            "limit": limit,
            "offset": 0,
            "owner": owner_address,
            "page_key": data.get("pageKey"),
        }


alchemy_service = AlchemyService()


