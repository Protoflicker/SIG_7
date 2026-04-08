from fastapi import APIRouter, HTTPException
from database import get_pool
from models import FasilitasCreate
import json

router = APIRouter(prefix="/api/fasilitas", tags=["Fasilitas"])

# 1. GET All
@router.get("/")
async def get_all_fasilitas():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT id, nama, jenis, ST_AsGeoJSON(geom) as geom FROM fasilitas LIMIT 100")
        return [dict(row) for row in rows]

# 2. GET GeoJSON (Wajib Format FeatureCollection)
@router.get("/geojson")
async def get_fasilitas_geojson():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT id, nama, jenis, ST_AsGeoJSON(geom) as geom FROM fasilitas")
        features = [{
            "type": "Feature",
            "geometry": json.loads(row["geom"]),
            "properties": {"id": row["id"], "nama": row["nama"], "jenis": row["jenis"]}
        } for row in rows]
        return {"type": "FeatureCollection", "features": features}

# 3. GET Nearby (Query Spasial Radius)
@router.get("/nearby")
async def get_nearby(lat: float, lon: float, radius: int = 1000):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT id, nama, jenis, ROUND(ST_Distance(geom::geography, ST_Point($1, $2)::geography)::numeric) as jarak_m
            FROM fasilitas WHERE ST_DWithin(geom::geography, ST_Point($1, $2)::geography, $3) ORDER BY jarak_m
        """, lon, lat, radius)
        return [dict(row) for row in rows]

# 4. GET by ID
@router.get("/{id}")
async def get_fasilitas_by_id(id: int):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow("SELECT id, nama, jenis, alamat, ST_X(geom) as longitude, ST_Y(geom) as latitude FROM fasilitas WHERE id = $1", id)
        if not row:
            raise HTTPException(status_code=404, detail="Fasilitas tidak ditemukan")
        return dict(row)

# 5. POST (Input Data Spasial)
@router.post("/", status_code=201)
async def create_fasilitas(data: FasilitasCreate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow("""
            INSERT INTO fasilitas (nama, jenis, alamat, geom)
            VALUES ($1, $2, $3, ST_SetSRID(ST_Point($4, $5), 4326))
            RETURNING id, nama, jenis, alamat, ST_X(geom) as longitude, ST_Y(geom) as latitude
        """, data.nama, data.jenis, data.alamat, data.longitude, data.latitude)
        return dict(row)