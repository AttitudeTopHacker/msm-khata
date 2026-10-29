from pydantic import BaseModel
from typing import List, Dict, Optional

class CategoryBreakdownItem(BaseModel):
    category_id: Optional[str] = None
    category_name: str
    color: str
    total_amount: float
    percentage: float

class PersonBalanceSummary(BaseModel):
    person_id: str
    name: str
    total_given: float
    total_taken: float
    net_balance: float
    status: str

class MonthlyTrendItem(BaseModel):
    month: str             # e.g., "2026-10"
    total_income: float
    total_expense: float
    total_given: float
    total_taken: float

class DashboardSummary(BaseModel):
    # Passbook / Master Account Real Balances
    net_account_balance: float = 0.0  # (income + taken) - (expense + given)
    total_money_in: float = 0.0       # income + taken
    total_money_out: float = 0.0      # expense + given
    active_account_id: Optional[str] = "main"

    # Len-Den Metrics
    total_receivable: float = 0.0     # Total Market Lena Hai
    total_payable: float = 0.0        # Total Market Dena Hai
    net_len_den_position: float = 0.0 # receivable - payable
    
    # Self Metrics
    total_income: float = 0.0
    total_expense: float = 0.0
    net_savings: float = 0.0          # income - expense
    
    # Active summaries
    people_to_receive_from_count: int = 0
    people_to_pay_to_count: int = 0
    total_transactions_count: int = 0
    
    # Visual breakdowns
    category_breakdown: List[CategoryBreakdownItem] = []
    top_debtors: List[PersonBalanceSummary] = []    # Jinse sabse zyada lena hai
    top_creditors: List[PersonBalanceSummary] = []  # Jinko sabse zyada dena hai
    monthly_trends: List[MonthlyTrendItem] = []
