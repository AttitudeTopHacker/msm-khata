from supabase import create_client, Client
from app.config import settings

_supabase_client: Client | None = None

def get_supabase() -> Client:
    """Returns a singleton instance of the Supabase Client."""
    global _supabase_client
    if _supabase_client is None:
        if not settings.SUPABASE_URL or not settings.SUPABASE_KEY:
            raise RuntimeError(
                "SUPABASE_URL and SUPABASE_KEY must be configured in your .env file."
            )
        _supabase_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    return _supabase_client
