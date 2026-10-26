from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class PersonBase(BaseModel):
    name: str = Field(..., min_length=1, description="Person or contact name")
    phone: Optional[str] = Field(None, description="Contact phone number")
    notes: Optional[str] = Field(None, description="Optional notes about this person")

class PersonCreate(PersonBase):
    user_id: Optional[str] = None

class PersonUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    notes: Optional[str] = None

class PersonResponse(PersonBase):
    id: str
    user_id: Optional[str] = None
    created_at: Optional[str] = None

class PersonWithBalanceResponse(PersonResponse):
    total_given: float = 0.0      # Maine diye (Lent)
    total_taken: float = 0.0      # Maine liye (Borrowed)
    net_balance: float = 0.0      # Positive = Lena Hai, Negative = Dena Hai, 0 = Settled
    status: str = "SETTLED"       # "TO_RECEIVE", "TO_PAY", "SETTLED"
    transaction_count: int = 0
