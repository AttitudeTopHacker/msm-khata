from fastapi import APIRouter, Depends, HTTPException, Header, status
from typing import Optional, Dict, Any
from app.database import get_supabase
from app.config import settings

router = APIRouter(prefix="/auth", tags=["Authentication & Profile"])

def get_current_user(authorization: Optional[str] = Header(None)) -> Optional[Dict[str, Any]]:
    """
    Extracts and validates Supabase JWT token from Authorization header.
    Returns user dict or None if no token provided.
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None
        
    token = authorization.split(" ")[1]
    client = get_supabase()
    try:
        user_res = client.auth.get_user(token)
        if user_res and user_res.user:
            return {
                "id": user_res.user.id,
                "email": user_res.user.email,
                "user_metadata": user_res.user.user_metadata or {}
            }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired authentication token: {str(e)}"
        )
    return None

@router.get("/me")
def get_current_profile(authorization: Optional[str] = Header(None)):
    """
    Returns the currently logged-in user profile with their 
    Gmail / GitHub avatar and display name from public.profiles.
    """
    user = get_current_user(authorization)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header with Bearer token is required."
        )
        
    client = get_supabase()
    res = client.table("profiles").select("*").eq("id", user["id"]).execute()
    
    if res.data and len(res.data) > 0:
        return res.data[0]
        
    # Fallback to auth metadata if profile row pending
    meta = user.get("user_metadata", {})
    return {
        "id": user["id"],
        "email": user["email"],
        "display_name": meta.get("full_name") or meta.get("name") or user["email"].split("@")[0],
        "avatar_url": meta.get("avatar_url") or meta.get("picture") or "",
        "created_at": None
    }

@router.get("/config")
def get_auth_config():
    """
    Returns Supabase Auth configuration and redirect callback URL
    needed for Google Cloud and GitHub Developer console setup.
    """
    callback_url = f"{settings.SUPABASE_URL}/auth/v1/callback"
    return {
        "supabase_url": settings.SUPABASE_URL,
        "callback_url": callback_url,
        "providers_supported": ["google", "github"],
        "instructions": {
            "google": {
                "authorized_redirect_uri": callback_url,
                "console_url": "https://console.cloud.google.com/apis/credentials"
            },
            "github": {
                "authorization_callback_url": callback_url,
                "console_url": "https://github.com/settings/developers"
            }
        }
    }
