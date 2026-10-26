from pydantic import BaseModel, Field
from typing import Optional, Literal

CategoryType = Literal["EXPENSE", "INCOME", "BOTH"]

class CategoryBase(BaseModel):
    name: str = Field(..., min_length=1, description="Category name (Food, Fuel, Bills, etc.)")
    type: CategoryType = Field("BOTH", description="Category classification: EXPENSE, INCOME, or BOTH")
    color: str = Field("#4F46E5", description="Hex color code for charts and UI badges")

class CategoryCreate(CategoryBase):
    user_id: Optional[str] = None

class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[CategoryType] = None
    color: Optional[str] = None

class CategoryResponse(CategoryBase):
    id: str
    user_id: Optional[str] = None
    created_at: Optional[str] = None
    total_amount: Optional[float] = None
