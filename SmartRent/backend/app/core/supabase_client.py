"""
Supabase client factory utilities.
"""

from typing import Literal
from supabase import Client, create_client
from app.core.config import settings


class SupabaseConfigurationError(RuntimeError):
    """Raised when Supabase configuration is missing or invalid."""


# Global clients
_service_client: Client = None
_anon_client: Client = None


def _build_supabase_client(scope: Literal["service", "anon"] = "service") -> Client:
    """Create a Supabase client instance for the requested scope."""
    url = settings.SUPABASE_URL
    if not url:
        raise SupabaseConfigurationError("SUPABASE_URL is not configured")

    if scope == "service":
        key = settings.SUPABASE_SERVICE_ROLE_KEY
    else:
        key = settings.SUPABASE_ANON_KEY

    if not key:
        raise SupabaseConfigurationError(
            f"{'SUPABASE_SERVICE_ROLE_KEY' if scope == 'service' else 'SUPABASE_ANON_KEY'} is not configured"
        )

    return create_client(url, key)


def get_supabase_client(use_service_role: bool = True) -> Client:
    """Return a Supabase client for the requested scope."""
    global _service_client, _anon_client
    
    if use_service_role:
        if _service_client is None:
            _service_client = _build_supabase_client("service")
        return _service_client
    else:
        if _anon_client is None:
            _anon_client = _build_supabase_client("anon")
        return _anon_client

