from fastapi import APIRouter, HTTPException, Query, status
from typing import List, Optional
from app.database import get_supabase
from app.models.category import CategoryCreate, CategoryUpdate, CategoryResponse

router = APIRouter(prefix="/categories", tags=["Categories"])

DEFAULT_SYSTEM_CATEGORIES = [
    {"name": "Market", "type": "BOTH", "color": "#3B82F6"},
    {"name": "Mandi", "type": "BOTH", "color": "#10B981"},
    {"name": "Agriculture", "type": "BOTH", "color": "#84CC16"},
    {"name": "Ploughing", "type": "EXPENSE", "color": "#D97706"},
    {"name": "Irrigation", "type": "EXPENSE", "color": "#06B6D4"},
    {"name": "Diesel", "type": "EXPENSE", "color": "#EF4444"},
    {"name": "Fertiliser & Seeds", "type": "EXPENSE", "color": "#14B8A6"},
    {"name": "Labour", "type": "EXPENSE", "color": "#8B5CF6"},
    {"name": "Household Expenses", "type": "EXPENSE", "color": "#F59E0B"},
    {"name": "General", "type": "BOTH", "color": "#64748B"},
]

@router.get("", response_model=List[CategoryResponse])
def get_categories(
    type_filter: Optional[str] = Query(None, alias="type", description="EXPENSE, INCOME, or BOTH"),
    user_id: Optional[str] = None
):
    """List all categories."""
    client = get_supabase()
    query = client.table("categories").select("*").order("name")
    if user_id:
        query = query.or_(f"user_id.is.null,user_id.eq.{user_id}")
    if type_filter:
        query = query.in_("type", [type_filter.upper(), "BOTH"])
        
    res = query.execute().data or []
    if not res:
        # Auto-seed system defaults if database table is completely empty
        try:
            client.table("categories").insert(DEFAULT_SYSTEM_CATEGORIES).execute()
            res = client.table("categories").select("*").order("name").execute().data or []
        except Exception:
            pass
    return res

@router.post("", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(payload: CategoryCreate):
    """Create a new expense/income category."""
    client = get_supabase()
    data = {
        "name": payload.name.strip(),
        "type": payload.type,
        "color": payload.color
    }
    if payload.user_id:
        data["user_id"] = payload.user_id
        
    res = client.table("categories").insert(data).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to create category")
    return res.data[0]

@router.put("/{category_id}", response_model=CategoryResponse)
def update_category(category_id: str, payload: CategoryUpdate):
    """Update category properties."""
    client = get_supabase()
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields provided for update")
        
    res = client.table("categories").update(update_data).eq("id", category_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Category not found or update failed")
    return res.data[0]

@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(category_id: str):
    """Delete a category."""
    client = get_supabase()
    client.table("categories").delete().eq("id", category_id).execute()
    return None
