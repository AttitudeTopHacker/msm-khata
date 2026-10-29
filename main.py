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

@app.get("/")
def read_root():
    return {
        "project": settings.PROJECT_NAME,
        "organization": "msm.movin",
        "status": "online",
        "documentation": "/docs",
        "version": "1.0.0"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=True)
