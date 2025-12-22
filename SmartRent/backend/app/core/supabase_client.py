"""
DEPRECATED: Supabase client factory utilities.

MIGRATION NOTE (Dec 2025):
- Supabase has been removed from the architecture
- Backend now uses blockchain as source of truth
- This file is kept as a stub to prevent import errors during migration
- All functions raise NotImplementedError

TODO: Remove this file completely after all dependent code is updated
"""

from typing import Literal, Any


class SupabaseConfigurationError(RuntimeError):
    """Raised when Supabase configuration is missing or invalid."""
    pass


class SupabaseDeprecatedError(RuntimeError):
    """Raised when deprecated Supabase functions are called."""
    pass


def get_supabase_client(use_service_role: bool = True) -> Any:
    """
    DEPRECATED: Supabase client is no longer available.
    
    Raises:
        SupabaseDeprecatedError: Always, as Supabase has been removed
    """
    raise SupabaseDeprecatedError(
        "Supabase has been removed from SmartRent. "
        "The application now uses blockchain as the source of truth. "
        "Please update your code to use blockchain services instead."
    )


def _build_supabase_client(scope: Literal["service", "anon"] = "service") -> Any:
    """DEPRECATED: See get_supabase_client()"""
    raise SupabaseDeprecatedError(
        "Supabase has been removed. Use blockchain services instead."
    )
