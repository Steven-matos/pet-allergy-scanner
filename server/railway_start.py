#!/usr/bin/env python3
"""
Railway-specific startup script with better error handling and diagnostics

This script ensures the app starts correctly on Railway by:
1. Validating environment variables before startup
2. Using Railway's PORT environment variable
3. Providing detailed error logging
4. Handling startup failures gracefully
"""

import os
import sys
import logging

# Configure basic logging first - write to stdout instead of stderr
# so Railway doesn't interpret INFO logs as errors
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout  # Railway interprets stderr as error-level, so use stdout
)
logger = logging.getLogger(__name__)

def validate_environment():
    """
    Validate required environment variables are present
    
    Returns:
        bool: True if all required vars present, False otherwise
    """
    required_vars = [
        "SUPABASE_URL",
        "SUPABASE_KEY",
        "SUPABASE_SERVICE_ROLE_KEY",
        "SUPABASE_JWT_SECRET",
        "SECRET_KEY",
        "DATABASE_URL",
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        logger.error("=" * 60)
        logger.error("RAILWAY STARTUP ERROR: Missing Required Environment Variables")
        logger.error("=" * 60)
        for var in missing_vars:
            logger.error(f"  ❌ {var}")
        logger.error("")
        logger.error("Set these in Railway Dashboard:")
        logger.error("  Project → Settings → Variables")
        logger.error("=" * 60)
        return False
    
    # Validate SECRET_KEY length
    secret_key = os.getenv("SECRET_KEY", "")
    if len(secret_key) < 32:
        logger.error("=" * 60)
        logger.error("RAILWAY STARTUP ERROR: SECRET_KEY too short")
        logger.error(f"  Current length: {len(secret_key)} characters")
        logger.error(f"  Required: 32+ characters")
        logger.error("")
        logger.error("Generate a secure key:")
        logger.error("  python3 test_config.py --generate-key")
        logger.error("=" * 60)
        return False
    
    logger.info("✅ All required environment variables present")
    return True

def main():
    """Main startup function with error handling"""
    try:
        logger.info("=" * 60)
        logger.info("🚀 Starting SniffTest API on Railway")
        logger.info("=" * 60)
        
        # Get PORT from Railway (defaults to 8000 for local testing)
        port = int(os.getenv("PORT", "8000"))
        logger.info(f"📡 Port: {port}")
        
        # Get environment
        environment = os.getenv("ENVIRONMENT", "production")
        logger.info(f"🌍 Environment: {environment}")
        
        # Validate environment variables
        logger.info("🔍 Validating configuration...")
        if not validate_environment():
            logger.error("❌ Configuration validation failed")
            logger.error("   Application cannot start without required environment variables")
            sys.exit(1)
        
        # Try to load settings to catch any Pydantic validation errors
        logger.info("⚙️  Loading application settings...")
        try:
            from app.core.config import settings
            logger.info(f"✅ Settings loaded successfully")
            logger.info(f"   API Version: {settings.api_version}")
            logger.info(f"   Debug: {settings.debug}")
        except Exception as e:
            logger.error(f"❌ Failed to load settings: {e}")
            logger.error("   Check your environment variables for typos or invalid values")
            sys.exit(1)
        
        # Import uvicorn
        logger.info("📦 Loading uvicorn...")
        try:
            import uvicorn
        except ImportError as e:
            logger.error(f"❌ Failed to import uvicorn: {e}")
            logger.error("   This should not happen on Railway")
            sys.exit(1)
        
        # Start the server
        logger.info(f"🎬 Starting uvicorn server on 0.0.0.0:{port}")
        logger.info("=" * 60)
        
        uvicorn.run(
            "main:app",
            host="0.0.0.0",
            port=port,
            log_level="info",
            access_log=True,
            # Don't use reload in production
            reload=False,
            # Configure uvicorn to use proper logging
            log_config={
                "version": 1,
                "disable_existing_loggers": False,
                "formatters": {
                    "default": {
                        "format": "%(levelname)s: %(message)s",
                    },
                },
                "handlers": {
                    "default": {
                        "formatter": "default",
                        "class": "logging.StreamHandler",
                        "stream": "ext://sys.stdout",  # Use stdout instead of stderr
                    },
                },
                "loggers": {
                    "uvicorn": {"handlers": ["default"], "level": "INFO"},
                    "uvicorn.error": {"handlers": ["default"], "level": "INFO"},
                    "uvicorn.access": {"handlers": ["default"], "level": "INFO"},
                },
            }
        )
        
    except KeyboardInterrupt:
        logger.info("\n👋 Shutting down gracefully...")
        sys.exit(0)
    except Exception as e:
        logger.error("=" * 60)
        logger.error(f"❌ FATAL ERROR: Application failed to start")
        logger.error(f"   Error: {e}")
        logger.error(f"   Type: {type(e).__name__}")
        logger.error("=" * 60)
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    main()

