"""
Core Models Module

Foundational models: User, Pet, Subscription, Waitlist
"""

from .user import (
    User,
    UserRole,
    UserBase,
    UserCreate,
    UserUpdate,
    UserResponse,
    UserInDB,
    UserLogin,
)

from .pet import (
    PetSpecies,
    PetActivityLevel,
    PetLifeStage,
    PetBreed,
    PetBase,
    PetCreate,
    PetUpdate,
    PetResponse,
)

from .subscription import (
    SubscriptionStatus,
    SubscriptionTier,
    SubscriptionBase,
    SubscriptionCreate,
    SubscriptionUpdate,
    SubscriptionResponse,
)

from .waitlist import (
    WaitlistSignup,
    WaitlistResponse,
)

__all__ = [
    # User models
    'User',
    'UserRole',
    'UserBase',
    'UserCreate',
    'UserUpdate',
    'UserResponse',
    'UserInDB',
    'UserLogin',
    # Pet models
    'PetSpecies',
    'PetActivityLevel',
    'PetLifeStage',
    'PetBreed',
    'PetBase',
    'PetCreate',
    'PetUpdate',
    'PetResponse',
    # Subscription models
    'SubscriptionStatus',
    'SubscriptionTier',
    'SubscriptionBase',
    'SubscriptionCreate',
    'SubscriptionUpdate',
    'SubscriptionResponse',
    # Waitlist models
    'WaitlistSignup',
    'WaitlistResponse',
]

