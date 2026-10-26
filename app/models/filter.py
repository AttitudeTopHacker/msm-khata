from pydantic import BaseModel, Field
from typing import Optional, Dict, Any

class SavedFilterBase(BaseModel):
    filter_name: str = Field(..., min_length=1, description="Custom name for this saved filter")
    filter_criteria: Dict[str, Any] = Field(..., description="Filter criteria (person_id, status, type, dates, etc.)")

class SavedFilterCreate(SavedFilterBase):
    user_id: Optional[str] = None

class SavedFilterResponse(SavedFilterBase):
    id: str
    user_id: Optional[str] = None
    created_at: Optional[str] = None
