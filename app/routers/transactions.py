from fastapi import APIRouter, HTTPException, Query, status
from typing import List, Optional
from datetime import datetime, timezone
from app.database import get_supabase
from app.models.transaction import (
    TransactionCreate,
    TransactionUpdate,
    TransactionResponse
)
from app.services.ledger_service import LedgerService

router = APIRouter(prefix="/transactions", tags=["Transactions (Ledger)"])

@router.get("", response_model=List[TransactionResponse])
def get_transactions(
    account_id: Optional[str] = Query(None, description="Account / Book ID filter"),
    person_id: Optional[str] = None,
    category_id: Optional[str] = None,
    type_filter: Optional[str] = Query(None, alias="type", description="GIVEN, TAKEN, EXPENSE, INCOME"),
    payment_mode: Optional[str] = None,
    is_settled: Optional[bool] = None,
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    user_id: Optional[str] = None,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0)
):
    """Fetch transactions with dynamic multi-criteria filters."""
    client = get_supabase()
    query = client.table("transactions").select(
        "*, persons(name), categories(name, color)"
    ).order("transaction_date", desc=True)
    
    if user_id:
        query = query.eq("user_id", user_id)
    if account_id:
        query = query.eq("account_id", account_id)
    if person_id:
        query = query.eq("person_id", person_id)
    if category_id:
        query = query.eq("category_id", category_id)
    if type_filter:
        query = query.eq("type", type_filter.upper())
    if payment_mode:
        query = query.eq("payment_mode", payment_mode.upper())
    if is_settled is not None:
        query = query.eq("is_settled", is_settled)
    if start_date:
        query = query.gte("transaction_date", f"{start_date}T00:00:00Z")
    if end_date:
        query = query.lte("transaction_date", f"{end_date}T23:59:59Z")
        
    query = query.range(offset, offset + limit - 1)
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
                account_id=row.get("account_id") or "main",
                account_name=row.get("account_name") or "Main Account",
                created_at=row.get("created_at")
            )
        )
    return formatted

@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(payload: TransactionCreate):
    """
    Record a transaction.
    Supports on-the-fly creation:
    - If `person_name` is provided, person is auto-created/linked in background.
    - If `category_name` is provided, category is auto-created/linked in background.
    """
    client = get_supabase()
    
    # 1. Resolve Person
    person_id = payload.person_id
    if not person_id and payload.person_name and payload.person_name.strip():
        person_id = LedgerService.get_or_create_person(
            name=payload.person_name,
            user_id=payload.user_id
        )
        
    # 2. Resolve Category
    category_id = payload.category_id
    if not category_id and payload.category_name and payload.category_name.strip():
        cat_type = "INCOME" if payload.type == "INCOME" else "EXPENSE"
        category_id = LedgerService.get_or_create_category(
            name=payload.category_name,
            category_type=cat_type,
            user_id=payload.user_id
        )
        
    # 3. Insert Transaction
    t_date = payload.transaction_date or datetime.now(timezone.utc).isoformat()
    record = {
        "type": payload.type,
        "amount": payload.amount,
        "payment_mode": payload.payment_mode,
        "due_date": payload.due_date,
        "is_settled": payload.is_settled,
        "notes": payload.notes,
        "transaction_date": t_date,
        "person_id": person_id,
        "category_id": category_id,
        "account_id": payload.account_id or "main",
        "account_name": payload.account_name or "Main Account"
    }
    if payload.user_id:
        record["user_id"] = payload.user_id
        
    res = client.table("transactions").insert(record).execute()
    if not res.data:
        raise HTTPException(status_code=400, detail="Failed to create transaction")
        
    inserted_id = res.data[0]["id"]
    
    # Fetch with joins
    fetch_res = client.table("transactions").select(
        "*, persons(name), categories(name, color)"
    ).eq("id", inserted_id).execute()
    
    row = fetch_res.data[0]
    person_info = row.get("persons") or {}
    cat_info = row.get("categories") or {}
    
    return TransactionResponse(
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
        account_id=row.get("account_id") or "main",
        account_name=row.get("account_name") or "Main Account",
        created_at=row.get("created_at")
    )

@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(transaction_id: str):
    """Get single transaction by ID."""
    client = get_supabase()
    res = client.table("transactions").select(
        "*, persons(name), categories(name, color)"
    ).eq("id", transaction_id).execute()
    
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
        
    row = res.data[0]
    person_info = row.get("persons") or {}
    cat_info = row.get("categories") or {}
    
    return TransactionResponse(
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
        account_id=row.get("account_id") or "main",
        account_name=row.get("account_name") or "Main Account",
        created_at=row.get("created_at")
    )

@router.put("/{transaction_id}", response_model=TransactionResponse)
def update_transaction(transaction_id: str, payload: TransactionUpdate):
    """Update transaction fields."""
    client = get_supabase()
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields provided for update")
        
    res = client.table("transactions").update(update_data).eq("id", transaction_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found or update failed")
        
    return get_transaction(transaction_id)

@router.patch("/{transaction_id}/settle", response_model=TransactionResponse)
def toggle_settle_transaction(transaction_id: str, is_settled: bool = True):
    """Mark a loan/borrow transaction as settled or unsettled."""
    client = get_supabase()
    res = client.table("transactions").update({"is_settled": is_settled}).eq("id", transaction_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return get_transaction(transaction_id)

@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(transaction_id: str):
    """Delete a transaction."""
    client = get_supabase()
    client.table("transactions").delete().eq("id", transaction_id).execute()
    return None
