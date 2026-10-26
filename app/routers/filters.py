from fastapi import APIRouter, HTTPException, status
from typing import List, Optional
from app.database import get_supabase
from app.models.filter import SavedFilterCreate, SavedFilterResponse

router = APIRouter(prefix="/filters", tags=["Saved Filters"])

@router.get("", response_model=List[SavedFilterResponse])
def get_saved_filters(user_id: Optional[str] = None):
    """List all saved custom filters."""
    client = get_supabase()
    query = client.table("saved_filters").select("*").order("created_at", desc=True)
    if user_id:
        query = query.eq("user_id", user_id)
    return query.execute().data or []

@router.post("", response_model=SavedFilterResponse, status_code=status.HTTP_201_CREATED)
def create_saved_filter(payload: SavedFilterCreate):
    """Save a user-defined filter configuration."""
    client = get_supabase()
    data = {
        "filter_name": payload.filter_name.strip(),
        "filter_criteria": payload.filter_criteria
    }
    if payload.user_id:
        data["user_id"] = payload.user_id
        
    res = client.table("saved_filters").insert(data).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to save filter")
    return res.data[0]

@router.delete("/{filter_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_saved_filter(filter_id: str):
    """Delete a saved filter."""
    client = get_supabase()
    client.table("saved_filters").delete().eq("id", filter_id).execute()
    return None
