from fastapi import APIRouter
from typing import Optional
from app.models.stats import DashboardSummary
from app.services.ledger_service import LedgerService

router = APIRouter(prefix="/stats", tags=["Stats & Dashboard Calculations"])

@router.get("/summary", response_model=DashboardSummary)
def get_dashboard_summary(user_id: Optional[str] = None, account_id: Optional[str] = None):
    """
    Computes all dashboard metrics for the specified account/book:
    - Net Available Account Passbook Balance (Money In vs Money Out)
    - Net Position Card: Total Lena Hai vs Total Dena Hai
    - Personal: Total Income vs Total Expense vs Net Savings
    - Category-wise Spending Donut breakdown
    - Monthly Len-Den & Cash Flow Trends
    - Top Debtors & Creditors
    """
    return LedgerService.calculate_dashboard_summary(user_id=user_id, account_id=account_id)
