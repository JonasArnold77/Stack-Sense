import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.recommendations import router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

app = FastAPI(
    title="StackSense Backend",
    description="Evidenzbasierte Supplement-Empfehlungen via Claude AI",
    version="1.0.0",
)

# CORS — Flutter App darf auf die API zugreifen
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In Produktion auf App-Domain einschränken
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/")
async def root():
    return {"message": "StackSense Backend läuft", "docs": "/docs"}
