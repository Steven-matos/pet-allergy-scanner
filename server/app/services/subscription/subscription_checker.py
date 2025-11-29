"""
Centralized subscription checker using RevenueCat as the source of truth

This service provides a single point of truth for subscription status checks,
ensuring all parts of the application use RevenueCat consistently.
"""

import logging
from typing import Optional, Dict, Any
from supabase import Client

from app.services.subscription.revenuecat_service import RevenueCatService
from app.models.core.user import UserRole

logger = logging.getLogger(__name__)


class SubscriptionChecker:
    """
    Centralized subscription checker that uses RevenueCat as the source of truth.
    
    This class ensures:
    1. RevenueCat is always checked first for subscription status
    2. Admin/protected users can bypass subscription requirements
    3. Consistent subscription checking across the entire application
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize subscription checker
        
        Args:
            supabase: Supabase client instance
        """
        self.supabase = supabase
        self.revenuecat_service = RevenueCatService(supabase)
    
    async def check_subscription_status(self, user_id: str) -> Dict[str, Any]:
        """
        Check user's subscription status using RevenueCat as source of truth
        
        This is the primary method for checking subscription status.
        It checks RevenueCat first, then falls back to database, and finally
        checks if user is a protected admin user.
        
        Args:
            user_id: User ID to check
            
        Returns:
            Dictionary with subscription status:
            {
                "has_active_subscription": bool,
                "is_premium": bool,
                "is_admin": bool,
                "source": str,  # "revenuecat", "database", "admin_protection"
                "subscription": Optional[Dict],  # Subscription details if available
                "user_role": str  # "premium" or "free"
            }
        """
        try:
            # STEP 0: Check bypass_subscription flag FIRST (highest priority)
            # This must be checked before any subscription checks to prevent downgrades
            user_response = self.supabase.table("users").select("role, bypass_subscription").eq(
                "id", user_id
            ).execute()
            
            if user_response.data:
                user_data = user_response.data[0]
                bypass_subscription = user_data.get("bypass_subscription", False)
                
                if bypass_subscription:
                    logger.info(f"🛡️ User {user_id} has bypass_subscription flag - granting premium access (bypassing all subscription checks)")
                    
                    # Ensure user role is premium in database
                    current_role = user_data.get("role", "free")
                    
                    if current_role != "premium":
                        from app.shared.services.user_role_manager import UserRoleManager
                        role_manager = UserRoleManager(self.supabase)
                        await role_manager.update_user_role(
                            user_id, 
                            UserRole.PREMIUM,
                            "Bypass subscription user - ensuring premium role"
                        )
                    
                    # Always return premium access for bypass users - skip all other checks
                    return {
                        "has_active_subscription": False,
                        "is_premium": True,
                        "is_admin": True,
                        "source": "bypass_subscription",
                        "subscription": None,
                        "user_role": "premium"
                    }
            
            # Step 1: Check RevenueCat API (source of truth)
            try:
                rc_info = await self.revenuecat_service.get_subscriber_info(user_id)
                
                if rc_info.get("has_subscription", False):
                    entitlements = rc_info.get("entitlements", {})
                    premium_entitlement = entitlements.get(
                        RevenueCatService.PREMIUM_ENTITLEMENT, {}
                    )
                    
                    if premium_entitlement.get("is_active"):
                        logger.info(f"✅ User {user_id} has active RevenueCat subscription")
                        
                        # Update database to sync with RevenueCat
                        subscriber = rc_info.get("subscriber", {})
                        product_id = self._extract_product_id(premium_entitlement, subscriber)
                        expires_date = premium_entitlement.get("expires_date")
                        
                        await self.revenuecat_service._update_subscription(
                            user_id=user_id,
                            status="active",
                            product_id=product_id or "unknown",
                            entitlement_id=RevenueCatService.PREMIUM_ENTITLEMENT,
                            expires_at=expires_date
                        )
                        
                        # Ensure user role is premium using centralized manager
                        from app.shared.services.user_role_manager import UserRoleManager
                        role_manager = UserRoleManager(self.supabase)
                        await role_manager.update_user_role(
                            user_id, 
                            UserRole.PREMIUM,
                            "RevenueCat subscription active"
                        )
                        
                        return {
                            "has_active_subscription": True,
                            "is_premium": True,
                            "is_admin": False,
                            "source": "revenuecat",
                            "subscription": {
                                "product_id": product_id,
                                "expires_date": expires_date,
                                "status": "active"
                            },
                            "user_role": "premium"
                        }
            except Exception as e:
                logger.warning(f"RevenueCat API check failed for user {user_id}: {str(e)}")
                # Continue to database check
            
            # Step 2: Check database for subscription record
            subscription_response = self.supabase.table("subscriptions").select(
                "status, product_id, expiration_date"
            ).eq("user_id", user_id).execute()
            
            if subscription_response.data:
                for sub in subscription_response.data:
                    sub_status = sub.get("status", "").lower()
                    if sub_status in ["active", "grace_period", "billing_retry"]:
                        logger.info(f"✅ User {user_id} has active subscription in database")
                        return {
                            "has_active_subscription": True,
                            "is_premium": True,
                            "is_admin": False,
                            "source": "database",
                            "subscription": sub,
                            "user_role": "premium"
                        }
            
            # Step 3: Check if user is admin (bypass subscription requirement via email)
            if await self.revenuecat_service.is_admin_user(user_id):
                logger.info(f"🛡️ User {user_id} is admin user - granting premium access without subscription")
                
                # Ensure user role is premium in database
                if user_response.data:
                    current_role = user_response.data[0].get("role", "free")
                else:
                    user_response = self.supabase.table("users").select("role").eq(
                        "id", user_id
                    ).execute()
                    current_role = user_response.data[0].get("role", "free") if user_response.data else "free"
                
                if current_role != "premium":
                    from app.shared.services.user_role_manager import UserRoleManager
                    role_manager = UserRoleManager(self.supabase)
                    await role_manager.update_user_role(
                        user_id, 
                        UserRole.PREMIUM,
                        "Bypass subscription user"
                    )
                
                return {
                    "has_active_subscription": False,
                    "is_premium": True,
                    "is_admin": True,
                    "source": "admin_protection",
                    "subscription": None,
                    "user_role": "premium"
                }
            
            # Step 4: No subscription found - user is free
            # Final safeguard: double-check for bypass users (should never reach here since checked in Step 0)
            if user_response.data:
                bypass_subscription = user_response.data[0].get("bypass_subscription", False)
                if bypass_subscription:
                    logger.warning(f"🛡️ User {user_id} has bypass_subscription but reached Step 5 - this should not happen")
                    # Ensure premium role and return premium access
                    from app.shared.services.user_role_manager import UserRoleManager
                    role_manager = UserRoleManager(self.supabase)
                    await role_manager.ensure_premium_for_bypass_user(user_id)
                    return {
                        "has_active_subscription": False,
                        "is_premium": True,
                        "is_admin": True,
                        "source": "bypass_subscription",
                        "subscription": None,
                        "user_role": "premium"
                    }
            
            logger.info(f"❌ User {user_id} has no active subscription")
            return {
                "has_active_subscription": False,
                "is_premium": False,
                "is_admin": False,
                "source": "none",
                "subscription": None,
                "user_role": "free"
            }
            
        except Exception as e:
            logger.error(f"Error checking subscription status for user {user_id}: {str(e)}", exc_info=True)
            # On error, default to free (fail secure)
            return {
                "has_active_subscription": False,
                "is_premium": False,
                "is_admin": False,
                "source": "error",
                "subscription": None,
                "user_role": "free"
            }
    
    def is_premium_user(self, user_id: str) -> bool:
        """
        Synchronous check if user has premium access (cached/quick check)
        
        This checks the database role first for quick access.
        For authoritative checks, use check_subscription_status() instead.
        
        Args:
            user_id: User ID to check
            
        Returns:
            True if user has premium access (subscription or admin)
        """
        try:
            user_response = self.supabase.table("users").select("role").eq(
                "id", user_id
            ).execute()
            
            if user_response.data:
                role = user_response.data[0].get("role", "free")
                return role == "premium"
            
            return False
        except Exception as e:
            logger.error(f"Error checking premium status for user {user_id}: {str(e)}")
            return False
    
    def _extract_product_id(
        self, 
        premium_entitlement: Dict[str, Any], 
        subscriber: Dict[str, Any]
    ) -> Optional[str]:
        """
        Extract product ID from RevenueCat entitlement or subscriber data
        
        Args:
            premium_entitlement: Premium entitlement data
            subscriber: Subscriber data
            
        Returns:
            Product ID or None
        """
        # Try entitlement first
        product_id = (
            premium_entitlement.get("product_identifier") or
            premium_entitlement.get("product_id")
        )
        
        if product_id:
            return product_id
        
        # Try subscriber subscriptions
        subscriber_subscriptions = subscriber.get("subscriptions", {})
        if subscriber_subscriptions:
            for sub_key, sub_data in subscriber_subscriptions.items():
                if isinstance(sub_data, dict):
                    product_id = sub_data.get("product_identifier") or sub_key
                    if product_id:
                        return product_id
        
        return None

