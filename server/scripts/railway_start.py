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
from pathlib import Path

# Add parent directory to Python path so we can import the app module
# This is necessary because the script is now in scripts/ subdirectory
script_dir = Path(__file__).resolve().parent
server_dir = script_dir.parent
sys.path.insert(0, str(server_dir))

# Configure basic logging first - write to stdout instead of stderr
# so Railway doesn't interpret INFO logs as errors
# Respect LOG_LEVEL environment variable if set
log_level_str = os.getenv("LOG_LEVEL", "INFO").upper()
log_level = getattr(logging, log_level_str, logging.INFO)

logging.basicConfig(
    level=log_level,
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
    # Force output immediately to ensure logs appear
    print("=" * 60, flush=True)
    print("🚀 Starting SniffTest API on Railway", flush=True)
    print("=" * 60, flush=True)
    
    try:
        logger.info("=" * 60)
        logger.info("🚀 Starting SniffTest API on Railway")
        logger.info("=" * 60)
        
        # Get PORT from Railway (defaults to 8000 for local testing)
        port = int(os.getenv("PORT", "8000"))
        logger.info(f"📡 Port: {port}")
        print(f"📡 Port: {port}", flush=True)
        
        # Get environment
        environment = os.getenv("ENVIRONMENT", "production")
        logger.info(f"🌍 Environment: {environment}")
        print(f"🌍 Environment: {environment}", flush=True)
        
        # Validate environment variables
        logger.info("🔍 Validating configuration...")
        if not validate_environment():
            logger.error("❌ Configuration validation failed")
            logger.error("   Application cannot start without required environment variables")
            sys.exit(1)
        
        # Log installed package versions for debugging
        logger.info("📦 Checking installed package versions...")
        try:
            import supabase
            import postgrest
            import httpx
            import storage3
            import supafunc
            logger.info(f"   supabase: {supabase.__version__}")
            logger.info(f"   postgrest: {postgrest.__version__}")
            logger.info(f"   httpx: {httpx.__version__}")
            logger.info(f"   storage3: {storage3.__version__}")
            logger.info(f"   supafunc: {supafunc.__version__}")
        except Exception as e:
            logger.warning(f"   Could not check versions: {e}")
        
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
        
        # Change to server directory so uvicorn can find main.py
        logger.info(f"📂 Changing to server directory: {server_dir}")
        os.chdir(server_dir)
        
        # Test if we can import main:app before starting uvicorn
        logger.info("🔍 Testing if main:app can be imported...")
        print("🔍 Testing if main:app can be imported...", flush=True)
        try:
            import sys
            sys.path.insert(0, server_dir)
            from main import app
            logger.info("✅ Successfully imported main:app")
            print("✅ Successfully imported main:app", flush=True)
        except ImportError as e:
            error_msg = f"❌ Failed to import main:app: {e}"
            logger.error(error_msg)
            print(error_msg, flush=True)
            import traceback
            tb = traceback.format_exc()
            logger.error(tb)
            print(tb, flush=True)
            sys.exit(1)
        except Exception as e:
            error_msg = f"❌ Error importing main:app: {e}"
            logger.error(error_msg)
            print(error_msg, flush=True)
            import traceback
            tb = traceback.format_exc()
            logger.error(tb)
            print(tb, flush=True)
            sys.exit(1)
        
        # Start the server
        logger.info(f"🎬 Starting uvicorn server on 0.0.0.0:{port}")
        logger.info("=" * 60)
        
        # Determine if we should enable verbose logging
        is_production = environment == "production"
        
        # Get log level from environment variable, with fallback based on environment
        uvicorn_log_level = os.getenv("LOG_LEVEL", "error" if is_production else "info").lower()
        
        # Production: Minimal logging to avoid Railway 500 logs/sec limit
        # Development: Full logging for debugging
        if is_production:
            logger.info("⚠️  Production mode: Access logs DISABLED to avoid Railway rate limits")
            logger.info("   Only errors will be logged. Use external monitoring for metrics.")
        
        logger.info(f"📊 Log level: {uvicorn_log_level.upper()} (from LOG_LEVEL env var)")
        
        uvicorn.run(
            "main:app",
            host="0.0.0.0",
            port=port,
            log_level=uvicorn_log_level,
            access_log=not is_production,  # Disable access logs in production
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
                    "uvicorn": {
                        "handlers": ["default"], 
                        "level": uvicorn_log_level.upper()
                    },
                    "uvicorn.error": {
                        "handlers": ["default"], 
                        "level": uvicorn_log_level.upper()
                    },
                    "uvicorn.access": {
                        "handlers": ["default"], 
                        "level": "CRITICAL" if is_production else uvicorn_log_level.upper()  # Completely disable in prod
                    },
                },
            }
        )
        
    except KeyboardInterrupt:
        logger.info("\n👋 Shutting down gracefully...")
        print("\n👋 Shutting down gracefully...", flush=True)
        sys.exit(0)
    except Exception as e:
        error_msg = f"❌ FATAL ERROR: Application failed to start\n   Error: {e}\n   Type: {type(e).__name__}"
        logger.error("=" * 60)
        logger.error(error_msg)
        logger.error("=" * 60)
        print("=" * 60, flush=True)
        print(error_msg, flush=True)
        print("=" * 60, flush=True)
        import traceback
        tb = traceback.format_exc()
        logger.error(tb)
        print(tb, flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()

