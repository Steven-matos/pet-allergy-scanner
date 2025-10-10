"""
Startup script for SniffTest Backend
Optimized for minimal logging in production to avoid Railway rate limits
"""

import uvicorn
import os
from app.core.config import settings

if __name__ == "__main__":
    # Get environment from settings or default to development
    environment = getattr(settings, 'environment', 'development')
    is_production = environment == "production"
    
    # Production: Disable access logs to reduce Railway log volume
    # Development: Enable access logs for debugging
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=environment == "development",
        log_level="error" if is_production else "info",
        access_log=not is_production,  # Disable access logs in production
    )
