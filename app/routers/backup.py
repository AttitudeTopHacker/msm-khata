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

@router.post("/google-drive")
def upload_backup_to_google_drive(
    google_access_token: str = Body(..., embed=True, description="Google OAuth access token"),
    user_id: Optional[str] = None
):
    """
    Uploads current MsmKhata ledger backup directly into user's Google Drive
    under 'MsmKhata Backups' folder.
    """
    backup_data = BackupService.generate_full_backup(user_id=user_id)
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    filename = f"msmkhata_backup_{date_str}.json"
    content_str = json.dumps(backup_data, indent=2)
    
    try:
        result = BackupService.upload_to_google_drive(
            access_token=google_access_token,
            backup_content=content_str,
            filename=filename,
            mime_type="application/json"
        )
        return {
            "status": "success",
            "message": "Backup uploaded successfully to Google Drive",
            "file_id": result.get("id"),
            "filename": filename,
            "google_drive_details": result
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Google Drive upload failed: {str(e)}"
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

