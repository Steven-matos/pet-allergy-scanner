"""
Advanced Nutrition Domain Module

Combines all advanced nutrition sub-domains into a single router.
"""

from fastapi import APIRouter

from .weight.router import router as weight_router
from .trends.router import router as trends_router
from .comparisons.router import router as comparisons_router
from .analytics.router import router as analytics_router

# Create main advanced nutrition router
router = APIRouter(prefix="/advanced-nutrition", tags=["advanced-nutrition"])

# Include all sub-domain routers
router.include_router(weight_router)
router.include_router(trends_router)
router.include_router(comparisons_router)
router.include_router(analytics_router)

__all__ = ['router']
