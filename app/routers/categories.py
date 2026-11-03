from fastapi import APIRouter, HTTPException, Query, status
from typing import List, Optional
from app.database import get_supabase
from app.models.category import CategoryCreate, CategoryUpdate, CategoryResponse

router = APIRouter(prefix="/categories", tags=["Categories"])

DEFAULT_SYSTEM_CATEGORIES = [
    # --- INCOME CATEGORIES ---
    {"name": "Paddy (Dhan Bikri)", "type": "INCOME", "color": "#10B981"},
    {"name": "Wheat (Gehu Bikri)", "type": "INCOME", "color": "#F59E0B"},
    {"name": "Sugarcane (Ganna)", "type": "INCOME", "color": "#84CC16"},
    {"name": "Mustard / Oilseeds (Sarson)", "type": "INCOME", "color": "#EAB308"},
    {"name": "Vegetables & Fruits (Sabzi/Fal)", "type": "INCOME", "color": "#14B8A6"},
    {"name": "Dairy & Milk (Doodh)", "type": "INCOME", "color": "#38BDF8"},
    {"name": "Rental Income (Kiraya/Bhaada)", "type": "INCOME", "color": "#6366F1"},
    {"name": "Other Income (Anya Kamai)", "type": "INCOME", "color": "#8B5CF6"},

    # --- EXPENSE CATEGORIES ---
    {"name": "Mandi & Selling", "type": "EXPENSE", "color": "#F97316"},
    {"name": "Ploughing", "type": "EXPENSE", "color": "#D97706"},
    {"name": "Irrigation", "type": "EXPENSE", "color": "#06B6D4"},
    {"name": "Diesel & Fuel", "type": "EXPENSE", "color": "#EF4444"},
    {"name": "Fertiliser & Seeds / Pesticides", "type": "EXPENSE", "color": "#10B981"},
    {"name": "Labour", "type": "EXPENSE", "color": "#8B5CF6"},
    {"name": "Machinery & Equipment", "type": "EXPENSE", "color": "#64748B"},
    {"name": "Family", "type": "EXPENSE", "color": "#EC4899"},
    {"name": "Household Expenses", "type": "EXPENSE", "color": "#F59E0B"},
    {"name": "Cropping / Harvester", "type": "EXPENSE", "color": "#84CC16"},
    {"name": "Personal", "type": "EXPENSE", "color": "#3B82F6"},
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
    """Create a new expense/income category with duplicate name prevention."""
    client = get_supabase()
    clean_name = payload.name.strip()
    if not clean_name:
        raise HTTPException(status_code=400, detail="Category name cannot be empty.")

    # Prevent duplicate category creation (case-insensitive)
    existing_query = client.table("categories").select("id, name").ilike("name", clean_name)
    if payload.user_id:
        existing_query = existing_query.or_(f"user_id.is.null,user_id.eq.{payload.user_id}")
    existing_res = existing_query.execute()
    if existing_res.data and len(existing_res.data) > 0:
        raise HTTPException(
            status_code=400,
            detail=f"A category named '{clean_name}' already exists. Duplicate category names are not permitted."
        )

    data = {
        "name": clean_name,
        "type": payload.type,
        "color": payload.color
    }
    if payload.user_id:
        data["user_id"] = payload.user_id
        
    res = client.table("categories").insert(data).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to create category.")
    return res.data[0]

import uuid

@router.put("/{category_id}", response_model=CategoryResponse)
def update_category(category_id: str, payload: CategoryUpdate):
    """Update category properties (name, color, type) with duplicate check."""
    try:
        uuid.UUID(str(category_id))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid category ID format.")

    client = get_supabase()
    update_data = payload.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields provided for update.")

    new_name = update_data.get("name")
    if new_name is not None:
        clean_name = new_name.strip()
        if not clean_name:
            raise HTTPException(status_code=400, detail="Category name cannot be empty.")
        update_data["name"] = clean_name

        # Prevent renaming to an existing duplicate category name (case-insensitive)
        dup_res = client.table("categories").select("id, name").ilike("name", clean_name).neq("id", category_id).execute()
        if dup_res.data and len(dup_res.data) > 0:
            raise HTTPException(
                status_code=400,
                detail=f"A category named '{clean_name}' already exists. Duplicate category names are not permitted."
            )

    res = client.table("categories").update(update_data).eq("id", category_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Category not found or update failed.")

    # If category name was updated, synchronize category_name in transactions linked to this category_id
    if new_name:
        try:
            client.table("transactions").update({"category_name": update_data["name"]}).eq("category_id", category_id).execute()
        except Exception:
            pass

    return res.data[0]

@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(category_id: str):
    """Delete a category if not in use by any transactions."""
    try:
        uuid.UUID(str(category_id))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid category ID format.")

    client = get_supabase()

    # 1. Fetch category info
    cat_res = client.table("categories").select("id, name").eq("id", category_id).execute()
    if not cat_res.data:
        raise HTTPException(status_code=404, detail="Category not found.")
    
    cat_name = cat_res.data[0].get("name") or "this category"

    # 2. Check if category is used in any transactions (by category_id or category_name)
    tx_check = client.table("transactions").select("id").eq("category_id", category_id).limit(1).execute()
    if tx_check.data and len(tx_check.data) > 0:
        raise HTTPException(
            status_code=400,
            detail=f"The category '{cat_name}' cannot be deleted because it is already associated with existing transactions. You may rename it instead."
        )

    if cat_name:
        tx_name_check = client.table("transactions").select("id").eq("category_name", cat_name).limit(1).execute()
        if tx_name_check.data and len(tx_name_check.data) > 0:
            raise HTTPException(
                status_code=400,
                detail=f"The category '{cat_name}' cannot be deleted because it is already associated with existing transactions. You may rename it instead."
            )

    client.table("categories").delete().eq("id", category_id).execute()
    return None
