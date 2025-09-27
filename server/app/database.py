"""
Database configuration and initialization
"""

from supabase import create_client, Client
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Initialize Supabase client
supabase: Client = create_client(settings.supabase_url, settings.supabase_key)

async def init_db():
    """
    Initialize database connection and verify connectivity
    """
    try:
        # Test Supabase connection
        response = supabase.table("users").select("id").limit(1).execute()
        logger.info("Database connection established successfully")
        return True
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise e

def get_supabase_client() -> Client:
    """
    Get Supabase client instance
    """
    return supabase
