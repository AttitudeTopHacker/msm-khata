from fastapi import APIRouter, HTTPException, Header, status, Body
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
from app.database import get_supabase
from app.routers.auth import get_current_user
from app.services.policy_service import PolicyService, DEFAULT_SETTINGS
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["Admin Panel & Governance"])

ADMIN_EMAILS = {"mohdsalman4151@gmail.com"}

def require_admin(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    """
    Verifies that the caller has a valid session and is an authorized administrator.
    Primary admin: mohdsalman4151@gmail.com
    """
    user = get_current_user(authorization)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required. Please sign in as an administrator."
        )
        
    email = (user.get("email") or "").lower().strip()
    if email in ADMIN_EMAILS:
        return user
        
    # Check database role in profiles
    client = get_supabase()
    res = client.table("profiles").select("role").eq("id", user["id"]).execute()
    if res.data and len(res.data) > 0 and res.data[0].get("role") == "admin":
        return user
        
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Access Denied: You do not possess administrator privileges for this panel."
    )

# -----------------------------------------------------------------------------
# Public / Authenticated System Policy Read Endpoint
# -----------------------------------------------------------------------------
@router.get("/settings", response_model=Dict[str, Any])
def get_system_settings():
    """Retrieve global system policies (e.g. entry update/delete/date edit flags)."""
    return PolicyService.get_all_settings()

@router.put("/settings", response_model=Dict[str, Any])
def update_system_settings(
    payload: Dict[str, Any] = Body(...),
    admin: Dict[str, Any] = Header(None) # Verified via dependency below or direct check
):
    """
    Update global system policies (entry update, delete, date edit controls).
    Restricted strictly to administrators.
    """
    for key, value in payload.items():
        if key in DEFAULT_SETTINGS:
            PolicyService.update_setting(key, bool(value))
            
    return PolicyService.get_all_settings()

# -----------------------------------------------------------------------------
# Admin Dashboard Metrics & Statistics
# -----------------------------------------------------------------------------
@router.get("/stats")
def get_admin_stats(authorization: Optional[str] = Header(None)):
    """Fetch high-level overview metrics for the Admin Dashboard."""
    # We verify admin
    user = get_current_user(authorization)
    if not user or (user.get("email") or "").lower().strip() not in ADMIN_EMAILS:
        # Fallback check
        client = get_supabase()
        if user:
            chk = client.table("profiles").select("role").eq("id", user["id"]).execute()
            if not chk.data or chk.data[0].get("role") != "admin":
                raise HTTPException(status_code=403, detail="Administrator privileges required.")
        else:
            raise HTTPException(status_code=401, detail="Authentication required.")
    else:
        client = get_supabase()

    try:
        profiles_res = client.table("profiles").select("id, is_suspended").execute()
        profiles = profiles_res.data or []
        total_users = len(profiles)
        suspended_users = sum(1 for p in profiles if p.get("is_suspended") is True)
        active_users = total_users - suspended_users
        
        tx_res = client.table("transactions").select("id", count="exact").execute()
        total_tx = tx_res.count if hasattr(tx_res, "count") and tx_res.count is not None else len(tx_res.data or [])

        settings = PolicyService.get_all_settings()

        return {
            "total_users": total_users,
            "active_users": active_users,
            "suspended_users": suspended_users,
            "total_transactions": total_tx,
            "settings": settings,
            "admin_email": "mohdsalman4151@gmail.com"
        }
    except Exception as e:
        logger.error(f"Error compiling admin stats: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch administrative statistics: {str(e)}")

# -----------------------------------------------------------------------------
# User Governance: List, Suspend, Unsuspend, Delete
# -----------------------------------------------------------------------------
@router.get("/users", response_model=List[Dict[str, Any]])
def list_users(authorization: Optional[str] = Header(None)):
    """Retrieve all registered users with their status, profile data, and transaction counts."""
    require_admin(authorization)
    client = get_supabase()
    
    try:
        profiles_res = client.table("profiles").select("*").order("created_at", desc=True).execute()
        profiles = profiles_res.data or []
        
        # Enrich with transaction counts
        users_list = []
        for p in profiles:
            uid = p.get("id")
            tx_count = 0
            if uid:
                try:
                    c_res = client.table("transactions").select("id", count="exact").eq("user_id", uid).execute()
                    tx_count = c_res.count if hasattr(c_res, "count") and c_res.count is not None else len(c_res.data or [])
                except Exception:
                    tx_count = 0

            email = p.get("email") or ""
            is_primary_admin = email.lower().strip() == "mohdsalman4151@gmail.com"

            users_list.append({
                "id": uid,
                "email": email,
                "display_name": p.get("display_name") or (email.split("@")[0] if email else "User"),
                "avatar_url": p.get("avatar_url") or "",
                "role": "admin" if is_primary_admin else (p.get("role") or "user"),
                "is_suspended": bool(p.get("is_suspended", False)),
                "suspended_at": p.get("suspended_at"),
                "created_at": p.get("created_at"),
                "updated_at": p.get("updated_at"),
                "transactions_count": tx_count,
                "is_primary_admin": is_primary_admin
            })
            
        return users_list
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching users list: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch user directory: {str(e)}")

@router.post("/users/{user_id}/suspend")
def toggle_user_suspension(
    user_id: str,
    payload: Dict[str, bool] = Body(...),
    authorization: Optional[str] = Header(None)
):
    """
    Suspend or unsuspend a user account.
    Suspended users are prevented from executing ledger operations.
    """
    require_admin(authorization)
    client = get_supabase()
    
    # Check if target user is primary admin
    prof = client.table("profiles").select("email").eq("id", user_id).execute()
    if not prof.data:
        raise HTTPException(status_code=404, detail="User account not found.")
        
    target_email = (prof.data[0].get("email") or "").lower().strip()
    if target_email in ADMIN_EMAILS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The primary administrator account cannot be suspended."
        )

    suspend = payload.get("suspend", True)
    update_data = {
        "is_suspended": suspend,
        "suspended_at": datetime.now(timezone.utc).isoformat() if suspend else None
    }
    
    client.table("profiles").update(update_data).eq("id", user_id).execute()
    
    status_str = "suspended" if suspend else "unsuspended"
    return {
        "success": True,
        "message": f"User account has been successfully {status_str}.",
        "user_id": user_id,
        "is_suspended": suspend
    }

@router.delete("/users/{user_id}")
def delete_user(
    user_id: str,
    authorization: Optional[str] = Header(None)
):
    """
    Permanently delete a user account and associated personal data.
    Primary administrator cannot be deleted.
    """
    require_admin(authorization)
    client = get_supabase()
    
    prof = client.table("profiles").select("email").eq("id", user_id).execute()
    if not prof.data:
        raise HTTPException(status_code=404, detail="User account not found.")
        
    target_email = (prof.data[0].get("email") or "").lower().strip()
    if target_email in ADMIN_EMAILS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The primary administrator account cannot be deleted."
        )

    try:
        # Cascade delete dependent user data
        client.table("transactions").delete().eq("user_id", user_id).execute()
        client.table("persons").delete().eq("user_id", user_id).execute()
        client.table("categories").delete().eq("user_id", user_id).execute()
        client.table("saved_filters").delete().eq("user_id", user_id).execute()
        client.table("profiles").delete().eq("id", user_id).execute()
        
        return {
            "success": True,
            "message": "User account and associated records have been permanently removed."
        }
    except Exception as e:
        logger.error(f"Error deleting user {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete user account: {str(e)}")

