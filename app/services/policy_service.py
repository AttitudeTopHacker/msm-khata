from typing import Dict, Any, Optional
from app.database import get_supabase
import logging

logger = logging.getLogger(__name__)

DEFAULT_SETTINGS = {
    "allow_entry_update": True,
    "allow_entry_delete": True,
    "allow_date_edit": True,
}

class PolicyService:
    @staticmethod
    def get_all_settings() -> Dict[str, Any]:
        """Fetches all system policy settings."""
        client = get_supabase()
        try:
            res = client.table("system_settings").select("key, value").execute()
            settings = dict(DEFAULT_SETTINGS)
            if res.data:
                for row in res.data:
                    k = row.get("key")
                    v = row.get("value")
                    if k is not None:
                        settings[k] = v
            return settings
        except Exception as e:
            logger.error(f"Error fetching system settings: {e}")
            return dict(DEFAULT_SETTINGS)

    @staticmethod
    def get_setting(key: str, default: bool = True) -> bool:
        """Fetches a specific system policy setting."""
        client = get_supabase()
        try:
            res = client.table("system_settings").select("value").eq("key", key).execute()
            if res.data and len(res.data) > 0:
                val = res.data[0].get("value")
                if isinstance(val, bool):
                    return val
                if isinstance(val, str):
                    return val.lower() in ("true", "1", "yes")
            return default
        except Exception as e:
            logger.error(f"Error fetching system setting {key}: {e}")
            return default

    @staticmethod
    def update_setting(key: str, value: Any) -> bool:
        """Updates a specific system policy setting."""
        client = get_supabase()
        try:
            client.table("system_settings").upsert({
                "key": key,
                "value": value
            }).execute()
            return True
        except Exception as e:
            logger.error(f"Error updating system setting {key}: {e}")
            return False

    @staticmethod
    def is_user_suspended(user_id: Optional[str], email: Optional[str] = None) -> bool:
        """Checks if a user is currently suspended."""
        if not user_id and not email:
            return False
        client = get_supabase()
        try:
            query = client.table("profiles").select("is_suspended")
            if user_id:
                query = query.eq("id", user_id)
            elif email:
                query = query.eq("email", email)
            res = query.execute()
            if res.data and len(res.data) > 0:
                return bool(res.data[0].get("is_suspended", False))
            return False
        except Exception as e:
            logger.error(f"Error checking suspension for user {user_id or email}: {e}")
            return False

