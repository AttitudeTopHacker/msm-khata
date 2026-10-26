from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime

TransactionType = Literal["GIVEN", "TAKEN", "EXPENSE", "INCOME"]
PaymentMode = Literal["CASH", "UPI", "BANK_TRANSFER", "OTHER"]

class TransactionBase(BaseModel):
    type: TransactionType = Field(..., description="GIVEN (Maine Diye), TAKEN (Maine Liye), EXPENSE, INCOME")
    amount: float = Field(..., gt=0, description="Transaction amount")
    payment_mode: PaymentMode = Field("CASH", description="Payment method: CASH, UPI, BANK_TRANSFER, OTHER")
    due_date: Optional[str] = Field(None, description="Due date for settlement (YYYY-MM-DD)")
    is_settled: bool = Field(False, description="Whether this loan/transaction is settled")
    notes: Optional[str] = Field(None, description="Remarks or details")
    transaction_date: Optional[str] = Field(None, description="Date of transaction (ISO format)")

class TransactionCreate(TransactionBase):
    user_id: Optional[str] = None
    person_id: Optional[str] = None
    person_name: Optional[str] = Field(None, description="If provided, auto-creates or links person on-the-fly")
    category_id: Optional[str] = None
    category_name: Optional[str] = Field(None, description="If provided, auto-creates or links category on-the-fly")

class TransactionUpdate(BaseModel):
    type: Optional[TransactionType] = None
    amount: Optional[float] = Field(None, gt=0)
    payment_mode: Optional[PaymentMode] = None
    due_date: Optional[str] = None
    is_settled: Optional[bool] = None
    notes: Optional[str] = None
    transaction_date: Optional[str] = None
    person_id: Optional[str] = None
    category_id: Optional[str] = None

class TransactionResponse(TransactionBase):
    id: str
    user_id: Optional[str] = None
    person_id: Optional[str] = None
    person_name: Optional[str] = None
    category_id: Optional[str] = None
    category_name: Optional[str] = None
    category_color: Optional[str] = None
    created_at: Optional[str] = None
