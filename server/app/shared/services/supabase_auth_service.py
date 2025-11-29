"""
Supabase Authentication Service

Centralized service for properly configuring Supabase client sessions
according to Supabase Python 2.9.1 official documentation.

This service ensures RLS policies work correctly by properly setting
authentication sessions on Supabase clients.
"""

import logging
from typing import Optional
from supabase import Client, create_client
from app.core.config import settings
from app.core.security.auth_enhancements import AuthSecurityService

logger = logging.getLogger(__name__)


class SupabaseAuthService:
    """
    Centralized service for Supabase client creation and authentication
    
    Single source of truth for:
    - Creating authenticated Supabase clients (with session management)
    - Getting service role clients (with connection pooling)
    - Configuring sessions for RLS
    
    According to Supabase Python 2.9.1 documentation:
    - set_session(access_token, refresh_token) sets the session
    - PostgREST should automatically use the session's access token for RLS
    - If refresh_token is not available, use access_token for both (with limitations)
    
    This service eliminates code duplication and ensures consistent client creation.
    
    Client Patterns:
    - Authenticated clients: Use create_authenticated_client() (fresh instance with session)
    - Service role clients: Use create_service_role_client() (connection pooling, no session)
    - Anon clients: Use create_anon_client() (fresh instance, no session)
    """
    
    @staticmethod
    def create_authenticated_client(
        access_token: str,
        refresh_token: Optional[str] = None
    ) -> Client:
        """
        Create an authenticated Supabase client with proper session configuration
        
        According to Supabase Python 2.9.1 docs:
        - set_session(access_token, refresh_token) properly configures the session
        - PostgREST will use the session's access token for RLS policies
        - If refresh_token is None, use access_token (works but not ideal)
        
        Args:
            access_token: JWT access token from Authorization header
            refresh_token: Optional refresh token (if available)
            
        Returns:
            Authenticated Supabase client with session set
        """
        # Create client with anon key (required for RLS)
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key  # anon key, not service role
        )
        
        # Set session according to Supabase Python 2.9.1 documentation
        # If refresh_token is not available, use access_token for both
        # This is a limitation but works for RLS (refresh won't work without real refresh token)
        refresh_token_to_use = refresh_token if refresh_token else access_token
        
        try:
            # According to Supabase Python 2.9.1 documentation:
            # - set_session(access_token, refresh_token) sets the session
            # - PostgREST client should automatically use session's access token for RLS
            # - The access token is used in Authorization header for PostgREST requests
            supabase.auth.set_session(access_token, refresh_token_to_use)
            
            # Explicitly inject JWT into PostgREST headers to ensure RLS works
            # This is a workaround for Supabase Python 2.9.1 RLS issues
            supabase = AuthSecurityService.inject_jwt_to_postgrest(supabase, access_token)
            
            # Verify session was set correctly
            # This is important for RLS to work - PostgREST needs the session
            session = supabase.auth.get_session()
            if not session:
                logger.warning(
                    "[SUPABASE_AUTH] Session was not set correctly after set_session call. "
                    "RLS may not work properly. PostgREST won't have access to auth.uid()."
                )
            else:
                # Session is set - PostgREST should now use this for RLS
                user_id = session.user.id if hasattr(session, 'user') and session.user else None
                if user_id:
                    logger.debug(
                        f"[SUPABASE_AUTH] Session set successfully. "
                        f"User ID: {user_id}. RLS should work for this user."
                    )
                else:
                    logger.warning(
                        "[SUPABASE_AUTH] Session set but user ID not found. "
                        "RLS may not work correctly."
                    )
                
        except Exception as session_error:
            logger.error(
                f"[SUPABASE_AUTH] Failed to set Supabase session: {session_error}",
                exc_info=True
            )
            # Continue anyway - explicit user_id filters will work
            # But RLS won't work without proper session
            # This is logged so we can monitor how often this happens
        
        return supabase
    
    @staticmethod
    def verify_session(client: Client) -> bool:
        """
        Verify that a Supabase client has a valid session set
        
        Args:
            client: Supabase client to verify
            
        Returns:
            True if session is valid, False otherwise
        """
        try:
            session = client.auth.get_session()
            if session and hasattr(session, 'user') and session.user:
                return True
            return False
        except Exception as e:
            logger.debug(f"Could not verify session: {e}")
            return False
    
    @staticmethod
    def get_user_id_from_session(client: Client) -> Optional[str]:
        """
        Extract user ID from Supabase client session
        
        Args:
            client: Supabase client with session
            
        Returns:
            User ID if session is valid, None otherwise
        """
        try:
            session = client.auth.get_session()
            if session and hasattr(session, 'user') and session.user:
                return session.user.id
            return None
        except Exception as e:
            logger.debug(f"Could not get user ID from session: {e}")
            return None
    
    @staticmethod
    def create_service_role_client() -> Client:
        """
        Get Supabase client with service role key (bypasses RLS)
        
        This uses the global client from database.py for connection pooling.
        Service role clients don't need sessions, so connection pooling is
        always preferred for efficiency.
        
        This is centralized to avoid code duplication. Use this instead of
        directly calling get_supabase_service_role_client() or create_client().
        
        Returns:
            Supabase client with service role privileges (from connection pool)
        """
        from app.core.database import get_supabase_service_role_client
        return get_supabase_service_role_client()
    
    @staticmethod
    def create_anon_client() -> Client:
        """
        Create a Supabase client with anon key (for RLS)
        
        This is centralized to avoid code duplication. Use this instead of
        directly calling create_client() with anon key.
        
        Returns:
            Supabase client with anon key (for RLS)
        """
        return create_client(
            settings.supabase_url,
            settings.supabase_key
        )

