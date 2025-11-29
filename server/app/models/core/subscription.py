"""
Subscription data models and schemas
"""

from pydantic import BaseModel, ConfigDict, Field
from typing import Optional
from datetime import datetime
from enum import Enum


class SubscriptionStatus(str, Enum):
    """Subscription status enumeration"""
    ACTIVE = "active"
    EXPIRED = "expired"
    GRACE_PERIOD = "grace_period"
    BILLING_RETRY = "billing_retry"
    CANCELLED = "cancelled"
    REVOKED = "revoked"


class SubscriptionTier(str, Enum):
    """Subscription tier enumeration"""
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    YEARLY = "yearly"


class SubscriptionBase(BaseModel):
    """Base subscription model"""
    user_id: str
    product_id: str
    tier: SubscriptionTier
    status: SubscriptionStatus = SubscriptionStatus.ACTIVE
    purchase_date: datetime
    expiration_date: Optional[datetime] = None
    auto_renew: bool = True
    original_transaction_id: str
    latest_transaction_id: str


class SubscriptionCreate(SubscriptionBase):
    """Subscription creation model"""
    pass


class SubscriptionUpdate(BaseModel):
    """Subscription update model"""
    status: Optional[SubscriptionStatus] = None
    expiration_date: Optional[datetime] = None
    auto_renew: Optional[bool] = None
    latest_transaction_id: Optional[str] = None


class SubscriptionResponse(SubscriptionBase):
    """Subscription response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class AppStoreReceiptVerification(BaseModel):
    """Model for App Store receipt verification request"""
    receipt_data: str = Field(..., description="Base64 encoded receipt data")
    password: Optional[str] = Field(None, description="App-specific shared secret for auto-renewable subscriptions")
    exclude_old_transactions: bool = Field(default=False, description="Exclude old transactions")


class AppStoreServerNotification(BaseModel):
    """Model for App Store Server Notification (Version 2)"""
    notification_type: str
    subtype: Optional[str] = None
    notification_uuid: str
    data: dict
    version: str = "2.0"
    signed_date: int

