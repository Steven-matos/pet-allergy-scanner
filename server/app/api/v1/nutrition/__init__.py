"""
Nutrition Domain Module

Combines all nutrition sub-domains into a single router.
"""

from fastapi import APIRouter

from .requirements.router import router as requirements_router
from .analysis.router import router as analysis_router
from .feeding.router import router as feeding_router
from .goals.router import router as goals_router
from .summaries.router import router as summaries_router
from .advanced.router import router as advanced_router

# Create main nutrition router
router = APIRouter(prefix="/nutrition", tags=["nutrition"])

# Include all sub-domain routers
router.include_router(requirements_router)
router.include_router(analysis_router)
router.include_router(feeding_router)
router.include_router(goals_router)
router.include_router(summaries_router)
router.include_router(advanced_router)

__all__ = ['router']
