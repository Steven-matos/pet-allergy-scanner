"""
Monitoring and health check router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from typing import Dict, Any
from app.services.monitoring import MonitoringService
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/health")
async def health_check():
    """
    Health check endpoint
    
    Returns system health status
    """
    try:
        monitoring_service = MonitoringService()
        health_status = monitoring_service.check_health()
        
        # Return appropriate status code
        if health_status["status"] == "healthy":
            return health_status
        elif health_status["status"] == "degraded":
            return health_status
        else:
            return health_status
            
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Health check failed"
        )

@router.get("/metrics")
async def get_metrics(hours: int = 24):
    """
    Get system metrics
    
    Args:
        hours: Number of hours to look back (default: 24)
        
    Returns:
        Metrics summary
    """
    try:
        if hours < 1 or hours > 168:  # Max 1 week
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Hours must be between 1 and 168"
            )
        
        monitoring_service = MonitoringService()
        metrics = monitoring_service.get_metrics_summary(hours)
        
        return metrics
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get metrics: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get metrics"
        )

@router.get("/status")
async def get_status():
    """
    Get system status
    
    Returns:
        System status information
    """
    try:
        from app.core.config import settings
        
        status_info = {
            "environment": settings.environment,
            "api_version": settings.api_version,
            "features": {
                "mfa_enabled": settings.enable_mfa,
                "audit_logging": settings.enable_audit_logging,
                "data_export": settings.enable_data_export,
                "data_deletion": settings.enable_data_deletion
            },
            "limits": {
                "rate_limit_per_minute": settings.rate_limit_per_minute,
                "auth_rate_limit_per_minute": settings.auth_rate_limit_per_minute,
                "max_file_size_mb": settings.max_file_size_mb,
                "max_request_size_mb": settings.max_request_size_mb
            },
            "security": {
                "cors_origins": len(settings.allowed_origins),
                "trusted_hosts": len(settings.allowed_hosts),
                "session_timeout_minutes": settings.session_timeout_minutes
            }
        }
        
        return status_info
        
    except Exception as e:
        logger.error(f"Failed to get status: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get status"
        )
