import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.recommendations import router as recommendations_router
from routers.users import router as users_router
from routers.insights import router as insights_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

logger = logging.getLogger(__name__)

app = FastAPI(
    title="StackSense Backend",
    description="Evidenzbasierte Supplement-Empfehlungen via Claude AI",
    version="2.0.0",
)

# CORS — Flutter App darf auf die API zugreifen
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In Produktion auf App-Domain einschränken
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(recommendations_router)
app.include_router(users_router)
app.include_router(insights_router)


@app.on_event("startup")
async def startup_event():
    """Datenbank-Tabellen beim Start initialisieren."""
    try:
        from database.db import init_user_tables, init_community_tables
        init_user_tables()
        init_community_tables()
    except Exception as e:
        logger.warning("DB-Init beim Start fehlgeschlagen (wird ignoriert): %s", e)


@app.get("/")
async def root():
    return {"message": "StackSense Backend läuft", "docs": "/docs", "version": "2.0.0"}
