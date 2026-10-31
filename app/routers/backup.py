import json
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Response, Query, Header, Body, status
from typing import Optional, Dict, Any
from app.services.backup_service import BackupService

router = APIRouter(prefix="/backup", tags=["Backup & Google Drive"])

@router.get("/export/json")
def export_json_backup(user_id: Optional[str] = None):
    """
    Downloads complete JSON backup of MsmKhata ledger.
    Contains persons, categories, transactions, and saved filters.
    """
    backup_data = BackupService.generate_full_backup(user_id=user_id)
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    filename = f"msmkhata_backup_{date_str}.json"
    
    json_bytes = json.dumps(backup_data, indent=2).encode("utf-8")
    
    return Response(
        content=json_bytes,
        media_type="application/json",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )

@router.get("/export/csv")
def export_csv_backup(user_id: Optional[str] = None):
    """
    Downloads Excel/Google Sheets compatible CSV export of all transactions.
    """
    csv_content = BackupService.generate_csv_export(user_id=user_id)
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    filename = f"msmkhata_transactions_{date_str}.csv"
    
    return Response(
        content=csv_content.encode("utf-8"),
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )

from pydantic import BaseModel
from app.database import get_supabase
from app.services.ledger_service import LedgerService
from app.services.report_service import ReportService

class GoogleDriveBackupRequest(BaseModel):
    google_access_token: str
    user_id: Optional[str] = None
    account_id: Optional[str] = "main"
    account_name: Optional[str] = "Main Account"
    include_excel: bool = False
    include_pdf: bool = True

@router.post("/google-drive")
def upload_backup_to_google_drive(payload: GoogleDriveBackupRequest):
    """
    Generates official A4 PDF Statement with charts & itemized ledger and uploads
    it directly into user's Google Drive under 'MsmKhata Backups' folder.
    """
    date_str = datetime.now(timezone.utc).strftime("%d_%b_%Y_%H%M%S")
    uploaded_files = []
    
    try:
        # Fetch transactions & summary for the selected account
        client = get_supabase()
        q = client.table("transactions").select("*, persons(name), categories(name, color)").order("transaction_date", desc=True)
        if payload.account_id:
            q = q.eq("account_id", payload.account_id)
        if payload.user_id:
            q = q.eq("user_id", payload.user_id)
        res = q.execute()
        tx_rows = res.data or []
        
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
                "account_name": row.get("account_name") or payload.account_name
            })
            
        summary_obj = LedgerService.calculate_dashboard_summary(user_id=payload.user_id, account_id=payload.account_id)
        summary_dict = summary_obj.model_dump() if hasattr(summary_obj, "model_dump") else summary_obj.dict()
        persons_objs = LedgerService.calculate_person_balances(user_id=payload.user_id, account_id=payload.account_id)
        persons_list = [p.model_dump() if hasattr(p, "model_dump") else p.dict() for p in persons_objs]

        # Generate Official PDF Statement (.pdf)
        pdf_bytes = ReportService.generate_pdf(
            account_id=payload.account_id or "main",
            account_name=payload.account_name or "Main Account",
            transactions=transactions,
            summary=summary_dict,
            persons=persons_list
        )
        safe_acc_name = (payload.account_name or "statement").replace(" ", "_").lower()
        pdf_filename = f"msmkhata_{safe_acc_name}_{date_str}.pdf"
        
        pdf_res = BackupService.upload_to_google_drive(
            access_token=payload.google_access_token,
            backup_content=pdf_bytes,
            filename=pdf_filename,
            mime_type="application/pdf"
        )
        uploaded_files.append({
            "type": "Official PDF Statement (.pdf)",
            "filename": pdf_filename,
            "file_id": pdf_res.get("id")
        })

        return {
            "status": "success",
            "message": f"Statement PDF '{pdf_filename}' uploaded successfully to Google Drive folder 'MsmKhata Backups'",
            "uploaded_files": uploaded_files,
            "folder": "MsmKhata Backups"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"{str(e)}"
        )

@router.post("/reset-data")
def reset_all_data():
    """Wipes all test transactions, persons, and custom test data."""
    from app.database import get_supabase
    client = get_supabase()
    try:
        client.table("transactions").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        client.table("saved_filters").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        client.table("persons").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        client.table("categories").delete().not_.is_("user_id", "null").execute()
        return {"status": "success", "message": "All data cleared successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

