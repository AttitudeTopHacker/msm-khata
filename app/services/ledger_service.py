from typing import List, Dict, Any, Optional
from collections import defaultdict
from datetime import datetime
from app.database import get_supabase
from app.models.person import PersonWithBalanceResponse, PersonResponse
from app.models.category import CategoryResponse
from app.models.transaction import TransactionCreate, TransactionResponse
from app.models.stats import (
    DashboardSummary,
    CategoryBreakdownItem,
    PersonBalanceSummary,
    MonthlyTrendItem
)

class LedgerService:
    @staticmethod
    def get_or_create_person(name: str, user_id: Optional[str] = None) -> str:
        """Finds person by name or creates a new person on-the-fly."""
        client = get_supabase()
        cleaned_name = name.strip()
        query = client.table("persons").select("id").ilike("name", cleaned_name)
        if user_id:
            query = query.eq("user_id", user_id)
        
        result = query.execute()
        if result.data and len(result.data) > 0:
            return result.data[0]["id"]
        
        # Create new person
        payload = {"name": cleaned_name}
        if user_id:
            payload["user_id"] = user_id
        
        insert_res = client.table("persons").insert(payload).execute()
        if insert_res.data and len(insert_res.data) > 0:
            return insert_res.data[0]["id"]
        raise RuntimeError(f"Failed to auto-create person: {name}")

    @staticmethod
    def get_or_create_category(
        name: str,
        category_type: str = "EXPENSE",
        color: str = "#4F46E5",
        user_id: Optional[str] = None
    ) -> str:
        """Finds category by name or creates a new category on-the-fly."""
        client = get_supabase()
        cleaned_name = name.strip()
        query = client.table("categories").select("id").ilike("name", cleaned_name)
        if user_id:
            query = query.eq("user_id", user_id)
        
        result = query.execute()
        if result.data and len(result.data) > 0:
            return result.data[0]["id"]
        
        # Auto-create category
        payload = {
            "name": cleaned_name,
            "type": category_type,
            "color": color
        }
        if user_id:
            payload["user_id"] = user_id
            
        insert_res = client.table("categories").insert(payload).execute()
        if insert_res.data and len(insert_res.data) > 0:
            return insert_res.data[0]["id"]
        raise RuntimeError(f"Failed to auto-create category: {name}")

    @staticmethod
    def calculate_person_balances(user_id: Optional[str] = None) -> List[PersonWithBalanceResponse]:
        """Calculates individual Len-Den balances for all contacts."""
        client = get_supabase()
        
        # Fetch all persons
        p_query = client.table("persons").select("*")
        if user_id:
            p_query = p_query.eq("user_id", user_id)
        persons_data = p_query.execute().data or []
        
        # Fetch all transactions involving persons
        t_query = client.table("transactions").select("*").in_("type", ["GIVEN", "TAKEN"])
        if user_id:
            t_query = t_query.eq("user_id", user_id)
        transactions_data = t_query.execute().data or []
        
        # Group transactions by person_id
        person_stats = defaultdict(lambda: {"given": 0.0, "taken": 0.0, "count": 0})
        for t in transactions_data:
            pid = t.get("person_id")
            if not pid:
                continue
            amt = float(t.get("amount") or 0.0)
            t_type = t.get("type")
            person_stats[pid]["count"] += 1
            if t_type == "GIVEN":
                person_stats[pid]["given"] += amt
            elif t_type == "TAKEN":
                person_stats[pid]["taken"] += amt
        
        result: List[PersonWithBalanceResponse] = []
        for p in persons_data:
            pid = p["id"]
            stats = person_stats[pid]
            given = stats["given"]
            taken = stats["taken"]
            net = round(given - taken, 2)
            
            if net > 0:
                status = "TO_RECEIVE"  # Lena Hai
            elif net < 0:
                status = "TO_PAY"      # Dena Hai
            else:
                status = "SETTLED"     # Hisab Barabar
                
            result.append(
                PersonWithBalanceResponse(
                    id=pid,
                    name=p.get("name"),
                    phone=p.get("phone"),
                    notes=p.get("notes"),
                    user_id=p.get("user_id"),
                    created_at=p.get("created_at"),
                    total_given=round(given, 2),
                    total_taken=round(taken, 2),
                    net_balance=net,
                    status=status,
                    transaction_count=stats["count"]
                )
            )
            
        return result

    @staticmethod
    def calculate_dashboard_summary(user_id: Optional[str] = None) -> DashboardSummary:
        """Calculates global Len-Den net position, category charts, and trends."""
        client = get_supabase()
        
        # 1. Person Balances
        person_balances = LedgerService.calculate_person_balances(user_id)
        total_receivable = sum(p.net_balance for p in person_balances if p.net_balance > 0)
        total_payable = sum(abs(p.net_balance) for p in person_balances if p.net_balance < 0)
        net_len_den = round(total_receivable - total_payable, 2)
        
        people_to_receive = len([p for p in person_balances if p.net_balance > 0])
        people_to_pay = len([p for p in person_balances if p.net_balance < 0])
        
        # 2. All Transactions
        t_query = client.table("transactions").select(
            "id, type, amount, transaction_date, category_id"
        )
        if user_id:
            t_query = t_query.eq("user_id", user_id)
        all_transactions = t_query.execute().data or []
        
        total_income = 0.0
        total_expense = 0.0
        category_spending = defaultdict(float)
        monthly_map = defaultdict(lambda: {"income": 0.0, "expense": 0.0, "given": 0.0, "taken": 0.0})
        
        for t in all_transactions:
            amt = float(t.get("amount") or 0.0)
            t_type = t.get("type")
            t_date = t.get("transaction_date") or ""
            month_key = t_date[:7] if len(t_date) >= 7 else "Unknown"
            
            if t_type == "INCOME":
                total_income += amt
                monthly_map[month_key]["income"] += amt
            elif t_type == "EXPENSE":
                total_expense += amt
                monthly_map[month_key]["expense"] += amt
                cid = t.get("category_id") or "uncategorized"
                category_spending[cid] += amt
            elif t_type == "GIVEN":
                monthly_map[month_key]["given"] += amt
            elif t_type == "TAKEN":
                monthly_map[month_key]["taken"] += amt
                
        # 3. Categories for breakdown
        c_query = client.table("categories").select("*")
        if user_id:
            c_query = c_query.or_(f"user_id.is.null,user_id.eq.{user_id}")
        categories_dict = {c["id"]: c for c in (c_query.execute().data or [])}
        
        cat_breakdown: List[CategoryBreakdownItem] = []
        for cid, spent in category_spending.items():
            cat = categories_dict.get(cid)
            name = cat["name"] if cat else "Other / Uncategorized"
            color = cat.get("color", "#9CA3AF") if cat else "#9CA3AF"
            pct = round((spent / total_expense * 100), 1) if total_expense > 0 else 0.0
            cat_breakdown.append(
                CategoryBreakdownItem(
                    category_id=cid if cid != "uncategorized" else None,
                    category_name=name,
                    color=color,
                    total_amount=round(spent, 2),
                    percentage=pct
                )
            )
        cat_breakdown.sort(key=lambda x: x.total_amount, reverse=True)
        
        # 4. Top Debtors (Jinse lene hain) & Top Creditors (Jinko dene hain)
        top_debtors = [
            PersonBalanceSummary(
                person_id=p.id,
                name=p.name,
                total_given=p.total_given,
                total_taken=p.total_taken,
                net_balance=p.net_balance,
                status=p.status
            )
            for p in sorted(person_balances, key=lambda x: x.net_balance, reverse=True)
            if p.net_balance > 0
        ][:5]
        
        top_creditors = [
            PersonBalanceSummary(
                person_id=p.id,
                name=p.name,
                total_given=p.total_given,
                total_taken=p.total_taken,
                net_balance=abs(p.net_balance),
                status=p.status
            )
            for p in sorted(person_balances, key=lambda x: x.net_balance)
            if p.net_balance < 0
        ][:5]
        
        # 5. Monthly Trends
        monthly_trends = [
            MonthlyTrendItem(
                month=m,
                total_income=round(vals["income"], 2),
                total_expense=round(vals["expense"], 2),
                total_given=round(vals["given"], 2),
                total_taken=round(vals["taken"], 2)
            )
            for m, vals in sorted(monthly_map.items())
            if m != "Unknown"
        ]
        
        return DashboardSummary(
            total_receivable=round(total_receivable, 2),
            total_payable=round(total_payable, 2),
            net_len_den_position=net_len_den,
            total_income=round(total_income, 2),
            total_expense=round(total_expense, 2),
            net_savings=round(total_income - total_expense, 2),
            people_to_receive_from_count=people_to_receive,
            people_to_pay_to_count=people_to_pay,
            total_transactions_count=len(all_transactions),
            category_breakdown=cat_breakdown,
            top_debtors=top_debtors,
            top_creditors=top_creditors,
            monthly_trends=monthly_trends
        )
