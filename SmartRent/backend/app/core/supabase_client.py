"""
Supabase client factory utilities.
"""

from functools import lru_cache
from typing import Literal

from supabase import Client, create_client

from app.core.config import settings


class SupabaseConfigurationError(RuntimeError):
    """Raised when Supabase configuration is missing or invalid."""


@lru_cache
def _build_supabase_client(scope: Literal["service", "anon"] = "service") -> Client:
    """Create and memoize a Supabase client instance for the requested scope."""
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
    """Return a cached Supabase client for the requested scope."""
    scope: Literal["service", "anon"] = "service" if use_service_role else "anon"
    return _build_supabase_client(scope)

