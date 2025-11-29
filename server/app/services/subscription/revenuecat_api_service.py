"""
RevenueCat API Service

Handles direct API calls to RevenueCat for querying subscription status.
Extracted from revenuecat_service.py for better single responsibility.

Documentation: https://www.revenuecat.com/docs/api-v1
"""

import httpx
from typing import Dict, Any
from fastapi import HTTPException, status
from supabase import Client
import logging

from app.core.config import settings

logger = logging.getLogger(__name__)


class RevenueCatAPIService:
    """
    Service for querying RevenueCat REST API
    
    Responsibilities:
    - Query subscriber information from RevenueCat API
    - Get real-time subscription status
    - Handle API authentication and errors
    """
    
    # RevenueCat API base URL
    API_BASE_URL = "https://api.revenuecat.com/v1"
    
    # Entitlement identifier from RevenueCat dashboard
    PREMIUM_ENTITLEMENT = "pro_user"
    
    def __init__(self, supabase: Client):
        """
        Initialize RevenueCat API service
        
        Args:
            supabase: Authenticated Supabase client (for RLS compliance)
        """
        self.supabase = supabase
        self.api_key = settings.revenuecat_api_key
    
    async def get_subscriber_info(self, user_id: str) -> Dict[str, Any]:
        """
        Get subscriber information from RevenueCat API
        
        This queries RevenueCat's REST API for real-time subscription status.
        Note: Webhooks are preferred for updating subscription status.
        
        Args:
            user_id: App user ID
            
        Returns:
            Subscriber information
            
        Raises:
            HTTPException: If API key not configured or API request fails
        """
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="RevenueCat API key not configured"
            )
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.API_BASE_URL}/subscribers/{user_id}",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    timeout=10.0
                )
                
                if response.status_code == 404:
                    return {"has_subscription": False}
                
                response.raise_for_status()
                data = response.json()
                
                # Extract subscription information
                subscriber = data.get("subscriber", {})
                entitlements = subscriber.get("entitlements", {})
                
                has_premium = (
                    self.PREMIUM_ENTITLEMENT in entitlements and
                    entitlements[self.PREMIUM_ENTITLEMENT].get("expires_date") is not None
                )
                
                return {
                    "has_subscription": has_premium,
                    "entitlements": entitlements,
                    "subscriber": subscriber
                }
        
        except httpx.HTTPError as e:
            logger.error(f"HTTP error querying RevenueCat API: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to fetch subscription information"
            )
        except Exception as e:
            logger.error(f"Error fetching subscriber info: {str(e)}")
            raise

