"""
IPFS Service using Pinata API
Handles NFT metadata and image uploads to IPFS
"""

import requests
import json
import logging
from typing import Dict, Optional, List
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger(__name__)


class IPFSService:
    """Service for uploading NFT metadata and images to IPFS via Pinata"""
    
    BASE_URL = "https://api.pinata.cloud"
    GATEWAY_URL = "https://gateway.pinata.cloud/ipfs"
    
    def __init__(self):
        self.api_key = getattr(settings, 'PINATA_API_KEY', None)
        self.secret_key = getattr(settings, 'PINATA_SECRET_KEY', None)
        self._last_image_url = None  # Track last uploaded image URL
        
        if not self.api_key or not self.secret_key:
            logger.warning("Pinata credentials not configured - IPFS uploads disabled")
    
    def _get_headers(self, content_type: str = "application/json") -> Dict:
        """Get request headers with Pinata authentication"""
        return {
            "pinata_api_key": self.api_key,
            "pinata_secret_api_key": self.secret_key,
            "Content-Type": content_type
        }
    
    def test_authentication(self) -> bool:
        """Test Pinata API authentication"""
        try:
            response = requests.get(
                f"{self.BASE_URL}/data/testAuthentication",
                headers={
                    "pinata_api_key": self.api_key,
                    "pinata_secret_api_key": self.secret_key
                }
            )
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Pinata auth test failed: {str(e)}")
            return False
    
    def get_last_uploaded_image_url(self) -> Optional[str]:
        """Get the gateway URL of the last uploaded image"""
        return self._last_image_url
    
    def upload_json_metadata(
        self,
        name: str,
        description: str,
        image_uri: str,
        attributes: List[Dict] = None,
        external_url: str = None,
        properties: Dict = None
    ) -> Optional[str]:
        """
        Upload NFT metadata JSON to IPFS
        
        Args:
            name: Asset name
            description: Asset description
            image_uri: IPFS URI of the image
            attributes: OpenSea attributes array
            external_url: Link to asset page
            properties: Additional custom properties
        
        Returns:
            IPFS URI (ipfs://...) or None on failure
        """
        try:
            if not self.api_key:
                logger.error("Pinata not configured")
                return None
            
            # Construct OpenSea-compatible metadata
            metadata = {
                "name": name,
                "description": description,
                "image": image_uri,
            }
            
            if external_url:
                metadata["external_url"] = external_url
            
            if attributes:
                metadata["attributes"] = attributes
            
            if properties:
                metadata["properties"] = properties
            
            # Upload to Pinata
            response = requests.post(
                f"{self.BASE_URL}/pinning/pinJSONToIPFS",
                headers=self._get_headers(),
                json={
                    "pinataContent": metadata,
                    "pinataMetadata": {
                        "name": f"{name}_metadata.json"
                    }
                }
            )
            
            if response.status_code == 200:
                ipfs_hash = response.json()["IpfsHash"]
                ipfs_uri = f"ipfs://{ipfs_hash}"
                logger.info(f"Metadata uploaded to IPFS: {ipfs_uri}")
                return ipfs_uri
            else:
                logger.error(f"Pinata upload failed: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Error uploading metadata to IPFS: {str(e)}")
            return None
    
    def upload_image_from_url(self, image_url: str, filename: str) -> Optional[str]:
        """
        Download image from URL and upload to IPFS
        
        Args:
            image_url: URL of the image to upload
            filename: Filename for the image
        
        Returns:
            IPFS URI (ipfs://...) or None on failure
        """
        try:
            if not self.api_key:
                logger.error("Pinata not configured")
                return None
            
            # Download image
            image_response = requests.get(image_url, timeout=30)
            if image_response.status_code != 200:
                logger.error(f"Failed to download image from {image_url}")
                return None
            
            # Upload to Pinata
            files = {
                'file': (filename, image_response.content)
            }
            
            headers = {
                "pinata_api_key": self.api_key,
                "pinata_secret_api_key": self.secret_key
            }
            
            response = requests.post(
                f"{self.BASE_URL}/pinning/pinFileToIPFS",
                headers=headers,
                files=files
            )
            
            if response.status_code == 200:
                ipfs_hash = response.json()["IpfsHash"]
                ipfs_uri = f"ipfs://{ipfs_hash}"
                self._last_image_url = f"{self.GATEWAY_URL}/{ipfs_hash}"  # Track gateway URL
                logger.info(f"Image uploaded to IPFS: {ipfs_uri}")
                return ipfs_uri
            else:
                logger.error(f"Image upload failed: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Error uploading image: {str(e)}")
            return None
    
    def upload_image_from_file(self, file_path: str) -> Optional[str]:
        """
        Upload image file to IPFS
        
        Args:
            file_path: Path to the image file
        
        Returns:
            IPFS URI (ipfs://...) or None on failure
        """
        try:
            if not self.api_key:
                logger.error("Pinata not configured")
                return None
            
            path = Path(file_path)
            if not path.exists():
                logger.error(f"File not found: {file_path}")
                return None
            
            with open(file_path, 'rb') as file:
                files = {'file': (path.name, file)}
                
                headers = {
                    "pinata_api_key": self.api_key,
                    "pinata_secret_api_key": self.secret_key
                }
                
                response = requests.post(
                    f"{self.BASE_URL}/pinning/pinFileToIPFS",
                    headers=headers,
                    files=files
                )
            
            if response.status_code == 200:
                ipfs_hash = response.json()["IpfsHash"]
                ipfs_uri = f"ipfs://{ipfs_hash}"
                logger.info(f"File uploaded to IPFS: {ipfs_uri}")
                return ipfs_uri
            else:
                logger.error(f"File upload failed: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Error uploading file: {str(e)}")
            return None
    
    def create_asset_metadata(
        self,
        asset_name: str,
        description: str,
        image_url: str,
        property_type: str = "Apartment",
        bedrooms: int = None,
        location: str = None,
        total_shares: int = 1000,
        square_feet: int = None,
        address: str = None,
    ) -> Optional[str]:
        """
        Create and upload complete asset metadata to IPFS
        
        Returns:
            IPFS URI of the metadata JSON
        """
        try:
            # First upload image
            logger.info(f"Uploading image for {asset_name}...")
            image_uri = self.upload_image_from_url(image_url, f"{asset_name}.jpg")
            
            if not image_uri:
                logger.error("Failed to upload image")
                return None
            
            # Prepare attributes for OpenSea
            attributes = [
                {"trait_type": "Property Type", "value": property_type},
                {"trait_type": "Total Shares", "value": total_shares}
            ]
            
            if bedrooms:
                attributes.append({"trait_type": "Bedrooms", "value": str(bedrooms)})
            
            if location:
                attributes.append({"trait_type": "Location", "value": location})
            
            if square_feet:
                attributes.append({"trait_type": "Square Feet", "value": str(square_feet)})
            
            # Properties
            properties = {}
            if address:
                properties["address"] = address
            
            # Upload metadata
            logger.info(f"Uploading metadata for {asset_name}...")
            metadata_uri = self.upload_json_metadata(
                name=asset_name,
                description=description,
                image_uri=image_uri,
                attributes=attributes,
                external_url=f"https://smartrent.com/assets/{asset_name.lower().replace(' ', '-')}",
                properties=properties if properties else None
            )
            
            return metadata_uri
            
        except Exception as e:
            logger.error(f"Error creating asset metadata: {str(e)}")
            return None
    
    def get_ipfs_gateway_url(self, ipfs_uri: str) -> str:
        """Convert ipfs:// URI to HTTP gateway URL"""
        if ipfs_uri.startswith("ipfs://"):
            ipfs_hash = ipfs_uri.replace("ipfs://", "")
            return f"{self.GATEWAY_URL}/{ipfs_hash}"
        return ipfs_uri
    
    def unpin(self, ipfs_hash: str) -> bool:
        """Unpin content from Pinata (free up storage)"""
        try:
            if not self.api_key:
                return False
            
            response = requests.delete(
                f"{self.BASE_URL}/pinning/unpin/{ipfs_hash}",
                headers={
                    "pinata_api_key": self.api_key,
                    "pinata_secret_api_key": self.secret_key
                }
            )
            
            return response.status_code == 200
            
        except Exception as e:
            logger.error(f"Error unpinning: {str(e)}")
            return False


# Singleton instance
ipfs_service = IPFSService()
