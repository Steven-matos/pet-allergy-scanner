"""
Startup script for SniffTest Backend
"""

import uvicorn
import os
from app.core.config import settings

if __name__ == "__main__":
    # Get environment from settings or default to development
    environment = getattr(settings, 'environment', 'development')
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=environment == "development",
        log_level="info"
    )
