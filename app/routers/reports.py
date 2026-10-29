from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Response, Query
from typing import Optional
from app.database import get_supabase
from app.services.ledger_service import LedgerService
from app.services.report_service import ReportService

router = APIRouter(prefix="/reports", tags=["Reports (PDF & Excel Engine)"])

@router.get("/pdf")
def download_pdf_statement(
    account_id: Optional[str] = Query(default="main", description="Account/Book ID to isolate"),
    account_name: Optional[str] = Query(default="Main Account", description="Display name of account"),
    user_id: Optional[str] = Query(default=None)
):
    """
    Generate and stream an executive A4 Financial Audit Statement in PDF
    featuring Matplotlib analytics charts, Cashflow tiles, and full Passbook Ledger.
    """
    client = get_supabase()
    
    # 1. Fetch transactions for account
    q = client.table("transactions").select("*, persons(name), categories(name, color)").order("transaction_date", desc=True)
    if account_id:
        q = q.eq("account_id", account_id)
    if user_id:
        q = q.eq("user_id", user_id)
        
    res = q.execute()
    tx_rows = res.data or []
    
    # Flatten joined names
    transactions = []
    for row in tx_rows:
        p_info = row.get("persons") or {}
        c_info = row.get("categories") or {}
        transactions.append({
            "id": row.get("id"),
            "transaction_date": row.get("transaction_date") or row.get("created_at"),
            "type": row.get("type"),
            "amount": float(row.get("amount", 0.0)),
            "payment_mode": row.get("payment_mode", "CASH"),
            "person_name": p_info.get("name"),
            "category_name": c_info.get("name"),
            "notes": row.get("notes"),
            "account_id": row.get("account_id") or "main",
            "account_name": row.get("account_name") or account_name
        })
        
    # 2. Compute Dashboard Summary
    summary_obj = LedgerService.calculate_dashboard_summary(user_id=user_id, account_id=account_id)
    summary_dict = summary_obj.model_dump() if hasattr(summary_obj, "model_dump") else summary_obj.dict()
    
    # 3. Persons balances
    persons_objs = LedgerService.calculate_person_balances(user_id=user_id, account_id=account_id)
    persons_list = [p.model_dump() if hasattr(p, "model_dump") else p.dict() for p in persons_objs]
    
    # 4. Generate PDF
    try:
        pdf_bytes = ReportService.generate_pdf(
            account_id=account_id,
            account_name=account_name,
            transactions=transactions,
            summary=summary_dict,
            persons=persons_list
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF generation error: {str(e)}")
        
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    safe_name = account_name.lower().replace(" ", "_").replace("(", "").replace(")", "")
    filename = f"msmkhata_{safe_name}_{date_str}.pdf"
    
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )

@router.get("/excel")
def download_excel_workbook(
    account_id: Optional[str] = Query(default="main", description="Account/Book ID to isolate"),
    account_name: Optional[str] = Query(default="Main Account", description="Display name of account"),
    user_id: Optional[str] = Query(default=None)
):
    """
    Generate and stream an enterprise multi-tab Excel Workbook (.xlsx)
    including Executive Summary, Passbook & Transactions, and Len-Den Parties.
    """
    client = get_supabase()
    
    # 1. Fetch transactions for account
    q = client.table("transactions").select("*, persons(name), categories(name, color)").order("transaction_date", desc=True)
    if account_id:
        q = q.eq("account_id", account_id)
    if user_id:
        q = q.eq("user_id", user_id)
        
    res = q.execute()
    tx_rows = res.data or []
    
    # Flatten joined names
    transactions = []
    for row in tx_rows:
        p_info = row.get("persons") or {}
        c_info = row.get("categories") or {}
        transactions.append({
            "id": row.get("id"),
            "transaction_date": row.get("transaction_date") or row.get("created_at"),
            "type": row.get("type"),
            "amount": float(row.get("amount", 0.0)),
            "payment_mode": row.get("payment_mode", "CASH"),
            "person_name": p_info.get("name"),
            "category_name": c_info.get("name"),
            "notes": row.get("notes"),
            "account_id": row.get("account_id") or "main",
            "account_name": row.get("account_name") or account_name
        })
        
    # 2. Compute Dashboard Summary
    summary_obj = LedgerService.calculate_dashboard_summary(user_id=user_id, account_id=account_id)
    summary_dict = summary_obj.model_dump() if hasattr(summary_obj, "model_dump") else summary_obj.dict()
    
    # 3. Persons balances
    persons_objs = LedgerService.calculate_person_balances(user_id=user_id, account_id=account_id)
    persons_list = [p.model_dump() if hasattr(p, "model_dump") else p.dict() for p in persons_objs]
    
    # 4. Generate Excel
    try:
        excel_bytes = ReportService.generate_excel(
            account_id=account_id,
            account_name=account_name,
            transactions=transactions,
            summary=summary_dict,
            persons=persons_list
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Excel generation error: {str(e)}")
        
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    safe_name = account_name.lower().replace(" ", "_").replace("(", "").replace(")", "")
    filename = f"msmkhata_{safe_name}_{date_str}.xlsx"
    
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )
