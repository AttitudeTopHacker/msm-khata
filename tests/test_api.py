from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_api():
    print("Testing / health and root...")
    r = client.get("/")
    assert r.status_code == 200, f"Root failed: {r.text}"
    print("Root response preview:", r.text[:100])
    
    # 1. Test Persons
    print("\nTesting /api/v1/persons...")
    r = client.get("/api/v1/persons")
    assert r.status_code == 200, f"Get persons failed: {r.text}"
    print(f"Persons count: {len(r.json())}")
    
    # 2. Test On-The-Fly Transaction Creation
    import time
    unique_name = f"Test Person {int(time.time())}"
    print(f"\nTesting on-the-fly transaction creation for {unique_name}...")
    payload = {
        "type": "GIVEN",
        "amount": 1500.0,
        "payment_mode": "UPI",
        "person_name": unique_name,
        "notes": "Testing len-den entry",
        "account_id": "main",
        "account_name": "Main Account"
    }
    r = client.post("/api/v1/transactions", json=payload)
    assert r.status_code == 201, f"Create transaction failed: {r.text}"
    t_data = r.json()
    t_id = t_data["id"]
    p_id = t_data["person_id"]
    print(f"Created transaction: {t_id}, Person: {t_data['person_name']} ({p_id}), Account: {t_data['account_id']}")
    assert t_data["account_id"] == "main"
    
    # 3. Verify Person Balance
    print(f"\nChecking person balance for {unique_name}...")
    r = client.get(f"/api/v1/persons/{p_id}")
    assert r.status_code == 200, f"Get person balance failed: {r.text}"
    p_info = r.json()
    print(f"Person Net Balance: {p_info['net_balance']} (Status: {p_info['status']})")
    assert p_info["net_balance"] == 1500.0
    assert p_info["status"] == "TO_RECEIVE"
    
    # 4. Test Dashboard Stats
    print("\nTesting /api/v1/stats/summary...")
    r = client.get("/api/v1/stats/summary")
    assert r.status_code == 200, f"Stats failed: {r.text}"
    stats_data = r.json()
    print("Stats summary:")
    print(f"  Total Receivable (Lena Hai): {stats_data['total_receivable']}")
    print(f"  Total Payable (Dena Hai): {stats_data['total_payable']}")
    print(f"  Net Position: {stats_data['net_len_den_position']}")
    
    # 5. Test Backup Exports (JSON & CSV)
    print("\nTesting /api/v1/backup/export/json...")
    r = client.get("/api/v1/backup/export/json")
    assert r.status_code == 200, f"JSON backup failed: {r.text}"
    backup_json = r.json()
    assert "metadata" in backup_json and backup_json["metadata"]["app"] == "MsmKhata"
    assert "transactions" in backup_json
    print(f"JSON backup generated successfully ({len(backup_json['transactions'])} transactions)")
    
    print("\nTesting /api/v1/backup/export/csv...")
    r = client.get("/api/v1/backup/export/csv")
    assert r.status_code == 200, f"CSV backup failed: {r.text}"
    assert "Transaction ID,Date,Type" in r.text
    print("CSV backup spreadsheet generated successfully!")

    # 6. Test Python Professional PDF & Excel Report Engine
    print("\nTesting /api/v1/reports/pdf...")
    r_pdf = client.get("/api/v1/reports/pdf?account_id=main&account_name=Main%20Account")
    assert r_pdf.status_code == 200, f"PDF report failed: {r_pdf.text}"
    assert r_pdf.headers.get("content-type") == "application/pdf"
    assert len(r_pdf.content) > 1000
    print(f"Professional PDF report generated successfully ({len(r_pdf.content):,} bytes, with embedded charts)")

    print("\nTesting /api/v1/reports/excel...")
    r_excel = client.get("/api/v1/reports/excel?account_id=main&account_name=Main%20Account")
    assert r_excel.status_code == 200, f"Excel report failed: {r_excel.text}"
    assert "openxmlformats" in r_excel.headers.get("content-type", "")
    assert len(r_excel.content) > 1000
    print(f"Professional Multi-Tab Excel Workbook generated successfully ({len(r_excel.content):,} bytes)")
    
    # 7. Cleanup Test Data
    print("\nCleaning up test transaction & person...")
    client.delete(f"/api/v1/transactions/{t_id}")
    client.delete(f"/api/v1/persons/{p_id}")
    print("Cleanup complete!")
    print("\n ALL TESTS PASSED SUCCESSFULLY! ")

if __name__ == "__main__":
    test_api()
