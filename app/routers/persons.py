from fastapi import APIRouter, HTTPException, Query, status
from typing import List, Optional
from app.database import get_supabase
from app.models.person import (
    PersonCreate,
    PersonUpdate,
    PersonResponse,
    PersonWithBalanceResponse
)
from app.models.transaction import TransactionResponse
from app.services.ledger_service import LedgerService

router = APIRouter(prefix="/persons", tags=["Persons (Len-Den Contacts)"])

@router.get("", response_model=List[PersonWithBalanceResponse])
def get_persons(
    status_filter: Optional[str] = Query(
        None,
        alias="status",
        description="Filter by balance status: TO_RECEIVE, TO_PAY, SETTLED"
    ),
    user_id: Optional[str] = None
):
    """Fetch all contacts with real-time Len-Den balances."""
    balances = LedgerService.calculate_person_balances(user_id=user_id)
    if status_filter:
        balances = [p for p in balances if p.status == status_filter.upper()]
    return balances

@router.post("", response_model=PersonResponse, status_code=status.HTTP_201_CREATED)
def create_person(payload: PersonCreate):
    """Create a new contact manually."""
    client = get_supabase()
    data = {"name": payload.name.strip()}
    if payload.phone:
        data["phone"] = payload.phone.strip()
    if payload.notes:
        data["notes"] = payload.notes.strip()
    if payload.user_id:
        data["user_id"] = payload.user_id

    res = client.table("persons").insert(data).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to create person")
    return res.data[0]

@router.get("/{person_id}", response_model=PersonWithBalanceResponse)
def get_person(person_id: str, user_id: Optional[str] = None):
    """Get single person details with their net balance."""
    balances = LedgerService.calculate_person_balances(user_id=user_id)
    match = next((p for p in balances if p.id == person_id), None)
    if not match:
        raise HTTPException(status_code=404, detail="Person not found")
    return match

import uuid

@router.put("/{person_id}", response_model=PersonResponse)
def update_person(person_id: str, payload: PersonUpdate):
    """Update contact information."""
    try:
        uuid.UUID(str(person_id))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid person ID format")

    client = get_supabase()
    update_data = payload.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields provided for update")
        
    res = client.table("persons").update(update_data).eq("id", person_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Person not found or update failed")
    return res.data[0]

@router.delete("/{person_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_person(person_id: str):
    """Delete person contact."""
    try:
        uuid.UUID(str(person_id))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid person ID format")

    client = get_supabase()
    res = client.table("persons").delete().eq("id", person_id).execute()
    return None

@router.get("/{person_id}/transactions", response_model=List[TransactionResponse])
def get_person_transactions(person_id: str, user_id: Optional[str] = None):
    """Get full ledger timeline for a specific person."""
    client = get_supabase()
    query = client.table("transactions").select(
        "*, persons(name), categories(name, color)"
    ).eq("person_id", person_id).order("transaction_date", desc=True)
    
    if user_id:
        query = query.eq("user_id", user_id)
        
    res = query.execute().data or []
    formatted = []
    for row in res:
        person_info = row.get("persons") or {}
        cat_info = row.get("categories") or {}
        formatted.append(
            TransactionResponse(
                id=row["id"],
                user_id=row.get("user_id"),
                type=row["type"],
                amount=float(row["amount"]),
                payment_mode=row.get("payment_mode", "CASH"),
                due_date=row.get("due_date"),
                is_settled=row.get("is_settled", False),
                notes=row.get("notes"),
                transaction_date=row.get("transaction_date"),
                person_id=row.get("person_id"),
                person_name=person_info.get("name"),
                category_id=row.get("category_id"),
                category_name=cat_info.get("name"),
                category_color=cat_info.get("color"),
                created_at=row.get("created_at")
            )
        )
    return formatted
