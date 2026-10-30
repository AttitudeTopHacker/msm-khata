from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.routers import persons, categories, transactions, stats, filters, auth, backup, reports

app = FastAPI(
    title=f"{settings.PROJECT_NAME} API",
    description="Personal financial ledger & tracker backend (msm.movin)",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS for cross-platform clients (Flutter, Web, React)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API v1 Routers
app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(persons.router, prefix=settings.API_V1_PREFIX)
app.include_router(categories.router, prefix=settings.API_V1_PREFIX)
app.include_router(transactions.router, prefix=settings.API_V1_PREFIX)
app.include_router(stats.router, prefix=settings.API_V1_PREFIX)
app.include_router(filters.router, prefix=settings.API_V1_PREFIX)
app.include_router(backup.router, prefix=settings.API_V1_PREFIX)
app.include_router(reports.router, prefix=settings.API_V1_PREFIX)

from fastapi.responses import HTMLResponse

@app.get("/", response_class=HTMLResponse)
def read_root():
    return """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>msm-khata — Financial Ledger & Tracker</title>
    <link rel="icon" href="https://raw.githubusercontent.com/AttitudeTopHacker/msm-khata/main/msmkhata_app/assets/icon.png">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: #0B0F19; color: #F8FAFC; min-height: 100vh; display: flex; flex-direction: column; justify-content: space-between; }
        .container { max-width: 860px; margin: 0 auto; padding: 48px 24px; }
        header { display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #1E293B; padding-bottom: 24px; margin-bottom: 40px; }
        .logo-box { display: flex; align-items: center; gap: 14px; }
        .logo-badge { width: 44px; height: 44px; border-radius: 12px; background: linear-gradient(135deg, #4F46E5, #3B82F6); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 18px; color: #fff; box-shadow: 0 8px 20px rgba(79, 70, 229, 0.35); }
        h1 { font-size: 26px; font-weight: 800; letter-spacing: -0.5px; }
        .tagline { color: #94A3B8; font-size: 13px; margin-top: 3px; }
        .hero { background: #131B2E; border: 1px solid #1E293B; border-radius: 20px; padding: 36px; margin-bottom: 32px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
        .hero h2 { font-size: 22px; color: #818CF8; margin-bottom: 12px; }
        .hero p { color: #CBD5E1; font-size: 15px; line-height: 1.7; margin-bottom: 24px; }
        .features { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 18px; margin-top: 24px; }
        .feature-card { background: #0F172A; border: 1px solid #1E293B; border-radius: 14px; padding: 20px; }
        .feature-card h3 { font-size: 15px; color: #38BDF8; margin-bottom: 6px; }
        .feature-card p { font-size: 13px; color: #94A3B8; line-height: 1.5; }
        .btn-group { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 28px; }
        .btn { display: inline-flex; align-items: center; padding: 10px 20px; border-radius: 10px; font-size: 13px; font-weight: 600; text-decoration: none; transition: all 0.2s; }
        .btn-primary { background: #4F46E5; color: #fff; }
        .btn-primary:hover { background: #4338CA; }
        .btn-secondary { background: #1E293B; color: #E2E8F0; border: 1px solid #334155; }
        .btn-secondary:hover { background: #334155; }
        footer { border-top: 1px solid #1E293B; padding: 28px 24px; text-align: center; color: #64748B; font-size: 13px; }
        footer a { color: #818CF8; text-decoration: none; margin: 0 10px; }
        footer a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo-box">
                <div class="logo-badge">MK</div>
                <div>
                    <h1>msm-khata</h1>
                    <div class="tagline">Financial Ledger &amp; Len-Den Tracker • By Salman (msm.movin)</div>
                </div>
            </div>
            <div>
                <a href="/privacy" class="btn btn-secondary">Privacy Policy</a>
            </div>
        </header>

        <main>
            <div class="hero">
                <h2>Welcome to msm-khata</h2>
                <p>
                    <strong>msm-khata</strong> is a personal financial ledger and smart debt/credit (Lena Hai vs Dena Hai) management platform. It helps individuals and small businesses track cash flows, borrower/lender balances, automated financial summaries, and secure cloud backups.
                </p>
                <div class="btn-group">
                    <a href="/privacy" class="btn btn-primary">Read Privacy Policy</a>
                    <a href="/terms" class="btn btn-secondary">Terms of Service</a>
                    <a href="/docs" class="btn btn-secondary">API Swagger Docs</a>
                    <a href="https://github.com/AttitudeTopHacker/msm-khata" target="_blank" class="btn btn-secondary">GitHub Repository</a>
                </div>
            </div>

            <div class="features">
                <div class="feature-card">
                    <h3>📊 Len-Den &amp; Smart Ledger</h3>
                    <p>Track who owes you money and who you owe, with real-time balance calculations and visual trend charts.</p>
                </div>
                <div class="feature-card">
                    <h3>🔒 Privacy &amp; Security First</h3>
                    <p>End-to-end user isolation with Supabase Cloud Row-Level Security (RLS). Your data belongs strictly to you.</p>
                </div>
                <div class="feature-card">
                    <h3>☁️ Google Drive Backup</h3>
                    <p>Export your records as JSON, Excel, and PDF directly into your personal Google Drive folder for safe archival.</p>
                </div>
            </div>
        </main>
    </div>

    <footer>
        <p>&copy; 2026 msm-khata • Engineered by Salman (msm.movin 2022)</p>
        <p style="margin-top: 8px;">
            <a href="/">Home</a> |
            <a href="/privacy">Privacy Policy</a> |
            <a href="/terms">Terms of Service</a> |
            <a href="mailto:mohdsalman4151@gmail.com">Contact Developer</a>
        </p>
    </footer>
</body>
</html>"""

@app.get("/privacy", response_class=HTMLResponse)
def read_privacy_policy():
    return """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy — msm-khata</title>
    <link rel="icon" href="https://raw.githubusercontent.com/AttitudeTopHacker/msm-khata/main/msmkhata_app/assets/icon.png">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: #0B0F19; color: #F8FAFC; min-height: 100vh; display: flex; flex-direction: column; justify-content: space-between; }
        .container { max-width: 860px; margin: 0 auto; padding: 48px 24px; }
        header { display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #1E293B; padding-bottom: 20px; margin-bottom: 32px; }
        .logo-box { display: flex; align-items: center; gap: 12px; }
        .logo-badge { width: 38px; height: 38px; border-radius: 10px; background: linear-gradient(135deg, #4F46E5, #3B82F6); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 16px; color: #fff; }
        h1 { font-size: 22px; font-weight: 800; }
        .back-link { color: #818CF8; text-decoration: none; font-size: 14px; font-weight: 600; }
        .back-link:hover { text-decoration: underline; }
        .content { background: #131B2E; border: 1px solid #1E293B; border-radius: 18px; padding: 36px; line-height: 1.8; color: #CBD5E1; font-size: 14.5px; }
        .content h2 { color: #F1F5F9; font-size: 18px; margin: 26px 0 10px 0; border-left: 3px solid #6366F1; padding-left: 10px; }
        .content h2:first-of-type { margin-top: 0; }
        .content p { margin-bottom: 16px; }
        .content ul { margin: 0 0 18px 24px; }
        .content li { margin-bottom: 8px; }
        .effective-date { color: #94A3B8; font-size: 13px; margin-bottom: 20px; }
        footer { border-top: 1px solid #1E293B; padding: 24px; text-align: center; color: #64748B; font-size: 13px; }
        footer a { color: #818CF8; text-decoration: none; margin: 0 10px; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo-box">
                <div class="logo-badge">MK</div>
                <h1>msm-khata Privacy Policy</h1>
            </div>
            <a href="/" class="back-link">&larr; Back to Home</a>
        </header>

        <div class="content">
            <div class="effective-date">Last Updated: October 30, 2026</div>

            <h2>1. Introduction</h2>
            <p>Welcome to <strong>msm-khata</strong> (&ldquo;we&rdquo;, &ldquo;our&rdquo;, or &ldquo;app&rdquo;), engineered by Salman (msm.movin). This Privacy Policy explains how our personal financial tracking application collects, uses, and safeguards your information when you access or use msm-khata across web, desktop, and mobile platforms.</p>

            <h2>2. Information We Collect</h2>
            <p>We only collect information strictly required to provide and maintain your financial ledger:</p>
            <ul>
                <li><strong>Account Authentication:</strong> When you sign in via Google OAuth, GitHub, or Email/Password, we receive your email address, display name, and unique user ID provided by Supabase Auth and Google.</li>
                <li><strong>Financial Ledger Data:</strong> Transactions, debtor/creditor names, transaction amounts, categories, dates, and payment notes that you voluntarily input into the ledger.</li>
            </ul>

            <h2>3. Google User Data Policy &amp; Drive Integration</h2>
            <p>msm-khata strictly complies with the <a href="https://developers.google.com/terms/api-services-user-data-policy" target="_blank" style="color: #38BDF8;">Google API Services User Data Policy</a>:</p>
            <ul>
                <li><strong>Google Sign-In:</strong> Used solely to authenticate your identity and link your encrypted ledger session. We request only basic profile information (email and name).</li>
                <li><strong>Google Drive Permissions (Optional):</strong> If you choose to enable cloud backups, msm-khata utilizes the restricted <code>drive.file</code> scope exclusively to create and update an archival backup folder named <code>MsmKhata_Backups</code> on your personal Google Drive.</li>
                <li><strong>Zero Data Selling:</strong> We do not sell, rent, or transfer your Google user data or financial transactions to third parties, advertisers, or data brokers.</li>
                <li><strong>Zero AI Training:</strong> Your private financial ledger and Google data are never used to train generalized artificial intelligence or machine learning models.</li>
            </ul>

            <h2>4. Data Storage &amp; Security</h2>
            <p>All financial records are stored securely in Supabase Cloud with PostgreSQL Row-Level Security (RLS) enabled. Each user can only read, write, or modify their own entries. All transmissions are encrypted using industry-standard TLS/SSL encryption.</p>

            <h2>5. Data Deletion &amp; User Control</h2>
            <p>You have full ownership of your data at all times. You can delete individual transactions or reset your account directly within the application settings. For permanent account or data deletion requests, you may contact the developer directly.</p>

            <h2>6. Contact Us</h2>
            <p>If you have any questions, feedback, or concerns regarding this Privacy Policy or your data, please contact:</p>
            <p><strong>Developer:</strong> Mohammad Salman (AttitudeTopHacker / msm.movin)<br>
            <strong>Email:</strong> <a href="mailto:mohdsalman4151@gmail.com" style="color: #38BDF8;">mohdsalman4151@gmail.com</a><br>
            <strong>Project Repository:</strong> <a href="https://github.com/AttitudeTopHacker/msm-khata" target="_blank" style="color: #38BDF8;">https://github.com/AttitudeTopHacker/msm-khata</a></p>
        </div>
    </div>

    <footer>
        <p>&copy; 2026 msm-khata • <a href="/">Home</a> • <a href="/privacy">Privacy Policy</a> • <a href="/terms">Terms of Service</a></p>
    </footer>
</body>
</html>"""

@app.get("/terms", response_class=HTMLResponse)
def read_terms_of_service():
    return """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Service — msm-khata</title>
    <link rel="icon" href="https://raw.githubusercontent.com/AttitudeTopHacker/msm-khata/main/msmkhata_app/assets/icon.png">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: #0B0F19; color: #F8FAFC; min-height: 100vh; display: flex; flex-direction: column; justify-content: space-between; }
        .container { max-width: 860px; margin: 0 auto; padding: 48px 24px; }
        header { display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #1E293B; padding-bottom: 20px; margin-bottom: 32px; }
        .logo-box { display: flex; align-items: center; gap: 12px; }
        .logo-badge { width: 38px; height: 38px; border-radius: 10px; background: linear-gradient(135deg, #4F46E5, #3B82F6); display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 16px; color: #fff; }
        h1 { font-size: 22px; font-weight: 800; }
        .back-link { color: #818CF8; text-decoration: none; font-size: 14px; font-weight: 600; }
        .content { background: #131B2E; border: 1px solid #1E293B; border-radius: 18px; padding: 36px; line-height: 1.8; color: #CBD5E1; font-size: 14.5px; }
        .content h2 { color: #F1F5F9; font-size: 18px; margin: 26px 0 10px 0; border-left: 3px solid #6366F1; padding-left: 10px; }
        .content h2:first-of-type { margin-top: 0; }
        .content p { margin-bottom: 16px; }
        footer { border-top: 1px solid #1E293B; padding: 24px; text-align: center; color: #64748B; font-size: 13px; }
        footer a { color: #818CF8; text-decoration: none; margin: 0 10px; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo-box">
                <div class="logo-badge">MK</div>
                <h1>msm-khata Terms of Service</h1>
            </div>
            <a href="/" class="back-link">&larr; Back to Home</a>
        </header>

        <div class="content">
            <h2>1. Acceptance of Terms</h2>
            <p>By using msm-khata, you agree to these Terms of Service. If you do not agree, please do not use the application.</p>

            <h2>2. Purpose of the Application</h2>
            <p>msm-khata is intended as a personal tool for recording and tracking financial transactions, credits, and debits. It does not provide licensed banking, tax, or legal financial advice.</p>

            <h2>3. Account Responsibility</h2>
            <p>You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account.</p>

            <h2>4. Changes to Terms</h2>
            <p>We may update these terms occasionally. Continued use of the service constitutes acceptance of any revised terms.</p>
        </div>
    </div>

    <footer>
        <p>&copy; 2026 msm-khata • <a href="/">Home</a> • <a href="/privacy">Privacy Policy</a> • <a href="/terms">Terms of Service</a></p>
    </footer>
</body>
</html>"""

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=True)
