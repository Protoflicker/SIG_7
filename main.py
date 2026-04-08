from fastapi import FastAPI
from contextlib import asynccontextmanager
from database import get_pool, close_pool
from routers import fasilitas

@asynccontextmanager
async def lifespan(app: FastAPI):
    await get_pool()
    yield
    await close_pool()

app = FastAPI(title="WebGIS API", lifespan=lifespan)
app.include_router(fasilitas.router)