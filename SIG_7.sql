--
-- PostgreSQL database dump
--

\restrict fEmzhknm8G8tKger8ipkndeeqgih86f275v27tKrMlAhFPgIi0Ey4OhSegkdwkb

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pertanian; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA pertanian;


ALTER SCHEMA pertanian OWNER TO postgres;

--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA topology;


ALTER SCHEMA topology OWNER TO postgres;

--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: transportasi; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA transportasi;


ALTER SCHEMA transportasi OWNER TO postgres;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: cari_kios_terdekat(double precision, double precision, integer); Type: FUNCTION; Schema: pertanian; Owner: postgres
--

CREATE FUNCTION pertanian.cari_kios_terdekat(p_lon double precision, p_lat double precision, p_limit integer DEFAULT 3) RETURNS TABLE(id integer, nama_kios character varying, jenis_pupuk text[], kuota_ton numeric, jarak_meter numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        k.id,
        k.nama_kios,
        k.jenis_pupuk,
        k.kuota_ton,
        ROUND(ST_Distance(k.geom::geography, ST_SetSRID(ST_Point(p_lon, p_lat), 4326)::geography)::numeric, 2)
    FROM pertanian.kios_pupuk k
    WHERE k.aktif = TRUE
    ORDER BY k.geom <-> ST_SetSRID(ST_Point(p_lon, p_lat), 4326)
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION pertanian.cari_kios_terdekat(p_lon double precision, p_lat double precision, p_limit integer) OWNER TO postgres;

--
-- Name: cari_halte_radius(double precision, double precision, integer); Type: FUNCTION; Schema: transportasi; Owner: postgres
--

CREATE FUNCTION transportasi.cari_halte_radius(p_lon double precision, p_lat double precision, p_radius integer DEFAULT 1000) RETURNS TABLE(id integer, nama character varying, jenis character varying, jarak_meter numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.id,
        h.nama,
        h.jenis,
        ROUND(ST_Distance(h.geom::geography, ST_SetSRID(ST_Point(p_lon, p_lat), 4326)::geography)::numeric, 2)
    FROM transportasi.halte h
    WHERE ST_DWithin(h.geom::geography, ST_SetSRID(ST_Point(p_lon, p_lat), 4326)::geography, p_radius)
      AND h.aktif = TRUE
    ORDER BY h.geom <-> ST_SetSRID(ST_Point(p_lon, p_lat), 4326);
END;
$$;


ALTER FUNCTION transportasi.cari_halte_radius(p_lon double precision, p_lat double precision, p_radius integer) OWNER TO postgres;

--
-- Name: get_halte_geojson(character varying); Type: FUNCTION; Schema: transportasi; Owner: postgres
--

CREATE FUNCTION transportasi.get_halte_geojson(p_jenis character varying DEFAULT NULL::character varying) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'type', 'FeatureCollection',
            'features', COALESCE(jsonb_agg(
                jsonb_build_object(
                    'type', 'Feature',
                    'geometry', ST_AsGeoJSON(geom)::jsonb,
                    'properties', jsonb_build_object(
                        'id', id,
                        'nama', nama,
                        'kode', kode,
                        'jenis', jenis,
                        'kapasitas', kapasitas
                    )
                )
            ), '[]'::jsonb)
        )
        FROM transportasi.halte
        WHERE aktif = TRUE
          AND (p_jenis IS NULL OR jenis = p_jenis)
    );
END;
$$;


ALTER FUNCTION transportasi.get_halte_geojson(p_jenis character varying) OWNER TO postgres;

--
-- Name: statistik_wilayah(integer); Type: FUNCTION; Schema: transportasi; Owner: postgres
--

CREATE FUNCTION transportasi.statistik_wilayah(p_wilayah_id integer) RETURNS TABLE(nama_wilayah character varying, luas_km2 numeric, jumlah_halte bigint, jumlah_parkir bigint, jumlah_kecelakaan bigint, total_korban bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.nama,
        w.luas_km2,
        (SELECT COUNT(*) FROM transportasi.halte h WHERE ST_Within(h.geom, w.geom) AND h.aktif = TRUE),
        (SELECT COUNT(*) FROM transportasi.parkir p WHERE ST_Within(p.geom, w.geom)),
        (SELECT COUNT(*) FROM transportasi.kecelakaan k WHERE ST_Within(k.geom, w.geom)),
        (SELECT COALESCE(SUM(k.jumlah_korban), 0) FROM transportasi.kecelakaan k WHERE ST_Within(k.geom, w.geom))
    FROM transportasi.wilayah w
    WHERE w.id = p_wilayah_id;
END;
$$;


ALTER FUNCTION transportasi.statistik_wilayah(p_wilayah_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: deteksi_objek; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.deteksi_objek (
    id integer NOT NULL,
    citra_sumber character varying(255),
    tanggal_deteksi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    model_digunakan character varying(50),
    kelas_objek character varying(50),
    confidence numeric(5,4),
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.deteksi_objek OWNER TO postgres;

--
-- Name: deteksi_objek_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.deteksi_objek_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.deteksi_objek_id_seq OWNER TO postgres;

--
-- Name: deteksi_objek_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.deteksi_objek_id_seq OWNED BY pertanian.deteksi_objek.id;


--
-- Name: hama_penyakit; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.hama_penyakit (
    id integer NOT NULL,
    tanggal_kejadian date NOT NULL,
    jenis character varying(50),
    nama_hama_penyakit character varying(100),
    tingkat_serangan character varying(20),
    luas_terdampak_ha numeric(10,2),
    tanaman_terdampak character varying(50),
    tindakan text,
    status character varying(20) DEFAULT 'aktif'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.hama_penyakit OWNER TO postgres;

--
-- Name: hama_penyakit_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.hama_penyakit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.hama_penyakit_id_seq OWNER TO postgres;

--
-- Name: hama_penyakit_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.hama_penyakit_id_seq OWNED BY pertanian.hama_penyakit.id;


--
-- Name: irigasi; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.irigasi (
    id integer NOT NULL,
    nama_saluran character varying(100),
    jenis character varying(50),
    panjang_km numeric(10,2),
    lebar_m numeric(5,2),
    kondisi character varying(50),
    tahun_bangun integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(LineString,4326)
);


ALTER TABLE pertanian.irigasi OWNER TO postgres;

--
-- Name: irigasi_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.irigasi_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.irigasi_id_seq OWNER TO postgres;

--
-- Name: irigasi_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.irigasi_id_seq OWNED BY pertanian.irigasi.id;


--
-- Name: kelompok_tani; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.kelompok_tani (
    id integer NOT NULL,
    nama_kelompok character varying(100) NOT NULL,
    ketua character varying(100),
    jumlah_anggota integer,
    desa character varying(100),
    kecamatan character varying(100),
    total_lahan_ha numeric(10,2),
    komoditas_utama character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.kelompok_tani OWNER TO postgres;

--
-- Name: kelompok_tani_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.kelompok_tani_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.kelompok_tani_id_seq OWNER TO postgres;

--
-- Name: kelompok_tani_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.kelompok_tani_id_seq OWNED BY pertanian.kelompok_tani.id;


--
-- Name: kios_pupuk; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.kios_pupuk (
    id integer NOT NULL,
    nama_kios character varying(100) NOT NULL,
    pemilik character varying(100),
    no_izin character varying(50),
    alamat text,
    telepon character varying(20),
    jenis_pupuk text[],
    kuota_ton numeric(10,2),
    radius_layanan_km numeric(5,2) DEFAULT 5.0,
    aktif boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE pertanian.kios_pupuk OWNER TO postgres;

--
-- Name: kios_pupuk_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.kios_pupuk_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.kios_pupuk_id_seq OWNER TO postgres;

--
-- Name: kios_pupuk_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.kios_pupuk_id_seq OWNED BY pertanian.kios_pupuk.id;


--
-- Name: lahan; Type: TABLE; Schema: pertanian; Owner: postgres
--

CREATE TABLE pertanian.lahan (
    id integer NOT NULL,
    kode_lahan character varying(20),
    nama_pemilik character varying(100),
    nik_pemilik character varying(20),
    jenis_tanaman character varying(50),
    luas_hektar numeric(10,2),
    status_kepemilikan character varying(50),
    tahun_tanam integer,
    produktivitas_ton_per_ha numeric(10,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Polygon,4326)
);


ALTER TABLE pertanian.lahan OWNER TO postgres;

--
-- Name: lahan_id_seq; Type: SEQUENCE; Schema: pertanian; Owner: postgres
--

CREATE SEQUENCE pertanian.lahan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE pertanian.lahan_id_seq OWNER TO postgres;

--
-- Name: lahan_id_seq; Type: SEQUENCE OWNED BY; Schema: pertanian; Owner: postgres
--

ALTER SEQUENCE pertanian.lahan_id_seq OWNED BY pertanian.lahan.id;


--
-- Name: v_lahan_kios; Type: VIEW; Schema: pertanian; Owner: postgres
--

CREATE VIEW pertanian.v_lahan_kios AS
 SELECT l.id,
    l.kode_lahan,
    l.nama_pemilik,
    l.jenis_tanaman,
    l.luas_hektar,
    l.produktivitas_ton_per_ha,
    (l.luas_hektar * COALESCE(l.produktivitas_ton_per_ha, (0)::numeric)) AS estimasi_produksi_ton,
    kp.nama_kios AS kios_terdekat,
    round((public.st_distance((public.st_centroid(l.geom))::public.geography, (kp.geom)::public.geography))::numeric, 2) AS jarak_ke_kios_m
   FROM (pertanian.lahan l
     CROSS JOIN LATERAL ( SELECT kios_pupuk.nama_kios,
            kios_pupuk.geom
           FROM pertanian.kios_pupuk
          WHERE (kios_pupuk.aktif = true)
          ORDER BY (kios_pupuk.geom OPERATOR(public.<->) public.st_centroid(l.geom))
         LIMIT 1) kp);


ALTER VIEW pertanian.v_lahan_kios OWNER TO postgres;

--
-- Name: v_statistik_hama; Type: VIEW; Schema: pertanian; Owner: postgres
--

CREATE VIEW pertanian.v_statistik_hama AS
 SELECT tanaman_terdampak,
    jenis,
    count(*) AS jumlah_kejadian,
    sum(luas_terdampak_ha) AS total_luas_terdampak_ha,
    count(*) FILTER (WHERE ((status)::text = 'aktif'::text)) AS masih_aktif,
    count(*) FILTER (WHERE ((tingkat_serangan)::text = 'berat'::text)) AS serangan_berat
   FROM pertanian.hama_penyakit
  GROUP BY tanaman_terdampak, jenis
  ORDER BY (count(*)) DESC;


ALTER VIEW pertanian.v_statistik_hama OWNER TO postgres;

--
-- Name: fasilitas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fasilitas (
    id integer NOT NULL,
    nama character varying(100),
    jenis character varying(50),
    alamat text,
    geom public.geometry(Point,4326)
);


ALTER TABLE public.fasilitas OWNER TO postgres;

--
-- Name: fasilitas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fasilitas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fasilitas_id_seq OWNER TO postgres;

--
-- Name: fasilitas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fasilitas_id_seq OWNED BY public.fasilitas.id;


--
-- Name: jalan; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jalan (
    id integer NOT NULL,
    nama character varying(100),
    geom public.geometry(LineString,4326)
);


ALTER TABLE public.jalan OWNER TO postgres;

--
-- Name: jalan_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.jalan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.jalan_id_seq OWNER TO postgres;

--
-- Name: jalan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.jalan_id_seq OWNED BY public.jalan.id;


--
-- Name: wilayah; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wilayah (
    id integer NOT NULL,
    nama character varying(100),
    geom public.geometry(Polygon,4326)
);


ALTER TABLE public.wilayah OWNER TO postgres;

--
-- Name: wilayah_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.wilayah_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wilayah_id_seq OWNER TO postgres;

--
-- Name: wilayah_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.wilayah_id_seq OWNED BY public.wilayah.id;


--
-- Name: halte; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.halte (
    id integer NOT NULL,
    nama character varying(100) NOT NULL,
    kode character varying(20),
    jenis character varying(50),
    alamat text,
    kapasitas integer,
    fasilitas text[],
    jam_operasi_mulai time without time zone,
    jam_operasi_selesai time without time zone,
    aktif boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE transportasi.halte OWNER TO postgres;

--
-- Name: halte_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.halte_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.halte_id_seq OWNER TO postgres;

--
-- Name: halte_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.halte_id_seq OWNED BY transportasi.halte.id;


--
-- Name: kecelakaan; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.kecelakaan (
    id integer NOT NULL,
    tanggal date NOT NULL,
    waktu time without time zone,
    jenis_kecelakaan character varying(50),
    jumlah_korban integer DEFAULT 0,
    jumlah_kendaraan integer DEFAULT 1,
    penyebab text,
    kondisi_jalan character varying(50),
    kondisi_cuaca character varying(50),
    keterangan text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE transportasi.kecelakaan OWNER TO postgres;

--
-- Name: kecelakaan_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.kecelakaan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.kecelakaan_id_seq OWNER TO postgres;

--
-- Name: kecelakaan_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.kecelakaan_id_seq OWNED BY transportasi.kecelakaan.id;


--
-- Name: parkir; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.parkir (
    id integer NOT NULL,
    nama character varying(100) NOT NULL,
    jenis character varying(50),
    kapasitas integer,
    tarif_per_jam integer,
    jam_buka time without time zone,
    jam_tutup time without time zone,
    pengelola character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Point,4326)
);


ALTER TABLE transportasi.parkir OWNER TO postgres;

--
-- Name: parkir_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.parkir_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.parkir_id_seq OWNER TO postgres;

--
-- Name: parkir_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.parkir_id_seq OWNED BY transportasi.parkir.id;


--
-- Name: rute; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.rute (
    id integer NOT NULL,
    kode_rute character varying(20) NOT NULL,
    nama_rute character varying(100) NOT NULL,
    jenis character varying(50),
    warna character varying(20),
    panjang_km numeric(10,2),
    estimasi_waktu_menit integer,
    tarif integer,
    aktif boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(LineString,4326)
);


ALTER TABLE transportasi.rute OWNER TO postgres;

--
-- Name: rute_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.rute_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.rute_id_seq OWNER TO postgres;

--
-- Name: rute_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.rute_id_seq OWNED BY transportasi.rute.id;


--
-- Name: tugas5_area_rawan_kecelakaan; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.tugas5_area_rawan_kecelakaan (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE transportasi.tugas5_area_rawan_kecelakaan OWNER TO postgres;

--
-- Name: tugas5_centroid_wilayah; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.tugas5_centroid_wilayah (
    id integer NOT NULL,
    nama character varying(100),
    geom public.geometry(Point,4326)
);


ALTER TABLE transportasi.tugas5_centroid_wilayah OWNER TO postgres;

--
-- Name: tugas5_tumpang_tindih; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.tugas5_tumpang_tindih (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE transportasi.tugas5_tumpang_tindih OWNER TO postgres;

--
-- Name: tugas5_zona_layanan_halte; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.tugas5_zona_layanan_halte (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE transportasi.tugas5_zona_layanan_halte OWNER TO postgres;

--
-- Name: wilayah; Type: TABLE; Schema: transportasi; Owner: postgres
--

CREATE TABLE transportasi.wilayah (
    id integer NOT NULL,
    kode_wilayah character varying(20),
    nama character varying(100) NOT NULL,
    tipe character varying(50),
    populasi integer,
    luas_km2 numeric(10,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    geom public.geometry(Polygon,4326)
);


ALTER TABLE transportasi.wilayah OWNER TO postgres;

--
-- Name: v_halte_wilayah; Type: VIEW; Schema: transportasi; Owner: postgres
--

CREATE VIEW transportasi.v_halte_wilayah AS
 SELECT h.id,
    h.nama,
    h.kode,
    h.jenis,
    h.kapasitas,
    h.fasilitas,
    w.nama AS wilayah,
    public.st_x(h.geom) AS longitude,
    public.st_y(h.geom) AS latitude,
    h.geom
   FROM (transportasi.halte h
     LEFT JOIN transportasi.wilayah w ON (public.st_within(h.geom, w.geom)))
  WHERE (h.aktif = true);


ALTER VIEW transportasi.v_halte_wilayah OWNER TO postgres;

--
-- Name: v_statistik_kecelakaan; Type: VIEW; Schema: transportasi; Owner: postgres
--

CREATE VIEW transportasi.v_statistik_kecelakaan AS
 SELECT w.nama AS wilayah,
    w.populasi,
    count(k.id) AS jumlah_kejadian,
    sum(COALESCE(k.jumlah_korban, 0)) AS total_korban,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'fatal'::text)) AS kejadian_fatal,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'berat'::text)) AS kejadian_berat,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'sedang'::text)) AS kejadian_sedang,
    count(*) FILTER (WHERE ((k.jenis_kecelakaan)::text = 'ringan'::text)) AS kejadian_ringan
   FROM (transportasi.wilayah w
     LEFT JOIN transportasi.kecelakaan k ON (public.st_within(k.geom, w.geom)))
  GROUP BY w.id, w.nama, w.populasi;


ALTER VIEW transportasi.v_statistik_kecelakaan OWNER TO postgres;

--
-- Name: wilayah_id_seq; Type: SEQUENCE; Schema: transportasi; Owner: postgres
--

CREATE SEQUENCE transportasi.wilayah_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE transportasi.wilayah_id_seq OWNER TO postgres;

--
-- Name: wilayah_id_seq; Type: SEQUENCE OWNED BY; Schema: transportasi; Owner: postgres
--

ALTER SEQUENCE transportasi.wilayah_id_seq OWNED BY transportasi.wilayah.id;


--
-- Name: deteksi_objek id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.deteksi_objek ALTER COLUMN id SET DEFAULT nextval('pertanian.deteksi_objek_id_seq'::regclass);


--
-- Name: hama_penyakit id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.hama_penyakit ALTER COLUMN id SET DEFAULT nextval('pertanian.hama_penyakit_id_seq'::regclass);


--
-- Name: irigasi id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.irigasi ALTER COLUMN id SET DEFAULT nextval('pertanian.irigasi_id_seq'::regclass);


--
-- Name: kelompok_tani id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kelompok_tani ALTER COLUMN id SET DEFAULT nextval('pertanian.kelompok_tani_id_seq'::regclass);


--
-- Name: kios_pupuk id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kios_pupuk ALTER COLUMN id SET DEFAULT nextval('pertanian.kios_pupuk_id_seq'::regclass);


--
-- Name: lahan id; Type: DEFAULT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.lahan ALTER COLUMN id SET DEFAULT nextval('pertanian.lahan_id_seq'::regclass);


--
-- Name: fasilitas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fasilitas ALTER COLUMN id SET DEFAULT nextval('public.fasilitas_id_seq'::regclass);


--
-- Name: jalan id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jalan ALTER COLUMN id SET DEFAULT nextval('public.jalan_id_seq'::regclass);


--
-- Name: wilayah id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wilayah ALTER COLUMN id SET DEFAULT nextval('public.wilayah_id_seq'::regclass);


--
-- Name: halte id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.halte ALTER COLUMN id SET DEFAULT nextval('transportasi.halte_id_seq'::regclass);


--
-- Name: kecelakaan id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.kecelakaan ALTER COLUMN id SET DEFAULT nextval('transportasi.kecelakaan_id_seq'::regclass);


--
-- Name: parkir id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.parkir ALTER COLUMN id SET DEFAULT nextval('transportasi.parkir_id_seq'::regclass);


--
-- Name: rute id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.rute ALTER COLUMN id SET DEFAULT nextval('transportasi.rute_id_seq'::regclass);


--
-- Name: wilayah id; Type: DEFAULT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.wilayah ALTER COLUMN id SET DEFAULT nextval('transportasi.wilayah_id_seq'::regclass);


--
-- Data for Name: deteksi_objek; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.deteksi_objek (id, citra_sumber, tanggal_deteksi, model_digunakan, kelas_objek, confidence, geom) FROM stdin;
\.


--
-- Data for Name: hama_penyakit; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.hama_penyakit (id, tanggal_kejadian, jenis, nama_hama_penyakit, tingkat_serangan, luas_terdampak_ha, tanaman_terdampak, tindakan, status, created_at, geom) FROM stdin;
1	2024-01-10	hama	penggerek_buah_kopi	sedang	5.50	kopi_robusta	Penyemprotan pestisida	terkendali	2026-03-30 20:03:41.711895	0101000020E6100000EC51B81E85035A40F6285C8FC27514C0
2	2024-01-25	penyakit	karat_daun	ringan	2.00	kopi_arabika	Aplikasi fungisida	selesai	2026-03-30 20:03:41.711895	0101000020E61000003D0AD7A370055A4000000000008014C0
3	2024-02-08	hama	wereng	berat	15.00	padi	Penyemprotan massal	aktif	2026-03-30 20:03:41.711895	0101000020E6100000713D0AD7A3085A40D7A3703D0A5714C0
4	2024-02-20	hama	ulat_grayak	sedang	8.00	jagung	Pengendalian hayati	terkendali	2026-03-30 20:03:41.711895	0101000020E61000005C8FC2F528045A4014AE47E17A9414C0
5	2024-03-05	penyakit	busuk_akar	ringan	3.00	kopi_robusta	Drainase dan fungisida	selesai	2026-03-30 20:03:41.711895	0101000020E61000007B14AE47E1025A400AD7A3703D8A14C0
6	2024-03-18	hama	kutu_putih	sedang	6.50	sawit	Penyemprotan sistemik	terkendali	2026-03-30 20:03:41.711895	0101000020E6100000C3F5285C8F0A5A40C3F5285C8F4214C0
7	2024-04-02	penyakit	blast	berat	12.00	padi	Aplikasi fungisida intensif	aktif	2026-03-30 20:03:41.711895	0101000020E6100000E17A14AE47095A40EC51B81E856B14C0
8	2024-04-15	hama	tikus	sedang	4.50	padi	Gropyokan dan umpan beracun	terkendali	2026-03-30 20:03:41.711895	0101000020E610000052B81E85EB095A40CDCCCCCCCC4C14C0
9	2024-05-01	penyakit	antraknosa	ringan	2.50	kopi_arabika	Pemangkasan dan fungisida	selesai	2026-03-30 20:03:41.711895	0101000020E6100000AE47E17A14065A40F6285C8FC27514C0
10	2024-05-12	hama	nematoda	sedang	7.00	kopi_robusta	Aplikasi nematisida	aktif	2026-03-30 20:03:41.711895	0101000020E61000009A99999999015A401F85EB51B89E14C0
11	2024-06-01	hama	penggerek_batang	berat	10.00	padi	Penyemprotan intensif	aktif	2026-03-30 20:03:41.711895	0101000020E61000000000000000085A40E17A14AE476114C0
12	2024-06-15	penyakit	jamur_upas	sedang	4.00	karet	Aplikasi fungisida	terkendali	2026-03-30 20:03:41.711895	0101000020E61000008FC2F5285C075A40295C8FC2F5A814C0
13	2024-07-01	hama	kutu_hijau	ringan	3.50	kopi_robusta	Predator alami	selesai	2026-03-30 20:03:41.711895	0101000020E6100000EC51B81E85035A40EC51B81E856B14C0
14	2024-07-10	penyakit	vsd	berat	8.50	kakao	Pemangkasan sanitasi	aktif	2026-03-30 20:03:41.711895	0101000020E61000008FC2F5285C075A400AD7A3703D8A14C0
15	2024-07-20	hama	lalat_buah	sedang	5.00	kopi_arabika	Perangkap feromon	terkendali	2026-03-30 20:03:41.711895	0101000020E6100000CDCCCCCCCC045A40E17A14AE476114C0
\.


--
-- Data for Name: irigasi; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.irigasi (id, nama_saluran, jenis, panjang_km, lebar_m, kondisi, tahun_bangun, created_at, geom) FROM stdin;
1	Saluran Primer Way Tenong	primer	12.50	4.00	baik	2005	2026-03-30 20:03:41.711895	0102000020E610000004000000E17A14AE47015A4052B81E85EB5114C085EB51B81E055A4066666666666614C0295C8FC2F5085A405C8FC2F5285C14C0EC51B81E850B5A4048E17A14AE4714C0
2	Saluran Sekunder Sukanegara	sekunder	5.20	2.00	sedang	2010	2026-03-30 20:03:41.711895	0102000020E61000000300000085EB51B81E055A4066666666666614C0A4703D0AD7035A407B14AE47E17A14C03333333333035A408FC2F5285C8F14C0
3	Saluran Tersier Blok A	tersier	1.50	0.80	baik	2018	2026-03-30 20:03:41.711895	0102000020E6100000030000003333333333035A4066666666666614C0A4703D0AD7035A40713D0AD7A37014C014AE47E17A045A40713D0AD7A37014C0
4	Saluran Sekunder Sekincau	sekunder	6.80	2.50	rusak	2008	2026-03-30 20:03:41.711895	0102000020E610000003000000295C8FC2F5085A405C8FC2F5285C14C09A99999999095A4048E17A14AE4714C00AD7A3703D0A5A403D0AD7A3703D14C0
5	Saluran Primer Balik Bukit	primer	8.50	3.50	baik	2012	2026-03-30 20:03:41.711895	0102000020E6100000040000006666666666065A4066666666666614C048E17A14AE075A407B14AE47E17A14C0295C8FC2F5085A408FC2F5285C8F14C09A99999999095A40A4703D0AD7A314C0
6	Saluran Tersier Blok B	tersier	2.00	1.00	sedang	2015	2026-03-30 20:03:41.711895	0102000020E61000000300000048E17A14AE075A4052B81E85EB5114C0B81E85EB51085A405C8FC2F5285C14C0295C8FC2F5085A405C8FC2F5285C14C0
7	Saluran Sekunder Fajar Bulan	sekunder	4.50	2.00	baik	2016	2026-03-30 20:03:41.711895	0102000020E61000000300000014AE47E17A045A4066666666666614C085EB51B81E055A40713D0AD7A37014C0F6285C8FC2055A4085EB51B81E8514C0
\.


--
-- Data for Name: kelompok_tani; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.kelompok_tani (id, nama_kelompok, ketua, jumlah_anggota, desa, kecamatan, total_lahan_ha, komoditas_utama, created_at, geom) FROM stdin;
1	Poktan Maju Bersama	Suparman	45	Sukanegara	Way Tenong	125.50	kopi_robusta	2026-03-30 20:03:41.711895	0101000020E6100000A4703D0AD7035A40713D0AD7A37014C0
2	Poktan Sumber Rejeki	Mardianto	38	Fajar Bulan	Way Tenong	95.00	kopi_arabika	2026-03-30 20:03:41.711895	0101000020E6100000F6285C8FC2055A4085EB51B81E8514C0
3	Poktan Tani Jaya	Suroto	52	Sekincau	Sekincau	145.00	padi	2026-03-30 20:03:41.711895	0101000020E6100000295C8FC2F5085A4052B81E85EB5114C0
4	Poktan Mekar Sari	Sutrisno	35	Liwa	Balik Bukit	85.00	sayuran	2026-03-30 20:03:41.711895	0101000020E6100000D7A3703D0A075A4066666666666614C0
5	Poktan Harum Manis	Karman	40	Pekon Balak	Batu Brak	110.00	kopi_robusta	2026-03-30 20:03:41.711895	0101000020E6100000C3F5285C8F025A408FC2F5285C8F14C0
6	Poktan Subur Makmur	Wijaya	48	Gunung Terang	Way Tenong	135.00	kopi_robusta	2026-03-30 20:03:41.711895	0101000020E610000014AE47E17A045A407B14AE47E17A14C0
7	Poktan Sinar Tani	Rohman	32	Padang Cahya	Sekincau	78.00	padi	2026-03-30 20:03:41.711895	0101000020E61000000AD7A3703D0A5A405C8FC2F5285C14C0
8	Poktan Karya Mandiri	Slamet	42	Way Mengaku	Balik Bukit	105.00	jagung	2026-03-30 20:03:41.711895	0101000020E610000048E17A14AE075A409A999999999914C0
\.


--
-- Data for Name: kios_pupuk; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.kios_pupuk (id, nama_kios, pemilik, no_izin, alamat, telepon, jenis_pupuk, kuota_ton, radius_layanan_km, aktif, created_at, geom) FROM stdin;
1	Kios Tani Makmur	Agus Riyanto	IZN-2023-001	Jl. Lintas Sumatera KM 5	\N	{urea,npk,za}	50.00	8.00	t	2026-03-30 20:03:41.711895	0101000020E610000085EB51B81E055A407B14AE47E17A14C0
2	Kios Berkah Tani	Sri Mulyani	IZN-2023-002	Desa Sukanegara	\N	{urea,npk,organik}	35.00	5.00	t	2026-03-30 20:03:41.711895	0101000020E610000048E17A14AE075A405C8FC2F5285C14C0
3	Kios Subur Jaya	Bambang Sutrisno	IZN-2023-003	Kec. Way Tenong	\N	{urea,za,kcl}	45.00	6.00	t	2026-03-30 20:03:41.711895	0101000020E61000003333333333035A409A999999999914C0
4	Kios Mitra Petani	Dewi Sartika	IZN-2023-004	Pasar Liwa	\N	{urea,npk,organik,za}	60.00	10.00	t	2026-03-30 20:03:41.711895	0101000020E61000006666666666065A40713D0AD7A37014C0
5	Kios Harapan Tani	Hasan Basri	IZN-2023-005	Desa Sekincau	\N	{urea,npk}	30.00	5.00	t	2026-03-30 20:03:41.711895	0101000020E61000009A99999999095A403D0AD7A3703D14C0
6	Kios Sejahtera	Surya Darma	IZN-2023-006	Desa Fajar Bulan	\N	{urea,npk,sp36}	40.00	7.00	t	2026-03-30 20:03:41.711895	0101000020E610000014AE47E17A045A4066666666666614C0
7	Kios Mandiri Tani	Rina Wati	IZN-2023-007	Kec. Balik Bukit	\N	{urea,npk,organik}	55.00	8.00	t	2026-03-30 20:03:41.711895	0101000020E6100000B81E85EB51085A408FC2F5285C8F14C0
8	Kios Lestari	Dodi Pratama	IZN-2023-008	Desa Pekon Balak	\N	{urea,za,npk}	45.00	6.00	t	2026-03-30 20:03:41.711895	0101000020E6100000C3F5285C8F025A4085EB51B81E8514C0
\.


--
-- Data for Name: lahan; Type: TABLE DATA; Schema: pertanian; Owner: postgres
--

COPY pertanian.lahan (id, kode_lahan, nama_pemilik, nik_pemilik, jenis_tanaman, luas_hektar, status_kepemilikan, tahun_tanam, produktivitas_ton_per_ha, created_at, geom) FROM stdin;
1	LHN-001	Ahmad Suryadi	\N	kopi_robusta	2.50	milik	2018	1.20	2026-03-30 20:03:41.711895	0103000020E610000001000000050000003333333333035A4066666666666614C014AE47E17A045A4066666666666614C014AE47E17A045A407B14AE47E17A14C03333333333035A407B14AE47E17A14C03333333333035A4066666666666614C0
2	LHN-002	Budi Santoso	\N	kopi_arabika	3.00	milik	2015	0.80	2026-03-30 20:03:41.711895	0103000020E6100000010000000500000085EB51B81E055A40713D0AD7A37014C06666666666065A40713D0AD7A37014C06666666666065A4085EB51B81E8514C085EB51B81E055A4085EB51B81E8514C085EB51B81E055A40713D0AD7A37014C0
3	LHN-003	Citra Dewi	\N	padi	1.50	sewa	2023	5.50	2026-03-30 20:03:41.711895	0103000020E6100000010000000500000048E17A14AE075A4052B81E85EB5114C0295C8FC2F5085A4052B81E85EB5114C0295C8FC2F5085A4066666666666614C048E17A14AE075A4066666666666614C048E17A14AE075A4052B81E85EB5114C0
4	LHN-004	Darmawan	\N	jagung	2.00	garapan	2023	7.00	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000A4703D0AD7035A408FC2F5285C8F14C085EB51B81E055A408FC2F5285C8F14C085EB51B81E055A40A4703D0AD7A314C0A4703D0AD7035A40A4703D0AD7A314C0A4703D0AD7035A408FC2F5285C8F14C0
5	LHN-005	Eko Prasetyo	\N	kopi_robusta	4.00	milik	2016	1.50	2026-03-30 20:03:41.711895	0103000020E6100000010000000500000052B81E85EB015A407B14AE47E17A14C0A4703D0AD7035A407B14AE47E17A14C0A4703D0AD7035A409A999999999914C052B81E85EB015A409A999999999914C052B81E85EB015A407B14AE47E17A14C0
6	LHN-006	Fitri Handayani	\N	sawit	5.00	milik	2012	3.50	2026-03-30 20:03:41.711895	0103000020E610000001000000050000009A99999999095A4033333333333314C0EC51B81E850B5A4033333333333314C0EC51B81E850B5A4052B81E85EB5114C09A99999999095A4052B81E85EB5114C09A99999999095A4033333333333314C0
7	LHN-007	Gunawan	\N	karet	3.50	milik	2010	1.80	2026-03-30 20:03:41.711895	0103000020E610000001000000050000006666666666065A409A999999999914C0B81E85EB51085A409A999999999914C0B81E85EB51085A40B81E85EB51B814C06666666666065A40B81E85EB51B814C06666666666065A409A999999999914C0
8	LHN-008	Hendra Wijaya	\N	padi	2.00	milik	2023	6.00	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000295C8FC2F5085A4066666666666614C00AD7A3703D0A5A4066666666666614C00AD7A3703D0A5A407B14AE47E17A14C0295C8FC2F5085A407B14AE47E17A14C0295C8FC2F5085A4066666666666614C0
9	LHN-009	Indah Permata	\N	kopi_arabika	1.80	milik	2017	0.90	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000C3F5285C8F025A4052B81E85EB5114C0A4703D0AD7035A4052B81E85EB5114C0A4703D0AD7035A4066666666666614C0C3F5285C8F025A4066666666666614C0C3F5285C8F025A4052B81E85EB5114C0
10	LHN-010	Joko Susilo	\N	jagung	2.50	sewa	2023	6.50	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000F6285C8FC2055A403D0AD7A3703D14C0D7A3703D0A075A403D0AD7A3703D14C0D7A3703D0A075A4052B81E85EB5114C0F6285C8FC2055A4052B81E85EB5114C0F6285C8FC2055A403D0AD7A3703D14C0
11	LHN-011	Kartini	\N	kopi_robusta	3.20	milik	2014	1.30	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000E17A14AE47015A408FC2F5285C8F14C03333333333035A408FC2F5285C8F14C03333333333035A40AE47E17A14AE14C0E17A14AE47015A40AE47E17A14AE14C0E17A14AE47015A408FC2F5285C8F14C0
12	LHN-012	Lukman Hakim	\N	padi	1.00	garapan	2023	5.00	2026-03-30 20:03:41.711895	0103000020E610000001000000050000000AD7A3703D0A5A4048E17A14AE4714C07B14AE47E10A5A4048E17A14AE4714C07B14AE47E10A5A4052B81E85EB5114C00AD7A3703D0A5A4052B81E85EB5114C00AD7A3703D0A5A4048E17A14AE4714C0
13	LHN-013	Mardiyah	\N	kopi_robusta	2.80	milik	2019	1.10	2026-03-30 20:03:41.711895	0103000020E6100000010000000500000014AE47E17A045A405C8FC2F5285C14C0F6285C8FC2055A405C8FC2F5285C14C0F6285C8FC2055A40713D0AD7A37014C014AE47E17A045A40713D0AD7A37014C014AE47E17A045A405C8FC2F5285C14C0
14	LHN-014	Nugroho	\N	kakao	2.20	milik	2016	1.00	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000D7A3703D0A075A407B14AE47E17A14C0B81E85EB51085A407B14AE47E17A14C0B81E85EB51085A408FC2F5285C8F14C0D7A3703D0A075A408FC2F5285C8F14C0D7A3703D0A075A407B14AE47E17A14C0
15	LHN-015	Oktavia	\N	lada	1.50	milik	2018	0.60	2026-03-30 20:03:41.711895	0103000020E610000001000000050000003333333333035A40A4703D0AD7A314C014AE47E17A045A40A4703D0AD7A314C014AE47E17A045A40B81E85EB51B814C03333333333035A40B81E85EB51B814C03333333333035A40A4703D0AD7A314C0
\.


--
-- Data for Name: fasilitas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fasilitas (id, nama, jenis, alamat, geom) FROM stdin;
1	PB Swalayan	Pasar/Swalayan	J8Q3+QMM, Harapan Jaya, Sukarame, Bandar Lampung City, Lampung 35131	0101000020E610000024BE8C3C7B535A40C6A169C7087115C0
2	Masjid Raya Airan	Tempat Ibadah	J8R3+FXG, Jl. Hi Pangeransuhaimi, Harapan Jaya, Kec. Sukarame, Kabupaten Lampung Selatan, Lampung 35131	0101000020E61000009CAD385288535A4060290C43476F15C0
3	Polda Lampung	Fasilitas Umum	Jl. Terusan Ryacudu, Way Hui, Kec. Jati Agung, Kabupaten Lampung Selatan, Lampung 35131	0101000020E610000081196DB4A7535A40B91097E62C7015C0
4	Lapangan TVRI	Fasilitas Umum	J8W3+RJC, Way Hui, Jati Agung, South Lampung Regency, Lampung 35131	0101000020E61000002E0EFF5281535A40AA50C871FB6815C0
5	KLINIK BiMU MEDIKA MUHAMMADIYAH	Rumah Sakit/Klinik	Komplek Pasar Sukarame, Gg. Pembangunan G No.01, Way Dadi, Kec. Sukarame, Kota Bandar Lampung, Lampung 35137	0101000020E6100000BB2964D4EA525A40D73F0628CE8715C0
6	string	string	string	0101000020E610000000000000008066C000000000008056C0
7	string	string	string	0101000020E610000000000000008066C000000000008056C0
8	string	string	string	0101000020E610000000000000008066C000000000008056C0
\.


--
-- Data for Name: jalan; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.jalan (id, nama, geom) FROM stdin;
1	Jl. Terusan Ryacudu	0102000020E61000000200000017D9CEF753535A40F6285C8FC27515C0C1CAA145B6535A40EC51B81E856B15C0
2	Jl. Hi Pangeransuhaimi	0102000020E61000000200000008AC1C5A64535A40560E2DB29D6F15C0DD24068195535A403BDF4F8D976E15C0
3	Jl. Akses TVRI	0102000020E610000002000000FA7E6ABC74535A40EC51B81E856B15C0EC51B81E85535A4066666666666615C0
4	Jl. Gg Pembangunan G	0102000020E610000002000000C3F5285C8F525A4085EB51B81E8515C0508D976E12535A400AD7A3703D8A15C0
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: wilayah; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wilayah (id, nama, geom) FROM stdin;
1	Kecamatan Jati Agung	0103000020E610000001000000050000003333333333535A4066666666666615C0A4703D0AD7535A4066666666666615C0A4703D0AD7535A40A69BC420B07215C03333333333535A40A69BC420B07215C03333333333535A4066666666666615C0
2	Kecamatan Sukarame	0103000020E61000000100000005000000C3F5285C8F525A40EC51B81E856B15C03333333333535A40EC51B81E856B15C03333333333535A400AD7A3703D8A15C0C3F5285C8F525A400AD7A3703D8A15C0C3F5285C8F525A40EC51B81E856B15C0
\.


--
-- Data for Name: topology; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.topology (id, name, srid, "precision", hasz, useslargeids) FROM stdin;
\.


--
-- Data for Name: layer; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.layer (topology_id, layer_id, schema_name, table_name, feature_column, feature_type, level, child_id) FROM stdin;
\.


--
-- Data for Name: halte; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.halte (id, nama, kode, jenis, alamat, kapasitas, fasilitas, jam_operasi_mulai, jam_operasi_selesai, aktif, created_at, geom) FROM stdin;
1	Halte Tanjung Karang	HLT-001	brt	Jl. Raden Intan	50	{kursi_tunggu,atap,papan_info,cctv}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000A2B437F8C2505A400F9C33A2B4B715C0
2	Halte Rajabasa	HLT-002	brt	Jl. ZA Pagar Alam	40	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000265305A3924E5A402497FF907E7B15C0
3	Halte Sukaraja	HLT-003	bus	Jl. Soekarno Hatta	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E610000072F90FE9B74F5A40ED9E3C2CD49A15C0
4	Halte Kemiling	HLT-004	angkot	Jl. Imam Bonjol	20	{kursi_tunggu}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000D93D7958A84D5A40917EFB3A708E15C0
5	Halte Teluk Betung	HLT-005	brt	Jl. Laksamana Malahayati	45	{kursi_tunggu,atap,papan_info,toilet}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000003E7958A835515A4020D26F5F07CE15C0
6	Halte Panjang	HLT-006	bus	Jl. Yos Sudarso	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E610000088635DDC46535A40AA60545227E015C0
7	Halte Way Halim	HLT-007	angkot	Jl. Sultan Agung	25	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000EEEBC03923525A402E90A0F831A615C0
8	Halte Kedaton	HLT-008	brt	Jl. Teuku Umar	40	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E610000055302AA913505A408716D9CEF79315C0
9	Halte Labuhan Ratu	HLT-009	bus	Jl. Pulau Damar	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000002C6519E2584F5A400DE02D90A07815C0
10	Halte Tanjung Senang	HLT-010	angkot	Jl. Ryacudu	20	{kursi_tunggu}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000C4B12E6EA3515A40462575029A8815C0
11	Halte Sukarame	HLT-011	brt	Jl. Endro Suratmin	45	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000022B8716D9525A40CE1951DA1B7C15C0
12	Halte Korpri	HLT-012	bus	Jl. Korpri Raya	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000005D6DC5FEB2535A40B459F5B9DA8A15C0
13	Halte Gedong Air	HLT-013	angkot	Jl. Ikan Kakap	25	{kursi_tunggu}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E610000016FBCBEEC94F5A406F8104C58FB115C0
14	Halte Enggal	HLT-014	brt	Jl. Kartini	50	{kursi_tunggu,atap,papan_info,cctv}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000CD3B4ED191505A40772D211FF4AC15C0
15	Halte Kaliawi	HLT-015	bus	Jl. Ikan Tongkol	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000009C33A2B437505A4055C1A8A44EC015C0
16	Halte Sumur Batu	HLT-016	angkot	Jl. Wolter Monginsidi	20	{kursi_tunggu}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000009A779CA223515A404D158C4AEAC415C0
17	Halte Bumi Waras	HLT-017	brt	Jl. Ikan Hiu	40	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000DAACFA5C6D515A408E06F01648D015C0
18	Halte Sukabumi	HLT-018	bus	Jl. Pangeran Antasari	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000A5BDC117264F5A406D567DAEB6A215C0
19	Halte Langkapura	HLT-019	angkot	Jl. Pramuka	25	{kursi_tunggu}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000000B462575024E5A40ED9E3C2CD49A15C0
20	Halte Segala Mider	HLT-020	brt	Jl. Cut Nyak Dien	45	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E610000091ED7C3F35525A4014D044D8F0B415C0
21	Halte ITERA	HLT-021	brt	Jl. Terusan Ryacudu	50	{kursi_tunggu,atap,papan_info,wifi}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E610000087A757CA32545A4003098A1F636E15C0
22	Halte Unila	HLT-022	brt	Jl. Prof. Sumantri Brojonegoro	50	{kursi_tunggu,atap,papan_info}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E610000074B515FBCB4E5A4044FAEDEBC07915C0
23	Halte Pasar Tengah	HLT-023	bus	Jl. Ikan Bawal	35	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E6100000226C787AA5505A40DDB5847CD0B315C0
24	Halte Bambu Kuning	HLT-024	angkot	Jl. Bambu Kuning	30	{kursi_tunggu,atap}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000002A3A92CB7F505A4076711B0DE0AD15C0
25	Halte Simpur Center	HLT-025	brt	Jl. Jendral Sudirman	45	{kursi_tunggu,atap,papan_info,cctv}	\N	\N	t	2026-03-30 20:03:41.711895	0101000020E61000000D71AC8BDB505A409CC420B072A815C0
\.


--
-- Data for Name: kecelakaan; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.kecelakaan (id, tanggal, waktu, jenis_kecelakaan, jumlah_korban, jumlah_kendaraan, penyebab, kondisi_jalan, kondisi_cuaca, keterangan, created_at, geom) FROM stdin;
1	2024-01-15	08:30:00	sedang	2	2	Tabrakan beruntun	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E6100000C66D3480B7505A40D50968226CB815C0
2	2024-01-20	17:45:00	ringan	1	1	Motor tergelincir	berlubang	hujan	\N	2026-03-30 20:03:41.711895	0101000020E61000009C33A2B437505A40D3DEE00B93A915C0
3	2024-02-03	22:15:00	berat	3	3	Pengemudi mengantuk	baik	berkabut	\N	2026-03-30 20:03:41.711895	0101000020E6100000C4B12E6EA3515A4019E25817B79115C0
4	2024-02-10	06:00:00	ringan	0	2	Menyalip sembarangan	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E61000007B832F4CA64E5A404ED1915CFE8315C0
5	2024-02-18	14:30:00	sedang	2	2	Rem blong	rusak	cerah	\N	2026-03-30 20:03:41.711895	0101000020E61000009A779CA223515A4020D26F5F07CE15C0
6	2024-03-05	19:00:00	berat	4	2	Melawan arah	baik	hujan	\N	2026-03-30 20:03:41.711895	0101000020E610000072F90FE9B74F5A40363CBD5296A115C0
7	2024-03-12	11:30:00	ringan	1	2	Tidak jaga jarak	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E6100000022B8716D9525A40AA8251499D8015C0
8	2024-03-20	16:45:00	fatal	1	2	Kecepatan tinggi	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E6100000696FF085C9505A408104C58F31B715C0
9	2024-04-01	07:15:00	sedang	2	3	Tabrakan di persimpangan	baik	berkabut	\N	2026-03-30 20:03:41.711895	0101000020E6100000CD3B4ED191505A40772D211FF4AC15C0
10	2024-04-08	20:30:00	ringan	1	1	Menabrak pembatas jalan	baik	hujan	\N	2026-03-30 20:03:41.711895	0101000020E6100000EEEBC03923525A406F8104C58FB115C0
11	2024-04-15	13:00:00	berat	3	2	Truk hilang kendali	rusak	cerah	\N	2026-03-30 20:03:41.711895	0101000020E610000088635DDC46535A40F38E537424D715C0
12	2024-04-22	09:45:00	sedang	2	2	Motor vs mobil	berlubang	cerah	\N	2026-03-30 20:03:41.711895	0101000020E6100000A5BDC117264F5A4050FC1873D79215C0
13	2024-05-01	18:00:00	ringan	1	2	Saling senggol	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E610000055302AA913505A402C6519E2589715C0
14	2024-05-10	23:30:00	fatal	2	2	Mabuk	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E61000003E7958A835515A40F163CC5D4BC815C0
15	2024-05-18	10:15:00	sedang	2	3	Ban pecah	baik	hujan	\N	2026-03-30 20:03:41.711895	0101000020E6100000265305A3924E5A40AA8251499D8015C0
16	2024-06-02	15:30:00	ringan	1	2	Tidak fokus	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E6100000226C787AA5505A40772D211FF4AC15C0
17	2024-06-15	08:00:00	sedang	2	2	Lampu merah dilanggar	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E61000000D71AC8BDB505A409CC420B072A815C0
18	2024-06-28	21:00:00	berat	3	2	Tabrak lari	baik	hujan	\N	2026-03-30 20:03:41.711895	0101000020E6100000DAACFA5C6D515A4055C1A8A44EC015C0
19	2024-07-05	12:30:00	ringan	0	2	Parkir sembarangan	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E61000002A3A92CB7F505A40014D840D4FAF15C0
20	2024-07-12	17:00:00	sedang	2	3	U-turn sembarangan	baik	cerah	\N	2026-03-30 20:03:41.711895	0101000020E610000091ED7C3F35525A406D567DAEB6A215C0
\.


--
-- Data for Name: parkir; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.parkir (id, nama, jenis, kapasitas, tarif_per_jam, jam_buka, jam_tutup, pengelola, created_at, geom) FROM stdin;
1	Parkir Mall Kartini	campuran	500	3000	08:00:00	22:00:00	PT Mall Kartini	2026-03-30 20:03:41.711895	0101000020E6100000696FF085C9505A40401361C3D3AB15C0
2	Parkir Pasar Tengah	campuran	200	2000	06:00:00	18:00:00	Pemkot Bandar Lampung	2026-03-30 20:03:41.711895	0101000020E6100000CD3B4ED191505A406F8104C58FB115C0
3	Parkir RSUD Abdul Moeloek	campuran	150	2000	00:00:00	23:59:00	RSUD Abdul Moeloek	2026-03-30 20:03:41.711895	0101000020E61000009C33A2B437505A40D3DEE00B93A915C0
4	Parkir Stasiun Tanjung Karang	campuran	300	2500	04:00:00	23:00:00	PT KAI	2026-03-30 20:03:41.711895	0101000020E6100000C66D3480B7505A4014D044D8F0B415C0
5	Parkir Chandra Superstore	campuran	400	2000	09:00:00	21:30:00	Chandra Group	2026-03-30 20:03:41.711895	0101000020E6100000B0726891ED505A409CC420B072A815C0
6	Parkir Motor Pasar Bambu Kuning	motor	100	1000	06:00:00	17:00:00	Pemkot Bandar Lampung	2026-03-30 20:03:41.711895	0101000020E61000002A3A92CB7F505A40014D840D4FAF15C0
7	Parkir Unila	campuran	600	1500	06:00:00	22:00:00	Universitas Lampung	2026-03-30 20:03:41.711895	0101000020E610000074B515FBCB4E5A4044FAEDEBC07915C0
8	Parkir ITERA	campuran	400	1500	06:00:00	22:00:00	Institut Teknologi Sumatera	2026-03-30 20:03:41.711895	0101000020E610000087A757CA32545A4003098A1F636E15C0
9	Parkir Simpur Center	campuran	350	3000	09:00:00	22:00:00	PT Simpur Center	2026-03-30 20:03:41.711895	0101000020E61000000D71AC8BDB505A409CC420B072A815C0
10	Parkir Central Plaza	campuran	450	3000	09:00:00	22:00:00	PT Central Plaza	2026-03-30 20:03:41.711895	0101000020E6100000226C787AA5505A40772D211FF4AC15C0
11	Parkir Motor Enggal	motor	80	1000	06:00:00	18:00:00	Pemkot Bandar Lampung	2026-03-30 20:03:41.711895	0101000020E6100000CD3B4ED191505A40772D211FF4AC15C0
12	Parkir Transmart	campuran	500	2500	09:00:00	22:00:00	PT Trans Retail	2026-03-30 20:03:41.711895	0101000020E6100000C4B12E6EA3515A4019E25817B79115C0
\.


--
-- Data for Name: rute; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.rute (id, kode_rute, nama_rute, jenis, warna, panjang_km, estimasi_waktu_menit, tarif, aktif, created_at, geom) FROM stdin;
1	RT-001	Rajabasa - Tanjung Karang	brt	#FF0000	8.50	25	5000	t	2026-03-30 20:03:41.711895	0102000020E610000006000000265305A3924E5A402497FF907E7B15C074B515FBCB4E5A4044FAEDEBC07915C02C6519E2584F5A400AD7A3703D8A15C055302AA913505A408716D9CEF79315C0CD3B4ED191505A40772D211FF4AC15C0A2B437F8C2505A400F9C33A2B4B715C0
2	RT-002	Tanjung Karang - Teluk Betung	brt	#00FF00	6.20	20	5000	t	2026-03-30 20:03:41.711895	0102000020E610000005000000A2B437F8C2505A400F9C33A2B4B715C00D71AC8BDB505A409CC420B072A815C054742497FF505A40E78C28ED0DBE15C09A779CA223515A404D158C4AEAC415C03E7958A835515A4020D26F5F07CE15C0
3	RT-003	Kemiling - Sukarame	bus	#0000FF	12.30	40	4000	t	2026-03-30 20:03:41.711895	0102000020E610000006000000D93D7958A84D5A40917EFB3A708E15C0A5BDC117264F5A40D8F0F44A598615C0CD3B4ED191505A40AA8251499D8015C0EEEBC03923525A40CE1951DA1B7C15C0022B8716D9525A40CE1951DA1B7C15C05D6DC5FEB2535A40B459F5B9DA8A15C0
4	RT-004	Way Halim - Panjang	bus	#FFFF00	9.80	35	4000	t	2026-03-30 20:03:41.711895	0102000020E610000005000000EEEBC03923525A402E90A0F831A615C091ED7C3F35525A4014D044D8F0B415C035EF384547525A40C3F5285C8FC215C018265305A3525A408E06F01648D015C088635DDC46535A40AA60545227E015C0
5	RT-005	Kedaton Circular	angkot	#FF00FF	7.50	30	3000	t	2026-03-30 20:03:41.711895	0102000020E61000000600000055302AA913505A408716D9CEF79315C072F90FE9B74F5A40ED9E3C2CD49A15C02C6519E2584F5A406D567DAEB6A215C0A5BDC117264F5A406D567DAEB6A215C072F90FE9B74F5A408716D9CEF79315C055302AA913505A408716D9CEF79315C0
6	RT-006	ITERA - Tanjung Karang	brt	#00FFFF	10.50	35	5000	t	2026-03-30 20:03:41.711895	0102000020E61000000400000087A757CA32545A4003098A1F636E15C0022B8716D9525A40CE1951DA1B7C15C0C4B12E6EA3515A40462575029A8815C0A2B437F8C2505A400F9C33A2B4B715C0
7	RT-007	Unila - Teluk Betung	bus	#FFA500	11.20	40	4000	t	2026-03-30 20:03:41.711895	0102000020E61000000400000074B515FBCB4E5A4044FAEDEBC07915C072F90FE9B74F5A40ED9E3C2CD49A15C0CD3B4ED191505A40772D211FF4AC15C03E7958A835515A4020D26F5F07CE15C0
8	RT-008	Sukarame - Panjang	bus	#800080	13.50	45	4500	t	2026-03-30 20:03:41.711895	0102000020E610000004000000022B8716D9525A40CE1951DA1B7C15C0EEEBC03923525A402E90A0F831A615C0DAACFA5C6D515A408E06F01648D015C088635DDC46535A40AA60545227E015C0
\.


--
-- Data for Name: tugas5_area_rawan_kecelakaan; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.tugas5_area_rawan_kecelakaan (id, geom) FROM stdin;
1	0106000020E610000010000000010300000001000000A9000000DFA667CFD3505A40B37C209EF5B815C0A607F95AD3505A402AB2AEB90BB915C097A95CD5D2505A40DA74D07221B915C006F3E43ED2505A40FB0F20BC36B915C0B3AFEE97D1505A40D8C47C884BB915C091D7E0E0D0505A4088E312CB5FB915C0464F2C1AD0505A4062B4637773B915C08AA24B44CF505A40692C4D8186B915C096B8C25FCE505A400A6911DD98B915C0CA821E6DCD505A4003EE5D7FAAB915C0BFA5F46CCC505A40EAA0525DBBB915C0041DE35FCB505A405A7E886CCBB915C0A8D98F46CA505A40280418A3DAB915C0E75BA821C9505A405C4D9FF7E8B915C02848E1F1C7505A4055DB4761F6B915C095F7F5B7C6505A406509CCD702BA15C08F04A874C5505A4097267C530EBA15C049D3BE28C4505A40673343CD18BA15C0CB1607D5C2505A402040AB3E22BA15C0B952527AC1505A408B68E1A12ABA15C0165A7619C0505A40786BB9F131BA15C067CB4CB3BE505A40CFDBB02938BA15C07B8AB248BD505A4053E8F1453DBA15C0313887DABB505A402CB9554341BA15C087A8AC69BA505A406961661F44BA15C05B5706F7B8505A40F16360D845BA15C017DC7883B7505A4060C9336D46BA15C0B65CE90FB6505A4041C884DD45BA15C073003D9DB4505A405EFDAB2944BA15C07762582CB3505A406935B65241BA15C0D2041FBEB1505A40B1C6635A3DBA15C033C47253B0505A40427D274338BA15C0974C33EDAE505A40E017251032BA15C0588F3D8CAD505A406E582FC52ABA15C0E63A6B31AC505A4049A8C56622BA15C0893492DDAA505A40655211FA18BA15C076148491A9505A401254E2840EBA15C088A40D4EA8505A4037C7AB0D03BA15C0F261F613A7505A4070E87F9BF6B915C03F0200E4A5505A405DBA0B36E9B915C0CFFBE5BEA4505A408C4992E5DAB915C041125DA5A3505A405D94E7B2CBB915C0F2E61298A2505A40E8186BA7BBB915C0EF8DAD97A1505A40500D02CDAAB915C08027CBA4A0505A404345112E99B915C0A97E01C09F505A400BC976D586B915C0C3ACDDE99E505A40BC2183CE73B915C07DC2E3229E505A40CF5EF22460B915C065768E6B9D505A4068D9E4E44BB915C03DD94EC49C505A4096B9D71A37B915C03F108C2D9C505A40E5429DD321B915C08215A3A79B505A40CFEB541C0CB915C0A47EE6329B505A40B8456302F6B815C0DB499ECF9A505A40E8BA6993DFB815C08FB1077E9A505A40C7253EDDC8B815C09A06553E9A505A402749E2EDB1B815C04191AD109A505A407B2C7BD39AB815C0FA782DF599505A40AD62489C83B815C011B3E5EB99505A409C409B566CB815C035F8DBF499505A407D08CE1055B815C0EFC00A109A505A40EB0F3BD93DB815C00E49613D9A505A40E4E533BE26B815C0019AC37C9A505A40047EF8CD0FB815C0159C0ACE9A505A40D566AE16F9B715C0922E04319B505A40531058A6E2B715C0A84673A59B505A40CA27CC8ACCB715C01515102B9C505A409E0FADD1B6B715C0703288C19C505A40FC756088A1B715C0F9D17E689D505A40381207BC8CB715C0DBFA8C1F9E505A400B8C747978B715C0A8C741E69E505A403E9227CD64B715C000AC22BC9F505A405B2642C351B715C020C0ABA0A0505A40F92082673FB715C043125093A1505A40F1F339C52DB715C085FD7993A2505A40FFAE49E71CB715C039868BA0A3505A40964A18D80CB715C04DBBDEB9A4505A40DC3D8DA1FDB615C0AA1CC6DEA5505A40C1620A4DEFB615C02E068D0EA7505A40FE2C66E3E1B615C0171F7848A8505A408736E66CD5B615C08ECDC58BA9505A40EB253AF1C9B615C008AEAED7AA505A40B5F07677BFB615C0440E662BAC505A40217D1206B6B615C0EE8FD611AD505A407D24EC72B0B615C0250DC336AD505A400FB0E813A8B615C0A7ED31ABAD505A406B065CF891B615C0DE82CE30AE505A40C20D3C3F7CB615C0856546C7AE505A40CD74EEF566B615C001C93C6EAF505A4080F3932952B615C0A0B44A25B0505A40423200E73DB615C01C43FFEBB0505A409FE0B13A2AB615C03AE8DFC1B1505A40F600CB3017B615C05FBC68A6B2505A40C16C09D504B615C0ECCD0C99B3505A40D596BF32F3B515C026783699B4505A40EE8FCD54E2B515C087BF47A6B5505A409A519A45D2B515C027B39ABFB6505A4021540D0FC3B515C015D381E4B7505A40A77288BAB4B515C05A7B4814B9505A402122E250A7B515C05A53334EBA505A40D2FD5FDA9AB515C066C18091BB505A40A2ADB15E8FB515C01D6269DDBC505A407D28ECE484B515C063832031BE505A400F5685737BB515C0A1A2D48BBF505A402113501073B515C0F6EDAFECC0505A40349A78C06BB515C018C8D852C2505A407B52818865B515C0874E72BDC3505A402908406C60B515C0C4E19C2BC5505A40FC8EDB6E5CB515C03FAF769CC6505A40C0D0C99259B515C0933C1C0FC8505A406A48CED957B515C0D8F3A882C9505A4055ECF84457B515C094B037F6CA505A40E785A5D457B515C0114DE368CC505A4073797B8859B515C0AC2FC7D9CD505A4068FC6D5F5CB515C0CBD7FF47CF505A40B2BBBC5760B515C0346AABB2D0505A408BEFF46E65B515C04B3CEA18D2505A407DDEF2A16BB515C00D5EDF79D3505A40F1CCE3EC72B515C04422B1D4D4505A40C158484B7BB515C0D4A48928D6505A400F3FF7B784B515C0974E9774D7505A407A8B202D8FB515C0A5560DB8D8505A40B82D51A49AB515C09E4024F2D9505A407FF37616A7B515C0B1571A22DB505A4007E5E47BB4B515C010263447DC505A40150158CCC2B515C08BE8BC60DD505A40FC54FCFED1B515C011FE066EDE505A409F6E720AE2B515C0C0526C6EDF505A40F523D5E4F2B515C050C64E61E0505A4082ADBF8304B615C09C8D1846E1505A40140F54DC16B615C0028F3C1CE2505A408ECB41E329B615C069B936E3E2505A402BDFCC8C3DB615C0B5558C9AE3505A4010FCD4CC51B615C07252CC41E4505A40FB04DD9666B615C098898FD8E4505A40A5C012DE7BB615C01F00795EE5505A4026C2569591B615C0601F36D3E5505A40E78044AFA7B615C003E87E36E6505A40969A3A1EBEB615C0631E1688E6505A40DE3B63D4D4B615C05770C9C7E6505A4001A8BCC3EBB615C03C9471F5E6505A409CDC21DE02B715C02F61F210E7505A40B44A53151AB715C06CE03A1AE7505A404DA0FF5A31B715C0C9574511E7505A40E79CCCA048B715C0394D17F6E6505A406FEB5FD85FB715C06E83C1C8E6505A4056FC67F376B715C07BEF5F89E6505A4034DAA4E38DB715C09DA71938E6505A4099F3F09AA4B715C022CB20D5E5505A4084D4490BBBB715C07C63B260E5505A408CCAD826D1B715C0A23E16DBE4505A40336DFBDFE6B715C0C4C29E44E4505A4027074C29FCB715C07FBBA89DE3505A4010D9A9F510B815C0A1209BE6E2505A405A32413825B815C0ABD6E61FE2505A409E5A93E438B815C02E69064AE1505A4002467EEE4BB815C03BBF7D65E0505A401811444A5EB815C00BCAD972DF505A40A53E92EC6FB815C0102EB072DE505A4038B388CA80B815C0B0E69E65DD505A40576AC0D990B815C0D1E44B4CDC505A40B8E05110A0B815C088A86427DB505A402B30DB64AEB815C013D69DF7D9505A40D0D885CEBBB815C072C6B2BDD8505A40B1340C45C8B815C0E213657AD7505A407F91BEC0D3B815C06A227C2ED6505A4051EE873ADEB815C0EDA4C4DAD4505A40065AF2ABE7B815C08B0854F4D3505A408E811C3FEDB815C0DFA667CFD3505A40B37C209EF5B815C0010300000001000000DE0000001C44E7CE9C505A4094CF5C62ABAF15C0D77EA07D9C505A40AE23A719C2AF15C09335A71A9C505A40F8A6FD89D8AF15C0067238A69B505A4080A889A5EEAF15C061029C209B505A4095C1A85E04B015C0014D248A9A505A40143FF5A719B015C0A81D2EE399505A4030644E742EB015C03D6C202C99505A403783E0B642B015C04C1D6C6598505A40FCE62C6356B015C06DBC8B8F97505A403387116D69B015C0A73003AB96505A405084D0C87BB015C0236B5FB895505A404D65176B8DB015C0331036B894505A40391306499EB015C0171B25AB93505A40698E3558AEB015C0817CD29192505A40A558BE8EBDB015C049B4EB6C91505A401C913EE3CBB015C06666253D90505A408BBDDF4CD9B015C089EB3A038F505A40D63D5CC3E5B015C08DDDEDBF8D505A40C265043FF1B015C019A005748C505A40B93AC3B8FBB015C09FE54E208B505A4014D2222A05B115C022319BC589505A40DF4C508D0DB115C00055C06488505A403F6F1FDD14B115C00CEF97FE86505A409AD10D151BB115C05FE2FE9385505A404BA8453120B115C018CFD42584505A402B21A02E24B115C07488FBB482505A400C55A70A27B115C08289564281505A40AECC97C328B115C0DD68CACE7F505A408E96615829B115C0A94B3C5B7E505A4026EFA8C828B115C0495891E87C505A403579C61427B115C00329AE777B505A406607C73D24B115C0083F76097A505A40FBF56A4520B115C02176CB9E78505A40F916252E1BB115C062798D3877505A40072F19FB14B115C03B3999D775505A40E9051AB00DB115C03163C87C74505A40C70AA75105B115C0A1DBF02873505A40568EE9E4FBB015C0D339E4DC71505A408393B16FF1B015C0B5466F9970505A40C63972F8E5B015C0917E595F6F505A4022C33D86D9B015C00796642F6E505A408337C120CCB015C090024C0A6D505A40A3A83FD0BDB015C0E486C4F06B505A40E2198D9DAEB015C083C37BE36A505A402B0E09929EB015C097CB17E369505A404AC098B78DB015C092BE36F068505A406108A1187CB015C09F666E0B68505A4009F3FFBF69B015C04BDC4B3567505A40610D06B956B015C0782F536E66505A40B56A6F0F43B015C0F315FFB665505A40CC675CCF2EB015C0BE9FC00F65505A4015304A051AB015C060F1FE7864505A403C0A0BBE04B015C0400417F363505A409B6FBE06EFAF15C0576D5B7E63505A403CF4C8ECD8AF15C03B2A141B63505A40BC04CC7DC2AF15C0C2747EC962505A40997D9DC7ABAF15C0389DCC8962505A4076233FD894AF15C062EB255C62505A4049FFD5BD7DAF15C03B86A64062505A4042A5A18666AF15C0A3625F3762505A402D6BF3404FAF15C0E338564062505A40F39325FB37AF15C02D81855B62505A408C7592C320AF15C00077DC8862505A40059F8BA809AF15C089233FC862505A40D10351B8F2AE15C0DA6E861963505A40F6310801DCAE15C01338807C63505A40A998B390C5AE15C03C74EFF063505A4020E42975AFAE15C003548C7664505A4063750DBC99AE15C0F06F040D65505A40FCF8C37284AE15C046FBFAB365505A4055246EA66FAE15C03DFD086B66505A40F49CDF635BAE15C08090BD3167505A40310F97B747AE15C0D0289E0768505A40D279B6AD34AE15C09CDE26EC68505A407EB2FB5122AE15C057C0CADE69505A40CF27B9AF10AE15C06429F4DE6A505A4007E6CED1FFAD15C0651E05EC6B505A40EEE1A3C2EFAD15C0A4AE57056D505A40AF8E1F8CE0AD15C0705A3E2A6E505A4025C2A337D2AD15C0167E045A6F505A40A7EB06CEC4AD15C04FC1EE9370505A40A1A08E57B8AD15C0C58A3BD771505A40EE82EADBACAD15C07F77232373505A402F832F62A2AD15C0D1D5D97674505A409582D3F098AD15C097238DD175505A403F57A98D90AD15C0D02F1DE475505A40A3EC302B90AD15C02A881F8475505A40535596FE7DAD15C0DD37D82075505A4025149A8F67AD15C03C7042CF74505A40FB1C6CD950AD15C0A081908F74505A4020340EEA39AD15C0D9B3E96174505A404162A5CF22AD15C0F72D6A4674505A405D3B71980BAD15C0ECE4223D74505A402415C352F4AC15C01A91194674505A406E32F50CDDAC15C0CBAA486174505A403EE961D5C5AC15C09B6D9F8E74505A40BCC85ABAAEAC15C0D7E201CE74505A4088C41FCA97AC15C0B5F2481F75505A40E76AD61281AC15C0747C428275505A40662B81A26AAC15C04C75B1F675505A40A0B2F68654AC15C00C0E4E7C76505A401862D9CD3EAC15C06DDFC51277505A40EAE68E8429AC15C0DF1CBCB977505A4011F737B814AC15C0C9CDC97078505A40CA38A87500AC15C0070D7E3779505A402A595EC9ECAB15C0914E5E0D7A505A40CF577CBFD9AB15C00AABE6F17A505A40350BC063C7AB15C01B318AE47B505A40F1E27BC1B5AB15C0613CB3E47C505A4041EC8FE3A4AB15C0B6D1C3F17D505A40F91C63D494AB15C0A200160B7F505A4066E9DC9D85AB15C0AD49FC2F80505A4084285F4977AB15C06309C25F81505A40E24AC0DF69AB15C0B9E7AB9982505A402EE745695DAB15C0994BF8DC83505A408DA09FED51AB15C047D2DF2885505A40F368E27347AB15C054CA957C86505A40F22284023EAB15C0E0B148D787505A4010A6579F35AB15C0CBB7223889505A406827894F2EAB15C0943F4A9E8A505A40A4089B1728AB15C08A67E2088C505A40561063FB22AB15C007910B778D505A407A0C08FE1EAB15C059EAE3E78E505A400CE1FF211CAB15C001FA875A90505A401D030E691AAB15C0022B13CE91505A400C6342D419AB15C0D359A04193505A404AC4F8631AAB15C0B3614AB494505A401A85D8171CAB15C0F6A92C2596505A40E5D4D4EE1EAB15C003B3639397505A408B5A2DE722AB15C09BA20DFE98505A4042486FFE27AB15C029CF4A649A505A4094DE76312EAB15C05FAF17A69B505A4006B6AAD734AB15C0C34A49E19C505A40B0D59D4F2EAB15C077C370479E505A4098D8AC1728AB15C09CDE08B29F505A40F9F671FB22AB15C093FD3120A1505A409E0014FE1EAB15C0B24E0A91A2505A4052DB08221CAB15C07D58AE03A4505A40FFFD13691AAB15C0FC853977A5505A40DA5A45D419AB15C0A9B3C6EAA6505A402DB7F8631AAB15C0C1BC705DA8505A401B73D5171CAB15C09B0853CEA9505A40E9BFCEEE1EAB15C098178A3CAB505A40514624E722AB15C0780F34A7AC505A405F3A63FE27AB15C09E46710DAE505A4075DE67312EAB15C002CE646EAF505A40D7725F7C35AB15C06FF934C9B0505A404791CADA3DAB15C0C0E50B1DB2505A40D6F27F4747AB15C0CDFC1769B3505A40229FAFBC51AB15C0A5768CACB4505A40F881E6335DAB15C0DED7A1E6B5505A40286512A669AB15C0966C9616B7505A402E4D860B77AB15C0F0BFAE3BB8505A401735FF5B85AB15C0A60F3655B9505A40A826A98E94AB15C08BBB7E62BA505A4044AC249AA4AB15C09AB0E262BB505A408E988C74B5AB15C065CFC355BC505A40CF207C13C7AB15C09A4D8C3ABD505A40BF45156CD9AB15C06312AF10BE505A404F870773ECAB15C0680DA8D7BE505A40EADE961C00AC15C04888FC8EBF505A4015FCA25C14AC15C044723B36C0505A4018BFAE2629AC15C0FBA5FDCCC0505A4057ECE76D3EAC15C00729E652C1505A40CB142F2554AC15C05665A2C7C1505A40E7AD1F3F6AAC15C01C5CEA2AC2505A409B5318AE80AC15C037D2807CC2505A40F730436497AC15C0F47533BCC2505A40DD879E53AEAC15C01CFEDAE9C2505A40BB54056EC5AC15C02B425B05C3505A40990738A5DCAC15C0B34BA30EC3505A40B34DE5EAF3AC15C0D360AD05C3505A40ECE5B2300BAD15C0BB077FEAC2505A40D97A466822AD15C04B0329BDC2505A40BD7C4E8339AD15C0BC48C77DC2505A4037F68A7350AD15C066EE802CC2505A401656D62A67AD15C0A01388C9C1505A40C8282E9B7DAD15C0D9C11955C1505A4090BCBBB693AD15C0FEC67DCFC0505A40C6A9DC6FA9AD15C025890639C0505A402B3C2BB9BEAD15C0C4D31092BF505A40A6B58685D3AD15C0789E03DBBE505A4018671BC8E7AD15C082CD4F14BE505A40BC996A74FBAD15C028EC6F3EBD505A408F43527E0EAE15C028E1E759BC505A40248314DA20AE15C0559D4467BB505A4074DD5E7C32AE15C0B6C41B67BA505A406A39515A43AE15C038520B5AB9505A401495846953AE15C03E36B940B8505A40DB6F11A062AE15C050F0D21BB7505A406BE695F470AE15C013240DECB5505A40E27B3B5E7EAE15C0E62923B2B4505A40688DBCD48AAE15C0599BD66EB3505A40FA6B695096AE15C0C1DBEE22B2505A40121A2DCAA0AE15C0449D38CFB0505A4011AA913BAAAE15C098628574AF505A40EF39C49EB2AE15C0CFFDAA13AE505A40AC8A98EEB9AE15C0730C83ADAC505A4081318C26C0AE15C05671EA42AB505A40855FC942C5AE15C050CCC0D4A9505A40443F2940C9AE15C059F0E763A8505A403EE6351CCCAE15C0405843F1A6505A40D2D92BD5CDAE15C05D9AB77DA5505A401C25FB69CEAE15C09DDB290AA4505A40360148DACDAE15C023427F97A2505A406E0D6B26CCAE15C001689C26A1505A400A19714FC9AE15C031CE64B89F505A40F07C1A57C5AE15C04C50BA4D9E505A40BD07DA3FC0AE15C037997CE79C505A40C47AD30CBAAE15C0E20177BD9B505A4060EE69E4B3AE15C0DC96C5189C505A400439ED2DC5AE15C0B5520D7C9C505A40637FE79CDBAE15C03E88A3CD9C505A40D1BA1353F2AE15C0E9E5550D9D505A40532C704209AF15C0AC22FD3A9D505A40AACFD75C20AF15C033167D569D505A405B140B9437AF15C03FCAC45F9D505A4040A7B8D94EAF15C02285CE569D505A401447861F66AF15C047CD9F3B9D505A40639E19577DAF15C0C965490E9D505A40921D217294AF15C01C44E7CE9C505A4094CF5C62ABAF15C001030000000100000081000000312E9C6654505A40BA80EF1806AA15C0E869A20354505A4034AB43891CAA15C02538338F53505A40E3C3CCA432AA15C05C67960953505A40E265E85D48AA15C0295E1E7352505A4032E030A75DAA15C080E827CC51505A407A78857372AA15C073FE191551505A40DB8312B686AA15C0B384654E50505A40475059629AAA15C0F00685784F505A40E6D8376CADAA15C0466CFC934E505A40EE41F0C7BFAA15C0E3A558A14D505A406716306AD1AA15C01F582FA14C505A40BC431748E2AA15C02D7E1E944B505A40E0CE3E57F2AA15C0B208CC7A4A505A40873EBF8D01AB15C06B77E55549505A4005B736E20FAB15C02F6E1F2648505A407AC3CE4B1DAB15C0814535EC46505A4071C941C229AB15C00D97E8A845505A408D22E03D35AB15C03DC6005D44505A403CDA94B73FAB15C041854A0943505A40200CEA2849AB15C0D25697AE41505A40A9DF0C8C51AB15C0F80CBD4D40505A40921FD1DB58AB15C0304595E73E505A40FE6AB4135FAB15C02EE2FC7C3D505A401DFDE02F64AB15C0AB83D30E3C505A40BA0A302D68AB15C072FCFA9D3A505A40B9B32B096BAB15C01CC7562B39505A40F78710C26CAB15C0C979CBB737505A40219DCE566DAB15C01A393E4436505A40F1360AC76CAB15C0EA2A94D134505A405EFF1B136BAB15C0F1E8B16033505A4057D0103C68AB15C0CEF37AF231505A40630DA94364AB15C0B126D18730505A40B28F572C5FAB15C0162C94212F505A40212340F958AB15C0CAF3A0C02D505A408C9635AE51AB15C0B32AD1652C505A401F60B74F49AB15C085B4FA112B505A4082D7EEE23FAB15C0DF27EFC529505A407206AC6D35AB15C0054D7B8228505A40111362F629AB15C0949F664827505A40F14523841DAB15C07DD3721826505A405CAD9C1E10AB15C08B5D5BF324505A403F6111CE01AB15C0C5FFD4D923505A40F66A559BF2AA15C0F8598DCC22505A403F53C88FE2AA15C0A27E2ACC21505A40775A4FB5D1AA15C0818C4AD920505A40195E4F16C0AA15C0164D83F41F505A40D06FA6BDADAA15C03CD8611E1F505A409621A5B69AAA15C02F3D6A571E505A40448B070D87AA15C00E3117A01D505A40ED0DEECC72AA15C03AC3D9F81C505A40F8D8D5025EAA15C0921719621C505A40C23691BB48AA15C0E22632DC1B505A400AA43F0433AA15C0838577671B505A40DFB745EA1CAA15C0773031041B505A409FE1447B06AA15C0FF609CB21A505A40310013C5EFA915C0DC66EB721A505A4043DAB1D5D8A915C0468945451A505A40827A46BBC1A915C0BBEEC6291A505A407C761084AAA915C09A8B80201A505A400725613E93A915C0B61778291A505A40B0C992F87BA915C0D20AA8441A505A40C1BAFFC064A915C003A0FF711A505A404087F9A54DA915C014E062B11A505A403422C0B536A915C0BEB2AA021B505A40E41879FE1FA915C0C9F6A4651B505A406DD9268E09A915C0F8A014DA1B505A408D0EA072F3A815C0B0E1B15F1C505A40811787B9DDA815C040512AF61C505A40B49E4170C8A815C0B722219D1D505A401057F0A3B3A815C0215D2F541E505A404DE366619FA815C0071BE41A1F505A409FEC23B58BA815C012D0C4F01F505A40646E49AB78A815C09B944DD520505A40743A954F66A815C00F77F1C721505A4064BB59AD54A815C0D1D21AC822505A401EF976CF43A815C08AAC2BD523505A40C7E353C033A815C096137EEE24505A40B0E9D78924A815C05B88641326505A4083DB643516A815C04C672A4327505A403B23D1CB08A815C04A58147D28505A40A7506255FCA715C033C260C029505A40C8FFC7D9F0A715C04742480C2B505A403C1B1760E6A715C01D27FE5F2C505A40F17DC5EEDCA715C0DFEEB0BA2D505A40A9F7A58BD4A715C081C88A1B2F505A4080B5E43BCDA715C09E17B28130505A40F8100404C7A715C0A8FA49EC31505A4054C8D9E7C1A715C022D3725A33505A4027A18CEABDA715C08ECF4ACB34505A40DB76920EBBA715C0A576EE3D36505A40E6B5AE55B9A715C0AA3379B137505A40F445F1C0B8A715C05DE3052539505A40B4E1B550B9A715C04A61AF973A505A40ACDEA304BBA715C01B1591083C505A407963AEDBBDA715C0927FC7763D505A403D0E15D4C1A715C0D1C670E13E505A40750865EBC6A715C0AA41AD4740505A40058A7A1ECDA715C08801A0A841505A40CAC88269D4A715C0B15A6F0343505A404154FEC7DCA715C0836A455744505A405FDBC334E6A715C05C9B50A345505A40C95B03AAF0A715C0D825C4E646505A408BB74921FCA715C0228FD82048505A40EEAE849308A815C0F223CC5049505A401F3D07F915A815C00570E3754A505A4026548E4924A815C0BAB1698F4B505A4003F5457C33A815C08949B19C4C505A40ADA1CE8743A815C01925149D4D505A40A424436254A815C0A825F48F4E505A4077AB3E0166A815C09581BB744F505A406D2FE35978A815C0BA20DD4A50505A407929E0608BA815C078F3D41151505A40668C790A9FA815C0224428C951505A4085018F4AB3A815C0B302667052505A405663A314C8A815C0800A270753505A40F070E45BDDA815C0DE610E8D53505A4069B63213F3A815C07473C90154505A40D2A4292D09A915C02B41106554505A402DD4279C1FA915C09C90A5B654505A40226C575236A915C0C71057F654505A40A1ABB6414DA915C02B79FD2355505A40AF8C205C64A915C0F5A17C3F55505A406A7D55937BA915C06495C34855505A40A72904D992A915C0449ACC3F55505A406F4FD21EAAA915C06C379D2455505A40F9986556C1A915C0623046F754505A40B5766C71D8A915C0FE7AE3B754505A40F3F3A661EFA915C0312E9C6654505A40BA80EF1806AA15C001030000000100000081000000F2F334ECD44F5A40B0FC21AAF2A115C0EAA8EC9AD44F5A40AF52676109A215C075F8F137D44F5A408948B7D11FA215C02AED81C3D34F5A4055313BED35A215C00056E43DD34F5A405FAB50A64BA215C00F9A6BA7D24F5A40740992EF60A215C0B9857400D24F5A409E95DEBB75A215C073116649D14F5A40F0A962FE89A215C04522B182D04F5A40E3999FAA9DA215C02344D0ACCF4F5A40BA6673B4B0A215C0695E47C8CE4F5A40443B2010C3A215C07262A3D5CD4F5A40B0A953B2D4A215C0B7F479D5CC4F5A4011A72D90E5A215C0811069C8CB4F5A407C40479FF5A215C079A616AFCA4F5A403E05B9D504A315C05636308AC94F5A40BA22212A13A315C0DA636A5AC84F5A40902DA99320A315C066878020C74F5A4026950B0A2DA315C07A3A34DDC54F5A4060BD988538A315C041E04C91C44F5A4050BC3BFF42A315C0A42A973DC34F5A4086B87E704CA315C0039CE4E2C14F5A40AFE48ED354A315C007060B82C04F5A400D1740235CA315C0BB05E41BBF4F5A4082FA0F5B62A315C05B7D4CB1BD4F5A403CD6287767A315C0160C2443BC4F5A4034EB63746BA315C026844CD2BA4F5A409F654B506EA315C0885FA95FB94F5A40D2E11B0970A315C0B0331FECB74F5A400A82C59D70A315C08F249378B64F5A409C96EC0D70A315C04357EA05B54F5A4031D6E9596EA315C0BD640995B34F5A406127CA826BA315C0CDCCD326B24F5A405AFA4D8A67A315C0CE692BBCB04F5A40EA34E87262A315C057E5EF55AF4F5A406DAFBC3F5CA315C0542EFEF4AD4F5A4027459EF454A315C0B9F02F9AAC4F5A4088780C964CA315C0470F5B46AB4F5A404AAD302943A315C0A31F51FAA94F5A4010F9DAB338A315C014E9DEB6A84F5A40A18D7E3C2DA315C031E6CB7CA74F5A40F3BE2DCA20A315C0E4C9D94CA64F5A406AA6956413A315C0ED07C427A54F5A40BF66F91305A315C047613F0EA44F5A40C1132DE1F5A215C0B174F900A34F5A40434090D5E5A215C096539800A24F5A40563608FBD4A215C0A61BBA0DA14F5A40C0DCF95BC3A215C04F95F428A04F5A40034E4303B1A215C05DD7D4529F4F5A407B2435FC9DA215C0FCEFDE8B9E4F5A40F67F8B528AA215C03F938DD49D4F5A40EBC8661276A215C07BCF512D9D4F5A40AF35444861A215C08DC792969C4F5A400017F6004CA215C03973AD109C4F5A4070EF9B4936A215C0DD65F49B9B4F5A405A5B9A2F20A215C0809BAF389B4F5A40D0CE92C009A215C0704C1CE79A4F5A40D82C5B0AF3A115C082C76CA79A4F5A40A83FF51ADCA115C00753C8799A4F5A40DE148600C5A115C09F144B5E9A4F5A405E444DC9ADA115C0D1FF05559A4F5A40AF269C8396A115C0A4CBFE5D9A4F5A407900CD3D7FA115C015EF2F799A4F5A4084283A0668A115C07EA488A69A4F5A40A82D35EB50A115C0F9F3ECE59A4F5A403302FEFA39A115C096C435379B4F5A400232BA4323A115C082F4309A9B4F5A4036296CD30CA115C0EF77A10E9C4F5A40F68FEAB7F6A015C0BB7E3F949C4F5A4042C2D7FEE0A015C0BBA0B82A9D4F5A40BA6699B5CBA015C09410B0D19D4F5A40E62B50E9B6A015C0ECD4BE889E4F5A4088AFCFA6A2A015C0F907744F9F4F5A40439596FA8EA015C01B1D5525A04F5A4067D2C6F07BA015C0732CDE09A14F5A402F321E9569A015C03D4482FCA14F5A400A18EFF257A015C0BCBFABFCA24F5A403F84191547A015C087A3BC09A44F5A40D35E040637A015C0F2FE0E23A54F5A40800D97CF27A015C06C52F547A64F5A40EA57337B19A015C07BFABA77A74F5A40949EAF110CA015C0249FA4B1A84F5A407567519BFF9F15C074A7F0F4A94F5A405044C81FF49F15C0E5B0D740AB4F5A402C1529A6E99F15C0580A8D94AC4F5A4016AAE934E09F15C04F323FEFAD4F5A4094C7DCD1D79F15C01F581850AF4F5A40478F2E82D09F15C0D2DF3EB6B04F5A40F84E614ACA9F15C054E8D520B24F5A40F9B84A2EC59F15C0B1D3FD8EB34F5A40B3861131C19F15C0FAD0D4FFB44F5A4051872B55BE9F15C088677772B64F5A40D51A5C9CBC9F15C0450301E6B74F5A40631CB307BC9F15C0A2818C59B94F5A40153A8C97BC9F15C0E9BE34CCBA4F5A40CCBC8E4BBE9F15C08923153DBC4F5A4083BEAD22C19F15C010314AABBD4F5A40BAD0281BC59F15C07C0EF215BF4F5A405A108D32CA9F15C07A132D7CC04F5A40CBA8B665D09F15C05C521EDDC14F5A4086C3D2B0D79F15C05520EC37C34F5A40CAE3610FE09F15C0B79BC08BC44F5A407BAC3A7CE99F15C0D92FCAD7C54F5A405F0F8DF1F39F15C057163C1BC74F5A40DEE2E568FF9F15C05BD54E55C84F5A40DCDB32DB0BA015C0A6BA4085C94F5A4068EAC64019A015C0005356AACA4F5A40C4F55E9127A015C0D2DDDAC3CB4F5A4079F426C436A015C0A4BC20D1CC4F5A40625EBFCF46A015C02BDE81D1CD4F5A404FF442AA57A015C0B82460C4CE4F5A4079DA4C4969A015C0B8C725A9CF4F5A404F01FFA17BA015C017B0457FD04F5A4054D908A98EA015C043CF3B46D14F5A40634DAE52A2A015C09D708DFDD14F5A4059FFCE92B6A015C02785C9A4D24F5A40C9C2ED5CCBA015C040E9883BD34F5A40585038A4E0A015C03DA46EC1D34F5A40442E8F5BF6A015C0C6212836D44F5A4047C88D750CA115C0BC646D99D44F5A40A9B192E422A115C0AA3301EBD44F5A40E90DC89A39A115C0813EB12AD54F5A4063182C8A50A115C0A13D5658D54F5A4025C899A467A115C01B0AD473D54F5A40F088D1DB7EA115C003AF197DD54F5A40DA04822196A115C0F3732174D54F5A40C9F85067ADA115C088E0F058D54F5A40740EE49EC4A115C005B9982BD54F5A4068B6E9B9DBA115C0F2F334ECD44F5A40B0FC21AAF2A115C001030000000100000081000000BF5E32AC30505A40FC057C38B59715C00A36EB5A30505A402908C4EFCB9715C0FDB8F1F72F505A40BD471760E29715C06CF182832F505A40CC159F7BF89715C08BADE6FD2E505A40390EB9340E9815C09E536F672E505A401181FF7D239815C02EAF79C02D505A4042B5514A389815C0CCB76C092D505A406001DC8C4C9815C09551B9422C505A4014B51F39609815C08E07DA6C2B505A4075CDFA42739815C016C052882A505A40D870AF9E859815C0896BB09529505A409E2CEB40979815C05CAD889528505A40BAF0CD1EA89815C0CC7F798827505A40DBC4F02DB89815C075D2286F26505A409F326C64C79815C0FC23444A25505A407861DEB8D59815C00B17801A24505A40CEDF7022E39815C0EE0298E022505A409716DE98EF9815C00A804D9D21505A400E637614FB9815C06FF0675120505A4066D4248E059915C0E904B4FD1E505A401E8A73FF0E9915C0C23E03A31D505A40ACAF8F62179915C0856E2B421C505A40EC134DB21E9915C0263006DC1A505A403A5A29EA249915C0CC64707119505A4023C24E062A9915C093AA490318505A40E08496032E9915C0A6D2739216505A40CFC68ADF309915C0F655D21F15505A40671C6898329915C0F4C849AC13505A40F29F1E2D339915C08F4EBF3812505A40D699529D329915C0EA0A18C610505A40C0B85CE9309915C0069638550F505A4055DB49122E9915C0C66E04E70D505A40DE69DA192A9915C09F6E5D7C0C505A4045428102259915C0513E23160B505A40233562CF1E9915C0F5CB32B509505A4001165084179915C0B4C2655A08505A40BD5FCA250F9915C09304920607505A40986EFAB8059915C0842689BA05505A40DE50B043FB9815C023EF177704505A4035315FCCEF9815C06CD8053D03505A40935C195AE39815C0B694140D02505A4099E58BF4D59815C03B97FFE700505A4069E8F9A3C79815C07FA07BCEFF4F5A4080723771B89815C0D24E36C1FE4F5A409B10A465A89815C041B3D5C0FD4F5A40F206258B979815C02AEBF7CDFC4F5A40BA361FEC859815C0B5BE32E9FB4F5A4037B57093739815C079441313FB4F5A40CA176A8C609815C0758A1D4CFA4F5A409479C7E24C9815C0A344CC94F94F5A40B93EA9A2389815C04B8190EDF84F5A408E998CD8239815C04663D156F84F5A402AD743910E9815C069E2EBD0F74F5A40CD76EED9F89715C02D92325CF74F5A40E311F1BFE29715C0C46EEDF8F64F5A40E919ED50CC9715C0B0B059A7F64F5A40B06FB89AB59715C00DA7A967F64F5A409BDB54AB9E9715C07E98043AF64F5A40D669E790879715C001AB861EF64F5A4039B1AF59709715C08BD24015F64F5A409E09FF13599715C09BC6381EF64F5A4069B72FCE419715C0B3FE6839F64F5A407C119C962A9715C0BFB5C066F64F5A4032A7957B139715C076F423A6F64F5A40BD6B5C8BFC9615C090A26BF7F64F5A4048EC15D4E59615C0EE9E655AF74F5A409796C463CF9615C07FDED4CEF74F5A40E2143F48B99615C0E9917154F84F5A4095C5278FA39615C0D551E9EAF84F5A401852E4458E9615C0BD51DF91F94F5A40196C9579799615C02F99EC48FA4F5A40DEB40E37659615C04843A00FFB4F5A40E7D3CE8A519615C05EC47FE5FB4F5A40B2C2F7803E9615C0893507CAFC4F5A40FC5047252C9615C005A6A9BCFD4F5A400DE70F831A9615C01A72D1BCFE4F5A404A8A31A5099615C0689FE0C9FF4F5A402A281396F99515C0523E31E300505A40162C9C5FEA9515C05AD0150802505A40AC632E0BDC9515C01AB3D93703505A40AB35A0A1CE9515C0AD8FC17104505A40762E372BC29515C039CE0BB505505A4083E6A2AFB69515C0560DF10007505A40B544F835AC9515C0FC9CA45408505A402B20ADC4A29515C0C9FC54AF09505A40A24494619A9515C0295D2C100B505A4022DBD911939515C03C2351760C505A40F53800DA8C9515C0086FE6E00D505A400F18DDBD879515C0A7A30C4F0F505A40993997C0839515C03BF1E1BF10505A408574A4E4809515C024E0823212505A40B930C82B7F9515C053DD0AA613505A40415112977E9515C038C7941915505A402A8CDE267F9515C0177B3B8C16505A404032D4DA809515C04F621AFD17505A406D65E6B1839515C05DFF4D6B19505A4011BF54AA879515C01C7AF4D51A505A40EF63ACC18C9515C01A2B2E3C1C505A403187C9F4929515C076251E9D1D505A40FA59D93F9A9515C02FBFEAF71E505A401B675C9EA29515C05117BE4B20505A40E658290BAC9515C0E899C69721505A406D287080B69515C0398137DB22505A4035B3BDF7C19515C00D54491524505A401AB5FF69CE9515C0B4603A4525505A40E82489CFDB9515C07C344F6A26505A406BF01620EA9515C0490FD38327505A407D14D552F99515C00E53189128505A400B0F645E099615C0E1EE789129505A40B3A6DE381A9615C064C556842A505A403905E0D72B9615C04B0E1C692B505A404C208A303E9615C0B9B23B3F2C505A40666D8C37519615C046A431062D505A4006DC2AE1649615C06F2E83BD2D505A405E124521799615C04742BF642E505A40FEE75DEB8D9615C02ABC7EFB2E505A403619A332A39615C062A364812F505A408E2FF5E9B89615C07C631EF62F505A40B799EF03CF9615C030FF635930505A408EEDF072E59615C0D13CF8AA30505A40C6502329FC9615C00ECCA8EA30505A4095008518139715C0F7644E1831505A407CF5F0322A9715C03BE0CC3331505A40509C276A419715C08448133D31505A40D59FD7AF589715C0F3E41B3431505A403FBDA6F56F9715C0A33CEC1831505A402E9E3A2D879715C0421395EB30505A40B2B241489E9715C0BF5E32AC30505A40FC057C38B59715C0010300000001000000810000004C2BB51A434F5A40D48B62CC339315C0CBE56BC9424F5A40C554A4834A9315C0075A7066424F5A40A294EFF3609315C01D93FFF1414F5A4069A16D0F779315C07B60616C414F5A40041D7CC88C9315C09629E8D5404F5A408C5EB511A29315C01EBBF02E404F5A400CB5F8DDB69315C0C00DE2773F4F5A4045807220CB9315C0A5062DB13E4F5A400D1AA4CCDE9315C0D5314CDB3D4F5A409D8A6BD6F19315C0A376C3F63C4F5A406D040B32049415C051C61F043C4F5A40E72130D4159415C02AC5F6033B4F5A40F4E0FAB1269415C0326EE6F6394F5A40135804C1369415C0BEB194DD384F5A40882065F7459415C01A0FAFB8374F5A403672BB4B549415C08729EA88364F5A40B1EC30B5619415C0D758014F354F5A40DF0A802B6E9415C0E335B60B344F5A40883CF9A6799415C01E23D0BF324F5A4017A48720849415C0A7D11B6C314F5A40CA74B5918D9415C005C36A11304F5A406AEEAFF4959415C0F0C792B02E4F5A409DF44A449D9415C0787C6D4A2D4F5A40F23F047CA39415C0CCC1D7DF2B4F5A408F250698A89415C0FC35B1712A4F5A409DF42995AC9415C016AADB00294F5A40A9E7F970AF9415C0E0963A8E274F5A4091A9B229B19415C08490B21A264F5A403A6B44BEB19415C0A4B928A7244F5A40B78B532EB19415C0FB358234234F5A4075D0387AAF9415C0139DA3C3214F5A40DA2E01A3AC9415C0476D7055204F5A40E0256DAAA89415C0767FCAEA1E4F5A400BAAEF92A39415C0B47B91841D4F5A4059A2AC5F9D9415C05F4FA2231C4F5A4091F87614969415C0DAA4D6C81A4F5A407C3DCEB58D9415C0515D0475194F5A40F6E2DB48849415C0CC0CFD28184F5A40870C70D3799415C0F4788DE5164F5A40A8F9FD5B6E9415C0C11A7DAB154F5A40A10B98E9619415C079A38D7B144F5A40DE68EB83549415C03B857A56134F5A40C1403B33469415C0627FF83C124F5A4061B35B00379415C00C2FB52F114F5A40685FACF4269415C009A4562F104F5A404E9A121A169415C071FA7A3C0F4F5A40BF55F37A049415C01BF9B7570E4F5A40B7B62C22F29315C049B59A810D4F5A406E610F1BDF9315C09E3BA7BA0C4F5A40087F5771CB9315C0AE3E58030C4F5A40C0802531B79315C058CB1E5C0B4F5A401DA5F666A29315C0090362C50A4F5A4066449D1F8D9315C023DC7E3F0A4F5A401DE83868779315C0AEE8C7CA094F5A40E6322E4E619315C064238567094F5A406B9E1EDF4A9315C056C3F315094F5A40A212E028349315C0251646D6084F5A40015E74391D9315C00161A3A8084F5A40B791001F069315C076C8278D084F5A407748C4E7EE9215C0093FE483084F5A40EDDC10A2D79215C0CC7ADE8C084F5A402995405CC09215C0D8F110A8084F5A409FC8AD24A99215C0BADD6AD5084F5A402006AA09929215C0C745D014094F5A40323F75197B9215C069101A66094F5A403FFE3462649215C02E1B16C9094F5A402BADEBF14D9215C0C459873D0A4F5A4039F16FD6379215C095FB25C30A4F5A40C722641D229215C019989F590B4F5A4021E42DD40C9215C0A66197000C4F5A40CFDEED07F89115C0AE5EA6B70C4F5A40E5AA77C5E39115C043A95B7E0D4F5A40B6E54919D09115C0B8B43C540E4F5A408F7D860FBD9115C03499C5380F4F5A400E36EBB3AA9115C00C65692B104F5A406B6ACA11999115C0B673922B114F5A401A120434889115C007CAA238124F5A40C10BFF24789115C0B077F451134F5A4027B3A2EE689115C087FDD976144F5A407FC5509A5A9115C094B89EA6154F5A405B98DF304D9115C06C5187E0164F5A403FA694BA409115C0C22FD223184F5A4014751F3F359115C0C9F1B76F194F5A4099D894C52A9115C02BE76BC31A4F5A402D946A54219115C0438F1C1E1C4F5A40505F73F1189115C0581AF47E1D4F5A40484EDBA1119115C06BED18E51E4F5A4039A1246A0B9115C07A28AE4F204F5A408FFC244E069115C0AC2ED4BD214F5A40930B0351029115C03C30A92E234F5A40158F3475FF9015C0BCB549A1244F5A40A2D87CBCFD9015C05D2CD114264F5A40BFB4EB27FD9015C0E1725A88274F5A40D8C2DCB7FD9015C0F06600FB284F5A40083DF76BFF9015C06272DE6B2A4F5A408A2E2E43029115C0391811DA2B4F5A401B1AC13B069115C0EB80B6442D4F5A40F30D3D530B9115C0AA05EFAA2E4F5A40D8267E86119115C054BADD0B304F5A40CE7FB1D1189115C0AAF5A866314F5A40BD8D5730219115C094D77ABA324F5A4060E5469D2A9115C004CD8106344F5A409D6AAF12359115C03311F149354F5A402EE61D8A409115C0EB2B0184364F5A409FFF7FFC4C9115C08E6CF0B3374F5A40F59928625A9115C0826103D9384F5A40C58FD4B2689115C0D44B85F2394F5A404FCBAFE5779115C0A98EC8FF3A4F5A408BB85AF1879115C0511A27003C4F5A40DF0CF0CB989115C0B6D202F33C4F5A408FE10A6BAA9115C0D7F0C5D73D4F5A40941CCDC3BC9115C02F5FE3AD3E4F5A408724E6CACF9115C0B210D7743F4F5A40DCDA9974E39115C04152262C404F5A40A2D8C7B4F79115C0551660D3404F5A4035E9F27E0C9215C0B93A1D6A414F5A40A4BD48C6219215C028C800F0414F5A402BD5A97D379215C09E2BB864424F5A403895B1974D9215C04B69FBC7424F5A406A8BBE06649215C0F8488D19434F5A4040D6FABC7A9215C0C87B3B59434F5A40CFAC64AC919215C040BBDE86434F5A408D02D7C6A89215C081E15AA2434F5A40564012FEBF9215C0A9FA9EAB434F5A401A0EC543D79215C0424FA5A2434F5A404B279589EE9215C0D0677387434F5A40E63428C1059315C065091A5A434F5A407BA72CDC1C9315C04C2BB51A434F5A40D48B62CC339315C0010300000001000000EF0000002BA5A7FDC24E5A40C844C56E718415C0546BAB9AC24E5A40ED6B0CDF878415C09C153A26C24E5A40D65C85FA9D8415C0CB739BA0C14E5A408EBC8DB3B38415C09AED210AC14E5A40F7E5BFFCC88415C0EB4F2A63C04E5A407C2CFBC8DD8415C087931BACBF4E5A40D4F46B0BF28415C0A39D66E5BE4E5A40649E93B7058515C03CFA850FBE4E5A408F3750C1188515C08490FD2ABD4E5A4076F9E31C2B8515C08F515A38BC4E5A40C185FCBE3C8515C060E13138BB4E5A401EE2B99C4D8515C0A33A222BBA4E5A40502DB5AB5D8515C03F4DD111B94E5A40570907E26C8515C00198ECECB74E5A4050B74D367B8515C099BD28BDB64E5A407BE0B29F888515C033154183B54E5A40CC09F115958515C0F136F73FB44E5A408AAD5891A08515C0808412F4B24E5A40F1F8D40AAB8515C023AE5FA0B14E5A40762AF07BB48515C07834B045B04E5A405C8DD7DEBC8515C03EE7D9E4AE4E5A4014115F2EC48515C07A61B67EAD4E5A403D7A0466CA8515C043832214AC4E5A40422AF281CF8515C084E9FDA5AA4E5A40C37C017FD38515C01B642A35A94E5A40F9B8BC5AD68515C0866A8BC2A74E5A408A966013D88515C0AB8F054FA64E5A404353DDA7D88515C0CFF47DDBA44E5A402C5BD717D88515C04FBCD968A34E5A40BD80A763D68515C0497CFDF7A14E5A4064C65A8CD38515C0A7B1CC89A04E5A401CB8B193CF8515C0CC33291F9F4E5A4065571F7CCA8515C04BA9F2B89D4E5A402398C748C48515C0FBFD05589C4E5A40E3707DFDBC8515C0B4DA3CFD9A4E5A40107FC09EB48515C0111F6DA9994E5A400141BA31AB8515C0885D685D984E5A4085E63ABCA08515C02E5AFB19974E5A4013BBB544958515C0668CEDDF954E5A40C42B3DD2888515C0E1A300B0944E5A407D6A7E6C7B8515C02911F08A934E5A40C9B1BC1B6D8515C008927071924E5A40932CCCE85D8515C00DC22F64914E5A40F9830CDD4D8515C07BAFD363904E5A40851763023D8515C0E474FA708F4E5A4088E234632B8515C0A3D7398C8E4E5A402A13600A198515C07AEB1EB68D4E5A4068563503068515C09EBB2DEF8C4E5A40A4DD7059F28415C039F9E0378C4E5A40D7213319DE8415C0CAAFA9908B4E5A40C368F94EC98415C067FFEEF98A4E5A405D119607B48415C02BDD0D748A4E5A404BAB28509E8415C0DCD958FF894E5A40BADE1536888415C005EF179C894E5A40532AFFC6718415C09052884A894E5A406C7ABA105B8415C00A51DC0A894E5A403EA14921448415C09B2E3BDD884E5A4021B3D1062D8415C0D50EC1C1884E5A40514D92CF158415C057E37EB8884E5A4061CCDC89FE8315C05C617AC1884E5A40A6770B44E78315C035FEADDC884E5A4038A7780CD08315C0B9F2080A894E5A40EBE975F1B88315C09F456F49894E5A409E304301A28315C0BBDCB99A894E5A407404064A8B8315C02195B6FD894E5A406BCDC0D9748315C0146228728A4E5A40382E4ABE5E8315C0A472C7F78A4E5A40197C4405498315C0085E418E8B4E5A40915515BC338315C0645639358C4E5A40CA5FDDEF1E8315C00F6248EC8C4E5A40DE2D70AD0A8315C0119BFDB28D4E5A408F574C01F78215C0CA74DE888E4E5A4011C593F7E38215C07D07676D8F4E5A405133049CD18215C0B5610A60904E5A4056F6EFF9BF8215C02ADF3260914E5A40D0FD361CAF8215C01085426D924E5A402B20400D9F8215C081639386934E5A407AB0F2D68F8215C0D6FB77AB944E5A40BC62B082818215C05B86ACCB954E5A40C1142CC9748215C099F6FA8B954E5A40FB078947758215C0E7795C19944E5A4048952900778215C0DB1ED7A5924E5A4006FCA294778215C06E065032914E5A4051AA9904778215C0AC52ACBF8F4E5A40AF746650758215C06399D04E8E4E5A40A25F1679728215C02757A0E08C4E5A4038F969806E8215C00663FD758B4E5A40FE44D468698215C04163C70F8A4E5A40E7387935638215C05843DBAE884E5A4089CD2BEA5B8215C0CDAB1254874E5A4053A26B8B538215C0E47B4300864E5A409837621E4A8215C0BF453FB4844E5A401DBFDFA83F8215C01BCDD270834E5A4046865731348215C00589C536824E5A400CFCDBBE278215C0DB28D906814E5A4028541A591A8215C0D11CC9E17F4E5A40F3CA55080C8215C05F224AC87E4E5A40108D62D5FC8115C0C1D409BB7D4E5A404E45A0C9EC8115C0EB41AEBA7C4E5A40CE54F4EEDB8115C01F84D5C77B4E5A4076B8C34FCA8115C06A6015E37A4E5A40E29FECF6B78115C048EAFA0C7A4E5A4079B9BFEFA48115C09F2C0A46794E5A40F537F945918115C056D8BD8E784E5A408D95B9057D8115C0A7F886E7774E5A402C197E3B688115C069ADCC50774E5A40E12219F4528115C076EBEBCA764E5A404C43AA3C3D8115C059433756764E5A4084239622278115C066AEF6F2754E5A4005437EB3108115C0516267A1754E5A40DA8E38FDF98015C075ABBB61754E5A40E0D9C60DE38015C0CFCD1A34754E5A40EE384EF3CB8015C0C4ECA018754E5A40B7490EBCB48015C0CCF95E0F754E5A401C6958769D8015C001AA5A18754E5A40AFDE8630868015C094728E33754E5A40A802F4F86E8015C0428CE960754E5A40E263F1DD578015C0AAFD4FA0754E5A4028F3BEED408015C08DAC9AF1754E5A40713982362A8015C0F4759754764E5A40769E3DC6138015C0124D09C9764E5A4088C4C7AAFD7F15C0F760A84E774E5A406C00C3F1E77F15C0D24822E5774E5A4017F094A8D27F15C0CD361A8C784E5A4001385EDCBD7F15C045312943794E5A40816AF299A97F15C04C52DE097A4E5A40821ED0ED957F15C0500DBFDF7A4E5A40433B19E4827F15C0A87A47C47B4E5A40A97C8B88707F15C0F7A8EAB67C4E5A40943579E65E7F15C010F412B77D4E5A408A54C2084E7F15C0446122C47E4E5A40A8AECDF93D7F15C0D20073DD7F4E5A40A19582C32E7F15C039545702814E5A4007BC426F207F15C03AB91A32824E5A404B6CE405137F15C042D9016C834E5A405315AD8F067F15C0E81C4BAF844E5A40F4304C14FB7E15C05F232FFB854E5A407086D69AF07E15C0623DE14E874E5A403CCCC129E77E15C072EB8FA9884E5A4096ACE0C6DE7E15C00A5F650A8A4E5A402A2E5F77D77E15C07AFE87708B4E5A403983BF3FD17E15C018EB1ADB8C4E5A40FD41D723CC7E15C079893E498E4E5A405A07CD26C87E15C0510B11BA8F4E5A408885164BC57E15C0BEFAAE2C914E5A4048FF7692C37E15C088C633A0924E5A403F32FEFDC27E15C0174FBA13944E5A40D4AE078EC37E15C0C2735D86954E5A4017A03A42C57E15C01CA038F7964E5A4030028A19C87E15C0EE586865984E5A40CB483512CC7E15C07AC80AD0994E5A401D73C929D17E15C0C64940369B4E5A40018F225DD77E15C08BF22B979C4E5A40A9A86DA8DE7E15C06F1BF4F19D4E5A405B262B07E77E15C039E6C2459F4E5A405F8E3174F07E15C0C6C1C691A04E5A405EB6B0E9FA7E15C035EB32D5A14E5A401C593561067F15C03EEC3F0FA34E5A407E10ADD3127F15C028162C3FA44E5A402FB26A39207F15C043F93B64A54E5A40CC0B2B8A2E7F15C07FD8BA7DA64E5A40FBFA19BD3D7F15C0E018FB8AA74E5A4092DFD7C84D7F15C094AC568BA84E5A403D637FA35E7F15C058792F7EA94E5A400394AB42707F15C0F7B9EF62AA4E5A40284D7E9B827F15C0B25A0A39AB4E5A4011EBA6A2957F15C03650FBFFAB4E5A409745694CA97F15C015E947B7AC4E5A40B8ECA48CBD7F15C06A197F5EAD4E5A405EA3DC56D27F15C099C039F5AD4E5A40C6123E9EE77F15C0E5E81A7BAE4E5A4003B3A955FD7F15C0C400D0EFAE4E5A40FCE2BA6F138015C0D10D1153AF4E5A40762AD0DE298015C030D9A0A4AF4E5A40D1A21395408015C04B154DE4AF4E5A40A97E8384578015C0DE7CEE11B04E5A40BBADFA9E6E8015C02FEB682DB04E5A40E69539D6858015C0686DAB36B04E5A40CBDCEE1B9D8015C0124DB02DB04E5A405A3CC061B48015C095137D12B04E5A40BE5C5399CB8015C0D58622E5AF4E5A4077AE56B4E28015C0D99EBCA5AF4E5A40013F8AA4F98015C08A747254AF4E5A409F82C85B108115C09C2976F1AE4E5A40CE0D0FCC268115C0A1C9047DAE4E5A40733987E73C8115C0652466F7AD4E5A4012AB8EA0528115C0A7A1EC60AD4E5A401FBEBFE9678115C0450EF5B9AC4E5A40B2C6F9B57C8115C00263E602AC4E5A40492A69F8908115C00885313CAB4E5A4020498FA4A48115C045005166AA4E5A4090324AAEB78115C0DABBC881A94E5A40C720DC09CA8115C0C2A8258FA84E5A408CB6F2ABDB8115C0E66AFD8EA74E5A40C3FAAD89EC8115C0D4FCED81A64E5A407A0DA798FC8115C04E4E9D68A54E5A401392F6CE0B8215C0FDDDB843A44E5A4018CB3A231A8215C0AF728423A34E5A4084B3C0DC268215C0FBFE3563A34E5A406470635E268215C0346BD4D5A44E5A407D9AC0A5248215C0B7B65949A64E5A4007784411248215C09FC1E0BCA74E5A407B9B4AA1248215C0F16A842FA94E5A40F4317A55268215C0EF1D60A0AA4E5A40AF39C62C298215C00D5F900EAC4E5A4066286E252D8215C03B583379AD4E5A4063FFFE3C328215C02C6469DFAE4E5A4088CE5470388215C041985540B04E5A4013A49CBB3F8215C0C94C1E9BB14E5A404BE8561A488215C03AA3EDEEB24E5A407A235A87518215C0150AF23AB44E5A40392DD6FC5B8215C027BE5E7EB54E5A403FC25774678215C0D1486CB8B64E5A40497ECCE6738215C006FB58E8B74E5A40E638874C818215C0C164690DB94E5A4074C1449D8F8215C09FC8E826BA4E5A405BF730D09E8215C0558B2934BB4E5A401D3CECDBAE8215C0BE9E8534BC4E5A40053B91B6BF8215C047E85E27BD4E5A40A903BB55D18215C072A21F0CBE4E5A40CD728BAEE38215C032B93AE2BE4E5A403BE6B1B5F68215C0EC202CA9BF4E5A402637725F0A8315C0EB277960C04E5A40CCF6AB9F1E8315C008C2B007C14E5A4049E9E169338315C064CE6B9EC14E5A40ECB841B1488315C004574D24C24E5A40CCDEAB685E8315C022CA0299C24E5A40B9BABB82748315C0232D44FCC24E5A4050D5CFF18A8315C0F348D44DC34E5A40A14812A8A18315C0CCCF808DC34E5A40F2478197B88315C03B7C22BBC34E5A4086C3F7B1CF8315C05B299DD6C34E5A40AB2136E9E68315C032E4DFDFC34E5A405A08EB2EFE8315C023F6E4D6C34E5A40B931BC74158415C078E8B1BBC34E5A401A464FAC2C8415C0FB80578EC34E5A4005B652C7438415C099B7F14EC34E5A40E18E86B75A8415C02BA5A7FDC24E5A40C844C56E718415C0010300000001000000810000002AE441E063535A40FB431BC080D715C099D6008F63535A405C39777797D715C00DE90C2C63535A40D4EAE4E7ADD715C0EE21A3B762535A4034998D03C4D715C0564C0B3262535A4025CCCEBCD9D715C0CACB979B61535A4083BB4206EFD715C07569A5F460535A403392C8D203D815C0E31A9B3D60535A40FB868C1518D815C088C2E9765F535A40EDC50FC22BD815C027EA0BA15E535A40EE2430CC3ED815C0357785BC5D535A40959F2F2851D815C08E59E3C95C535A401695BBCA62D815C08034BBC95B535A40E0C3F3A873D815C08702ABBC5A535A40EBFE70B883D815C0E0B358A359535A4006984BEF92D815C02EC8717E58535A40DE7B2144A1D815C07EE3AA4E57535A4051FB1BAEAED815C0DB5EBF1456535A401D3FF524BBD815C0C7D470D154535A40C861FDA0C6D815C0D1A9868553535A40752D1F1BD1D815C09A91CD3152535A406C7AE48CDAD815C09D1017D750535A40E62A7AF0E2D815C0F0FA38764F535A40B3C2B340EAD815C064F00C104E535A4081980E79F0D815C051D66FA54C535A40B49DB495F5D815C0574F41374B535A4020BC7E93F9D815C0723163C649535A40A8C7F66FFCD815C0AEFAB85348535A405F035929FED815C0DC4427E046535A40893795BEFED815C09838936C45535A40025A4F2FFED815C0EAFFE1F943535A40A5C6DF7BFCD815C0FA38F88842535A40360953A5F9D815C00969B91A41535A402F3769ADF5D815C0227007B03F535A400BDC9496F0D815C0CDFDC1493E535A406676F963EAD815C01107C6E83C535A4093886919E3D815C0383EED8D3B535A401A3D64BBDAD815C0878C0D3A3A535A4002A1124FD1D815C0518EF8ED38535A40AA7444DAC6D815C0AC117BAA37535A4044966C63BBD815C02A985C7036535A4000089DF1AED815C0C6DB5E4035535A408C93828CA1D815C06C573D1B34535A402A0E603C93D815C05ED3AC0133535A409840090A84D815C0A9F55AF431535A403575DDFE73D815C018D7EDF330535A4065B0C12463D815C0C39C030130535A4031961A8651D815C07F16321C2F535A408301C62D3FD815C0826206462E535A40575014272CD815C05796047F2D535A408269C17D18D815C06A6DA7C72C535A400C80ED3D04D815C056FD5F202C535A408F981574EFD715C0297095892B535A40D2D50B2DDAD715C0C5C4A4032B535A404D90EF75C4D715C08695E08E2A535A404F3E255CAED715C04FE5902B2A535A40EC314EED97D715C029F3F2D929535A405630403781D715C07414399A29535A4037EAFC476AD715C0E4958A6C29535A40DD57A92D53D715C04AA3035129535A40430085F63BD715C02836B54729535A406A2FE1B024D715C0460BA55029535A40D921186B0DD715C0279FCD6B29535A40AB2A8433F6D615C06C311E9929535A4081D97618DFD615C031CF7AD829535A40DD253028C8D615C04564BC292A535A4047A5D570B1D615C046D3B08C2A535A40E9D169009BD615C091141B012B535A405766C3E484D615C0DD5BB3862B535A4057D5842B6FD615C08A44271D2C535A408BE013E259D615C071041AC42C535A40B755911545D615C01EA5247B2D535A40FCF5D0D230D615C04F43D6412E535A406A8C51261DD615C09A54B4172F535A40AB39351C0AD615C0F9F23AFC2F535A402DF839C0F7D515C0292EDDEE30535A40555EB21DE6D515C0916205EF31535A40F5A27E3FD5D515C08E9515FC32535A401AE80530C5D515C0E3D6671534535A40DED02FF9B5D515C00DA74E3A35535A4074655EA4A7D515C04362156A36535A40FD49683A9AD515C0DEAF00A437535A40E54A93C38DD515C0E7F54EE738535A4022438F4782D515C076D038333A535A406D5E71CD77D515C0AE8CF1863B535A40E7BAAF5B6ED515C0FAA6A7E13C535A404A6D1DF865D515C03F4C85423E535A406DE9E6A75ED515C0C1DDB0A83F535A4010D18E6F58D515C053774D1341535A40072CEB5253D515C093777B8142535A40AC0A23554FD515C0D00959F243535A402C94AC784CD515C056B1026545535A408E814BBF4AD515C0B5D593D846535A40B707102A4AD515C0B94F274C48535A40FD2E56B94AD515C0C1F6D7BE49535A40CD9AC56C4CD515C00D2EC12F4B535A40C9BF51434FD515C0BF71FF9D4C535A40EA893A3B53D515C022E3B0084E535A4045700D5258D515C002D4F56E4F535A40CFF7A6845ED515C09250F1CF50535A40D4A234CF65D515C0B7A7C92A52535A405D4C372D6ED515C045F1A87E53535A40E3ED859977D515C0EB91BDCA54535A405CCE500E82D515C076BC3A0E56535A40BA1725858DD515C021F0584857535A409DD0F0F699D515C09B73567858535A40CC38075CA7D515C087CC779D59535A40068525ACB5D515C00D3308B75A535A40EFF677DEC4D515C069015AC45B535A40E94E9FE9D4D515C0F51EC7C45C535A408893B6C3E5D515C09C66B1B75D535A40DD2B5962F7D515C06808839C5E535A401B48A9BA09D615C0E0E5AE725F535A404E9556C11CD615C011E9B03960535A407037A56A30D615C00A560EF160535A40FC0575AA44D615C08616569861535A408006497459D615C0B1FF202F62535A40D11F4FBB6ED615C0C61112B562535A407702687284D615C06EB1D62963535A4083402F8C9AD615C0ADDA268D63535A40778F03FBB0D615C0554DC5DE63535A40DD300FB1C7D615C0C5B27F1E64535A40F37950A0DED615C0FCBC2E4C64535A404377A2BAF5D615C0D53EB66764535A40C1A5C5F10CD715C06A3D057164535A4049BC683724D715C08BFA156864535A401B80317D3BD715C050F8ED4C64535A40D49EC5B452D715C0AFF59D1F64535A407288D3CF69D715C02AE441E063535A40FB431BC080D715C001030000000100000081000000024055A640515A408632FCB163CE15C09A390F5540515A407E2C4A697ACE15C0387116F23F515A404EBEA5D990CE15C042F0A77D3F515A40E73338F5A6CE15C0BF840BF83E515A40A1225FAEBCCE15C0089593613E515A4083D2B4F7D1CE15C004ED9CBA3D515A400E8118C4E6CE15C0E3848E033D515A40107AB606FBCE15C0A141D93C3C515A400B0110B30ECF15C06BAFF7663B515A40940503BD21CF15C007B66D823A515A40399FD11834CF15C07A47C88F39515A40534B29BB45CF15C020099D8F38515A408FE8299956CF15C062F7898237515A40296C6CA866CF15C03E04356936515A402A4C09DF75CF15C0FEB04B4435515A40589B9E3384CF15C028A3821434515A4063D2559D91CF15C0203595DA32515A409443E9139ECF15C09302459731515A408334A98FA9CF15C01871594B30515A40E59B8009B4CF15C030359FF72E515A40EA7FF97ABDCF15C008D4E79C2D515A40F7F140DEC5CF15C03E22093C2C515A4028A62A2ECDCF15C008C0DCD52A515A407D243466D3CF15C0F3923F6B29515A408D908782D8CF15C0AB3D11FD27515A402C07FE7FDCCF15C00B96338C26515A40E08F215CDFCF15C0D9198A1925515A40E9A12E15E1CF15C07462F9A523515A40233A15AAE1CF15C0D697663222515A403B83791AE1CF15C045E3B6BF20515A40110EB466DFCF15C0F7E1CE4E1F515A406E9BD18FDCCF15C0151892E01D515A40B0759297D8CF15C06B64E2751C515A40FE5C6980D3CF15C018759F0F1B515A4044047A4DCDCF15C0983DA6AE19515A40A8219702C6CF15C0826ED05318515A40E11240A4BDCF15C044EFF3FF16515A406C179E37B4CF15C0365AE2B315515A40442181C2A9CF15C0567B687014515A40363F5C4B9ECF15C0F9D14D3613515A40F7A241D991CF15C0BE15540612515A408944DE7384CF15C01ABF36E110515A401C26752376CF15C0B893AAC70F515A40043CDAF066CF15C0F9365DBA0E515A409DFA6CE556CF15C0DFBEF4B90D515A40AD8E120B46CF15C0A04D0FC70C515A40DCC22F6C34CF15C022B042E20B515A40E096A21322CF15C090011C0C0B515A40998BBB0C0FCF15C05B541F450A515A40BAA83663FBCE15C0C760C78D09515A401C403423E7CE15C0383985E608515A40FA723159D2CE15C07904C04F08515A40837E0012BDCE15C020BED4C907515A405BD3C05AA7CE15C035FD155507515A4094FDD64091CE15C042C1CBF106515A40A562E4D17ACE15C0EE4533A006515A40B6D8BE1B64CE15C040DD7E6006515A40E11E682C4DCE15C08CD0D53206515A406F39051236CE15C04648541706515A40BCB8D5DA1ECE15C0993A0B0E06515A409CEF2A9507CE15C0FF60001706515A40D91E5F4FF0CD15C0B2342E3206515A40349BCC17D9CD15C018F2835F06515A405AF3C4FCC1CD15C01BA3E59E06515A40441B880CABCD15C06A302CF006515A4059A23B5594CD15C09779255307515A4010FAE1E47DCD15C0FC7394C707515A40C0D151C967CD15C06950314D08515A40698E2D1052CD15C06CA7A9E308515A406CE1DAC63CCD15C022ACA08A09515A40DA857AFA27CD15C07865AF410A515A40B427E0B713CD15C0A4ED64080B515A409A7A8A0B00CD15C0D2B746DE0B515A4070859B01EDCC15C0B4DBD0C20C515A40A726D1A5DACC15C0DA6676B50D515A407ED67D03C9CC15C0A1B3A1B50E515A4085AB8125B8CC15C07FC5B4C20F515A408AA54316A8CC15C073AA09DC10515A407043ABDF98CC15C059E1F20012515A4063671A8B8ACC15C0EDC4BB3013515A40B38D67217DCC15C037FBA86A14515A405C59D8AA70CC15C010E9F8AD15515A404D7A1C2F65CC15C08D29E4F916515A40CEEF48B55ACC15C0F4089E4D18515A4025AAD34351CC15C0FC0255A819515A40038F8FE048CC15C0044433091B515A400FE2A89041CC15C0EE2C5F6F1C515A40D313A2583BCC15C056D9FBD91D515A4015FA503C36CC15C0CFA729481F515A404D72DC3E32CC15C0C9C306B920515A402C70BA622FCC15C0D7B0AF2B22515A40AE78AEA92DCC15C0FDD63F9F23515A40458CC8142DCC15C0A30FD21225515A40977E64A42DCC15C0ED32818526515A4033BE29582FCC15C00BA568F627515A40D48A0B2F32CC15C035E3A46429515A40B79B492736CC15C0F80F54CF2A515A405B33713E3BCC15C0817E96352C515A408EA25E7141CC15C0923C8F962D515A40E1373FBC48CC15C0BE9A64F12E515A40459B931A51CC15C0AFB2404530515A40D49332875ACC15C00AEB519131515A4003374CFC64CC15C0B778CBD432515A40357E6D7370CC15C02BDDE50E34515A40954084E57CCC15C06D61DF3E35515A40A58FE34A8ACC15C0938DFC6336515A403473489B98CC15C05C9C887D37515A405D01DFCDA7CC15C0ADEAD58A38515A407FD047D9B7CC15C0A8623E8B39515A40D1BE9DB3C8CC15C015E2237E3A515A40B90C7C52DACC15C0EF9BF0623B515A4096C504ABECCC15C0C37417393C515A408073E7B1FFCC15C0B65914003D515A408819685B13CD15C0FD916CB73D515A404370669B27CD15C08A0AAF5E3E515A40846065653CCD15C0CB9B74F53E515A409DB692AC51CD15C04449607B3F515A40DD0ACF6367CD15C0F17A1FF03F515A4066D9B57D7DCD15C032306A5340515A403BC4A5EC93CD15C0312C03A540515A40D8FBC8A2AACD15C0AF1BB8E440515A40D5C61D92C1CD15C007B4611241515A40B6257FACD8CD15C072CBE32D41515A40DD8BADE3EFCD15C05F6A2D3741515A402CA9572907CE15C0F0D5382E41515A40863E236F1ECE15C084930B1341515A40B9F7B5A635CE15C04E65B6E540515A409545BEC14CCE15C0024055A640515A408632FCB163CE15C001030000000100000081000000B6FDFFAB52515A4014B42FB0A7C815C08B49BA5A52515A40CA467E67BEC815C0DADDC1F751515A404B8ADAD7D4C815C0D0C3538351515A401ACA6DF3EAC815C035C9B7FD50515A40119B95AC00C915C01C54406750515A40AE44ECF515C915C020304AC04F515A40DB0351C22AC915C021553C094F515A40BE23F0043FC915C0C3A787424E515A4020E74AB152C915C0D7B3A66C4D515A40DB3C3FBB65C915C0C0601D884C515A40AE3B0F1778C915C01FA078954B515A400E6068B989C915C0E5164E954A515A40C8876A979AC915C006C13B8849515A4027A7AEA6AAC915C01290E76E48515A4033334DDDB9C915C0D904FF4947515A40AF3DE431C8C915C065C4361A46515A40373E9D9BD5C915C09B284AE044515A40FC853212E2C915C0A8CCFA9C43515A407559F48DEDC915C09D15105142515A402FAECD07F8C915C075B756FD40515A402B89487901CA15C0D336A0A23F515A4092FA91DC09CA15C0CD67C2413E515A404EB57D2C11CA15C00BEA96DB3C515A401840896417CA15C08DA2FA703B515A4049BDDE801CCA15C07133CD023A515A406A48577E20CA15C00572F09138515A40BDE77C5A23CA15C081DB471F37515A4037118C1325CA15C0B408B8AB35515A4067C074A825CA15C00E21263834515A40B31EDB1825CA15C0464D77C532515A40B4BB176523CA15C0092A905431515A40E056378E20CA15C0F63A54E62F515A405D39FA951CCA15C0545EA57B2E515A400822D37E17CA15C0BA4163152D515A4097C2E54B11CA15C025D86AB42B515A40EDCF04010ACA15C0ABD195592A515A409AA6AFA201CA15C03F15BA0529515A40E4840F36F8C915C0C03CA9B927515A40A85BF4C0EDC915C0B913307626515A409238D149E2C915C00B19163C25515A40454CB8D7D5C915C0EF031D0C24515A40B28D5672C8C915C0704C00E722515A400FFEEE21BAC915C0D6B774CD21515A40B19055EFAAC915C025E927C020515A400FB9E9E39AC915C00AF6BFBF1F515A400BA390098AC915C06800DBCC1E515A407A18AF6A78C915C0D6D40EE81D515A404A18231266C915C03C8EE8111D515A40A0223D0B53C915C0CA3EEC4A1C515A40863EB9613FC915C08A9E94931B515A4036BDB7212BC915C0ADBF52EC1A515A405CBFB55716C915C0D2C88D551A515A40A781851001C915C067B5A2CF19515A4046744659EBC815C0561CE45A19515A40ED225D3FD5C815C010FD99F718515A40BFF26AD0BEC815C02D9301A618515A40A3B9451AA8C815C0A4304D6618515A408336EF2A91C815C0CB1EA43818515A40846D8C107AC815C01586221D18515A40F0EE5CD962C815C0BB5CD91318515A409D0DB2934BC815C0465CCE1C18515A405E0AE64D34C815C007FEFB3718515A401B3A53161DC815C0857E516518515A40AF2B4BFB05C815C0D0E7B2A418515A404FD30D0BEFC715C0C322F9F518515A40B5C0C053D8C715C0200FF25819515A40B86566E3C1C715C07EA260CD19515A401D72D5C7ABC715C0EC0DFD521A515A40634BB00E96C715C03DEA74E91A515A4077A35CC580C715C0DA6A6B901B515A400836FBF86BC715C0FF9679471C515A40BFAF5FB657C715C03D892E0E1D515A40F7C4080A44C715C01CB50FE41D515A40547D180031C715C0AE3299C81E515A401CB84CA41EC715C0EA0F3EBB1F515A406EEEF7010DC715C099A768BB20515A40C237FA23FCC615C0A0FD7AC821515A40D894BA14ECC615C07220CFE122515A40988520DEDCC615C0628FB70624515A4035ED8D89CEC615C0A9A57F3625515A401549D91FC1C615C0CB096C7026515A404B3D48A9B4C615C02521BBB327515A40ED7A8A2DA9C615C04F87A5FF28515A406A02B5B39EC615C015895E532A515A403CC53D4295C615C0B9A214AE2B515A404CAAF7DE8CC615C02101F20E2D515A407BF60E8F85C615C0BC051D752E515A40961B06577FC615C0B4CCB8DF2F515A40A4F0B23A7AC615C028B5E54D31515A4066543C3D76C615C016EBC1BE32515A40D03B186173C615C09FF2693134515A402E2D0AA871C615C05234F9A435515A40382A221371C615C0288A8A1837515A40DF07BCA271C615C0CDCC388B38515A40F6357F5673C615C0FF601FFC39515A4087F55E2D76C615C07CC45A6A3B515A4008FF9A257AC615C0571A09D53C515A403D96C03C7FC615C044B64A3B3E515A402E0DAC6F85C615C085A6429C3F515A40A3B38ABA8CC615C02D3C17F740515A40BA32DD1895C615C06191F24A42515A40BC527A859EC615C03F0D039743515A403B2A92FAA8C615C021E57BDA44515A40B7B3B171B4C615C0ED9A951446515A406BC7C6E3C0C615C016788E4447515A40E6772449CEC615C01A05AB6948515A40F1CD8799DCC615C01A7D368349515A409AE01CCCEBC615C0563D83904A515A402E4784D7FBC615C04930EB904B515A40BEE0D8B10CC715C00D34D0834C515A407EEEB5501EC715C0E97B9C684D515A40997C3DA930C715C0B0ECC23E4E515A40DC151FB043C715C0C973BF054F515A40FABD9E5957C715C0A25817BD4F515A402D2E9C996BC715C05F88596450515A40D24F9A6380C715C09CDB1EFB50515A40BAEFC6AA95C715C006560A8151515A40A3A60262ABC715C0B55FC9F551515A4012F1E87BC1C715C022F8135952515A405971D8EAD7C715C08BE2ACAA52515A403558FBA0EEC715C0BBCB61EA52515A4075EC4F9005C815C013690B1853515A40B42EB1AA1CC815C0C5908D3353515A407092DFE133C815C0384BD73C53515A408CC789274BC815C07EDDE23353515A40D58E556D62C815C0DECCB51853515A400194E8A479C815C06CDB60EB52515A40B047F1BF90C815C0B6FDFFAB52515A4014B42FB0A7C815C0010300000001000000810000008713460F8A515A405D20C4ADC1C015C03E724EAC89515A405461221ED8C015C0F42FE13789515A4032FAB739EEC015C0EA1946B288515A405F7EE2F203C115C0AA95CF1B88515A40B4333C3C19C115C0386EDA7487515A403C55A4082EC115C0D79ACDBD86515A40072C474B42C115C08BFF19F785515A4094F8A5F755C115C07A273A2185515A4045A79E0169C115C05BF9B13C84515A402B4C735D7BC115C017660E4A83515A40DF60D1FF8CC115C0E411E54982515A4027C0D8DD9DC115C0FDF7D33C81515A40155B22EDADC115C02B09812380515A4050A3C623BDC115C076C599FE7E515A400FA76378CBC115C021D1D2CE7D515A404ADA22E2D8C115C04285E7947C515A405A8ABE58E5C115C0397C99517B515A40C4F786D4F0C115C0441AB0057A515A400414674EFBC115C08B12F8B178515A40EBDFE8BF04C215C0DEE8425777515A40606739230DC215C0807066F675515A40E7582C7314C215C045483C9074515A40CB363FAB1AC215C05B54A12573515A40DE1E9CC71FC215C00D3675B771515A4016281CC523C215C0DAC1994670515A40155449A126C215C02C74F2D36E515A402914605A28C215C006E563606D515A402D5F50EF28C215C0123BD3EC6B515A40D959BE5F28C215C0429E257A6A515A400E8F02AC26C215C082AA3F0969515A409CB929D523C215C0B9E2049B67515A40EF1DF4DC1FC215C07324573066515A405076D4C51AC215C09A1C16CA64515A40CF6FEE9214C215C07EBD1E6963515A40D0BA14480DC215C092B64A0E62515A4062AFC6E904C215C02BEE6FBA60515A406C872D7DFBC115C091FD5F6E5F515A40772F1908F1C115C0C0AFE72A5E515A40F9B0FC90E5C115C01383CEF05C515A407D38EA1ED9C115C0422ED6C05B515A40F5B88EB9CBC115C0E228BA9B5A515A40B92F2D69BDC115C0CD372F8259515A406A8C9936AEC115C0A4FDE27458515A40E83E332B9EC115C0B78F7B7457515A40AA6FDF508DC115C0960F978156515A4042E502B27BC115C09149CB9C55515A40879B7B5969C115C05258A5C654515A40B50F9A5256C115C0D44DA9FF53515A401D461AA942C115C0F5E1514853515A406D8D1C692EC115C0C82610A152515A40FF031E9F19C115C0D6424B0A52515A405DE4F05704C115C08131608451515A40CD9CB4A0EEC015C0B189A10F51515A404BB7CD86D8C015C0E14A57AC50515A407D97DD17C2C015C0BDB0BE5A50515A400412BA61ABC015C05A0D0A1B50515A40BDE4647294C015C037AA60ED4F515A40FC1203587DC015C0F7AFDED14F515A40722CD42066C015C0121595C84F515A40988329DB4EC015C0549389D14F515A4028595D9537C015C063A4B6EC4F515A401702CA5D20C015C01A850B1A50515A409C0DC14209C015C0EE3F6C5950515A4078708252F2BF15C026BEB1AA50515A4032BB339BDBBF15C0F9DFA90D51515A40A460D72AC5BF15C07A9B178251515A40D111440FAFBF15C03D22B30752515A40AD351C5699BF15C0A30D2A9E52515A40D37FC50C84BF15C0A9911F4553515A40D9AD60406FBF15C028B62CFC53515A407C6EC1FD5ABF15C05396E0C254515A406678665147BF15C05AA6C09855515A40C0D5714734BF15C0FFFE487D56515A408268A1EB21BF15C0EDAEEC6F57515A40A4AC474910BF15C0A811167058515A40B3BC446BFFBE15C0D32B277D59515A40AA9CFF5BEFBE15C0A20C7A965A515A40D3CF5F25E0BE15C0313461BB5B515A40E83CC7D0D1BE15C082FE27EB5C515A4008650C67C4BE15C0E51213255E515A4017F074F0B7BE15C086D760685F515A401E93B074ACBE15C0CDE849B460515A40A152D4FAA1BE15C05B94010862515A404924568998BE15C04157B66263515A4048F3082690BE15C03A5F92C364515A40DE0819D688BE15C0890EBC2966515A4047DB089E82BE15C02982569467515A401346AE817DBE15C0091A820269515A40912C308479BE15C0F9025D736A515A40548804A876BE15C0E4C103E66B515A4052E4EEEE74BE15C028C091596D515A40EA46FF5974BE15C080D821CD6E515A40BB8991E974BE15C061E4CE3F70515A404E214D9D76BE15C04349B4B071515A405453257479BE15C0A385EE1E73515A40EBDC596C7DBE15C048BD9B8974515A407806788382BE15C09744DCEF75515A4090265CB688BE15C07B2AD35077515A408391330190BE15C0AEC0A6AB78515A40E8F47E5F98BE15C0F02181FF79515A40621D15CCA1BE15C0F5B5904B7B515A40CD252641ACBE15C0A9B2088F7C515A40DB0C3FB8B7BE15C0779A21C97D515A40DEAE4D2AC4BE15C052B719F97E515A405922A58FD1BE15C02D92351E80515A40F17302E0DFBE15C09766C03781515A4065BE9112EFBE15C037920C4582515A40929CF31DFFBE15C0E3FF734583515A40EEF042F80FBF15C0058E583884515A40F3FF1A9721BF15C03070241D85515A40D8D89DEF33BF15C0758B4AF385515A4050097BF646BF15C06DCD46BA86515A40CD97F69F5ABF15C0B47D9E7187515A400840F0DF6EBF15C08F89E01888515A40B3EDEAA983BF15C0ACC9A5AF88515A40C46F14F198BF15C0C941913589515A40E2604DA8AEBF15C0FD5950AA89515A40463F31C2C4BF15C0B9119B0D8A515A40C7AE1E31DBBF15C0282C345F8A515A4060E13FE7F1BF15C0F755E99E8A515A40F41E93D608C015C05E4493CC8A515A40F068F3F01FC015C061CD15E88A515A406A33212837C015C028F95FF18A515A40A62ECB6D4EC015C0820C6CE88A515A409A1B97B365C015C0638C3FCD8A515A40E3A52AEB7CC015C0883AEB9F8A515A40CE3D340694C015C01E0B8B608A515A4003ED73F6AAC015C08713460F8A515A405D20C4ADC1C015C0010300000001000000810000003AD4283D40525A4048F0C214ECB115C0E0F6E5EB3F525A40CE2618CC02B215C08387F0883F525A407CAB7C3C19B215C0768D85143F525A40C9C419582FB215C093D4EC8E3E525A4080014D1145B215C0EEC078F83D525A401DA2B05A5AB215C00A1C86513D525A4090DB23276FB215C09EDB7B9A3C525A401AF0D26983B215C019E2CAD33B525A40B5183F1697B215C001B9EDFD3A525A4082394620AAB215C0614568193A525A40B25D2A7CBCB215C07876C72639525A4057F5981ECEB215C0C6EEA02638525A4000D1B1FCDEB215C0CAA7921937525A4002D70D0CEFB215C09090420036525A40AD6DC542FEB215C05F275EDB34525A404E9776970CB315C0B80E9AAB33525A4071BB4A011AB315C0EB9DB17132525A40871AFC7726B315C0976D662E31525A40B6E7DAF331B315C036E07FE22F525A40AE06D26D3CB315C033A7CA8E2E525A400E6A6BDF45B315C0A24418342D525A402F0FD4424EB315C00D8A3ED32B525A40B595DF9255B315C09914176D2A525A40C3700BCB5BB315C0C6C67E0229525A40B9AE81E760B315C04140559427525A40EF561BE564B315C0ED537C2326525A40365B62C167B315C0A37CD7B024525A40E71C937A69B315C0E3504B3D23525A40CF829D0F6AB315C0DCF5BCC921525A4088A1258069B315C01392115720525A40D1F383CC67B315C017C02DE61E525A405524C5F564B315C07B01F5771D525A407A67A9FD60B315C08C32490D1C525A408267A3E65BB315C000FF09A71A525A40ACC1D6B355B315C00858144619525A40B21616694EB315C006EC41EB17525A4028AFE00A46B315C052A0689716525A40BFB55F9E3CB315C04A0D5A4B15525A401208632932B315C011FDE20714525A40FCA05DB226B315C040EDCACD12525A40C09E61401AB315C0DD93D39D11525A4073E61BDB0CB315C0E467B87810525A40FF67CF8AFEB215C0A92D2E5F0F525A4001065058EFB215C05B87E2510E525A40DC23FD4CDFB215C0F0897B510D525A4007DEBB72CEB215C0B356975E0C525A40A4EFF0D3BCB215C0C6B9CB790B525A40AB497A7BAAB215C0B8CDA5A30A525A40175FA87497B215C082A4A9DC09525A408D2A37CB83B215C016F6512509525A40C5F1468B6FB215C0AFD40F7E08525A40BDCA54C15AB215C016674AE707525A4062E8327A45B215C003A95E6107525A4007B200C32FB215C0C9319FEC06525A407AAB22A919B215C06301548906525A40E7323A3A03B215C01254BA3706525A4038181D84ECB115C0987C04F805525A405B15CD94D5B115C02CC559CA05525A40752A6F7ABEB115C04B57D6AE05525A40D3E44243A7B115C04C2A8BA505525A40549599FD8FB115C0F9F87DAE05525A40DF7BCDB778B115C0FE3DA9C905525A4067ED388061B115C05537FCF605525A40E3792D654AB115C09EF05A3606525A40A817EB7433B115C05E549E8706525A40945997BD1CB115C0184494EA06525A409DB5344D06B115C039B7FF5E07525A40B1E09931F0B015C0BFE098E407525A406A466978DAB015C0805B0D7B08525A40CF9F082FC5B015C0FA5C002209525A4097B09862B0B015C091EE0AD909525A40682EED1F9CB015C0102DBC9F0A525A4078D7847388B015C0488E99750B525A4039BE816975B015C09E2C1F5A0C525A4090CDA10D63B015C06F18C04C0D525A400C8B376B51B015C0F2AEE64C0E525A406F1B238D40B015C083F6F4590F525A407E8DCB7D30B015C01400457310525A40E66F184721B015C0824D299811525A4051B56BF212B015C0903CEDC712525A4047EB9B8805B015C05276D50114525A4099C6EE11F9AF15C0B362204515525A40B7091496EDAF15C0E09F069116525A40EAC6201CE3AF15C0347DBBE417525A400E028BAAD9AF15C07C796D3F19525A40E3B42547D1AF15C02BC446A01A525A4080371DF7C9AF15C031C16D061C525A404E0FF4BEC3AF15C0348F05711D525A403D2780A2BEAF15C0C58F2EDF1E525A403972E8A4BAAF15C049F1065020525A40A0F9A2C8B7AF15C03F3AABC221525A404958730FB6AF15C085D5363623525A40A1A4697AB5AF15C0519FC4A924525A4057C8E109B6AF15C081726F1C26525A40074883BDB7AF15C0EFB5528D27525A4077794194BAAF15C065E98AFB28525A40CA295C8CBEAF15C0EE3136662A525A4052B160A3C3AF15C01DE574CC2B525A406D762BD6C9AF15C001136A2D2D525A400ADDE920D1AF15C05F0E3C882E525A4023A21C7FD9AF15C0F8F214DC2F525A408AA19AEBE2AF15C06A29232831525A40FB049460EDAF15C077E8996B32525A40B8D995D7F8AF15C04EB3B1A533525A404A0A8E4905B015C093D4A8D534525A4006BBCFAE12B015C0D5D5C3FA35525A40F50518FF20B015C028F34D1437525A40D212933130B015C0A58A992138525A40EA88E13C40B015C07B87002239525A40AD561E1751B015C060C8E4143A525A40FECBE4B562B015C01081B0F93A525A40E902570E75B015C0B996D6CF3B525A406693241588B015C0F9F6D2963C525A40888D91BE9BB015C057E92A4E3D525A4006B67DFEAFB015C0F35A6DF53D525A40E2006CC8C4B015C03B24338C3E525A40B8448A0FDAB015C097481F123F525A401B23B9C6EFB015C0B62FDF863F525A40842094E005B115C08BD82AEA3F525A4040E6794F1CB115C0AB05C53B40525A4007AB940533B115C01B637B7B40525A40B3BAE2F449B115C055A526A940525A40EB193F0F61B115C08BA1AAC440525A40313F6A4678B115C0035FF6CD40525A4070DC128C8FB115C0922104C540525A4077B3DED1A6B115C0256DD9A940525A40F66F7309BEB115C05D02877C40525A4085817F24D5B115C03AD4283D40525A4048F0C214ECB115C001030000000100000081000000B6F7EE8EF8505A40C7BEEE03CFA815C0313EA93DF8505A407AA33BBBE5A815C0750BB1DAF7505A40295A952BFCA815C08D684366F7505A40F32F254712A915C0F522A8E0F6505A40C4BB480028A915C055A0314AF6505A40C5479A493DA915C0B2AB3CA3F5505A400A14F91552A915C02F3C30ECF4505A40666F915866A915C093357D25F4505A40D7A0E4047AA915C0AB229E4FF3505A40E19BD00E8DA915C0B1E9166BF2505A40707C976A9FA915C0F97A7478F1505A40A3C4E60CB1A915C0077A4C78F0505A405C58DEEAC1A915C041E13C6BEF505A40733217FAD1A915C085A0EB51EE505A40ECCEA930E1A915C0D236062DED505A40EA463485EFA915C0464741FDEB505A40D419E0EEFCA915C0BA2958C3EA505A40FEA0676509AA15C033770C80E9505A4064291BE114AA15C07F922534E8505A4066B1E55A1FAA15C03D2D70E0E6505A402E4751CC28AA15C09DC9BD85E5505A4058048B2F31AA15C02B39E424E4505A407FA5667F38AA15C0F018BDBEE2505A4052BB61B73EAA15C03C4B2554E1505A405672A6D343AA15C0676FFCE5DF505A406FF00DD147AA15C0EE572475DE505A40684622AD4AAA15C0267F8002DD505A40E5F41F664CAA15C0F37AF58EDB505A403902F7FA4CAA15C0CC6F681BDA505A40B3A24B6B4CAA15C06983BEA8D8505A40DB7076B74AAA15C06D4FDC37D7505A40293784E047AA15C06F54A5C9D5505A40BB4935E843AA15C0A36DFB5ED4505A407572FCD03EAA15C09345BEF8D2505A40F06DFD9D38AA15C02CCCCA97D1505A4001FC0A5331AA15C078AEFA3CD0505A40F283A4F428AA15C062D023E9CE505A40BD4EF3871FAA15C0C8C8179DCD505A40BC57C71215AA15C03C60A359CC505A40FBB6939B09AA15C0B1128E1FCB505A4042A76A29FDA915C07B9499EFC9505A407029F9C3EFA915C0D15A81CAC8505A406C488273E1A915C03628FAB0C7505A40FE00DA40D2A915C0FB9CB1A3C6505A40B8CF5F35C2A915C029CC4DA3C5505A4053E9F85AB1A915C018D56CB0C4505A4026200ABC9FA915C0E881A4CBC3505A403E7B71638DA915C021EB81F5C2505A408B827F5C7AA915C0AF20892EC2505A407644F0B266A915C070D83477C1505A403219E47252A915C08322F6CFC0505A40FC27D8A83DA915C097233439C0505A409BB39E6128A915C047D54BB3BF505A40EB3157AA12A915C0C3CC8F3EBF505A40CE336690FCA815C0EC0748DBBE505A4021236D21E6A815C0E6C0B189BE505A4000DA416BCFA815C05848FF49BE505A400F1BE67BB8A815C069E6571CBE505A40A8ED7E61A1A815C083C2D700BE505A40C9E44B2A8AA815C0FBD18FF7BD505A4071559EE472A815C097CD8500BE505A401F82D09E5BA815C0112EB41BBE505A40CDC03C6744A815C0782F0A49BE505A40EDA0344C2DA815C08EDB6B88BE505A40C116F85B16A815C0071BB2D9BE505A4082B1ACA4FFA715C0A3CDAA3CBF505A40FFE15434E9A715C01CE918B1BF505A406D56C718D3A715C0CB9EB436C0505A403272A65FBDA715C0F6872BCDC0505A409DE45716A8A715C09AD82074C1505A403966FC4993A715C0B2982D2BC2505A400FA067077FA715C0AFE3E0F1C2505A404B42185B6BA715C01E2EC0C7C3505A40F54F305158A715C0399147ACC4505A4037A36DF545A715C0451CEA9EC5505A4090AF225334A715C07A2B129FC6505A4072862F7523A715C04DC421ACC7505A402322FB6513A715C0E0F672C5C8505A409DFB6C2F04A715C0584458EAC9505A40C2EEE6DAF5A615C0DB091D1ACB505A4044713F71E8A615C0F9EF0554CC505A40201FBCFADBA615C0365E5197CD505A40F9A00C7FD0A615C06BF237E3CE505A407BEE4505C6A615C0C0FBEC36D0505A4008F0DD93BCA615C0E8F89E91D1505A402983A730B4A615C0521978F2D2505A4018E3CEE0ACA615C00BC19E58D4505A40BC77D6A8A6A615C0ED0E36C3D5505A40020E948CA1A615C0D8645E31D7505A40557A2E8F9DA615C09AF135A2D8505A4032A71BB39AA615C0363CD914DA505A403F101FFA98A615C025B06388DB505A4070AC486598A615C0552AF0FBDC505A40DA45F4F498A615C07386996EDE505A406441C9A89AA615C03E2C7BDFDF505A401ED5BA7F9DA615C07F9CB14DE1505A407FAE0878A1A615C058FD5AB8E2505A405106408FA6A615C088A5971EE4505A40A6233DC2ACA615C05FA68A7FE5505A40634B2D0DB4A615C0FA535ADAE6505A40DA1B916BBCA615C086CB302EE8505A40A3523FD8C5A615C01F773C7AE9505A40C0FB674DD0A615C0178FB0BDEA505A40510798C4DBA615C03F98C5F7EB505A405F43BD36E8A615C0F0DEB927ED505A407BB82A9CF5A615C079EED14CEE505A40AF659DEC03A715C0BF045966EF505A409358411F13A715C0B781A173F0505A403C1FB72A23A715C07C520574F1505A40D98F190534A715C0B557E666F2505A4014E303A445A715C021C7AE4BF3505A40D71C98FC57A715C0F087D121F4505A401EC085036BA715C0D089CAE8F4505A4030C910AD7EA715C05B161FA0F5505A4033EA18ED92A715C0C61C5E47F6505A40E60521B7A7A715C09F7720DEF6505A40F3E256FEBCA715C0692C0964F7505A4056149BB5D2A715C0F3A4C5D8F7505A405C1189CFE8A715C04CE20D3CF8505A4091777F3EFFA715C026A9A48DF8505A406973A8F415A815C09CA757CDF8505A40EF4702E42CA815C04294FFFAF8505A407EF267FE43A815C053468016F9505A40D7E399355BA815C020C7C81FF9505A40A7C9467B72A815C07A5CD316F9505A40176314C189A815C0468CA5FBF8505A40B75AA8F8A0A815C0101950CEF8505A408E20B113B8A815C0B6F7EE8EF8505A40C7BEEE03CFA815C001030000000100000081000000F78AB74252525A4007042DFE12A315C0493A75F151525A4071FB82B529A315C03073808E51525A409649E82540A315C09B3C161A51525A407334864156A315C0E9617E9450525A40584ABAFA6BA315C0A8460BFE4F525A4039CB1E4481A315C0C0B319574F525A4082EB921096A315C0419E10A04E525A40E3EC4253AAA315C0DFE760D94D525A40CC07B0FFBDA315C05A1985034D525A40CB1FB809D1A315C0EA16011F4C525A40763F9D65E3A315C0E6CE612C4B525A404AD60C08F5A315C0E1E23C2C4A525A403FB426E605A415C0594B301F49525A4007BF83F515A415C052F6E10548525A40585C3C2C25A415C0FD60FFE046525A40E18DEE8033A415C0B82C3DB145525A4089BAC3EA40A415C0ACAF567744525A40242276614DA415C03F810D3443525A403AF755DD58A415C0B30229E841525A40D21C4E5763A415C029E4759440525A40F384E8C86CA415C06BA6C5393F525A40522C522C75A415C0B119EED83D525A40FAB15E7C7CA415C0C6D9C8723C525A406A888BB482A415C0CFC732083B525A4074BD02D187A415C015820B9A39525A40CF579DCE8BA415C019DA342938525A40B948E5AA8EA415C04D4992B636525A40FAF0166490A415C0CB64084335525A40D13622F990A415C056507CCF33525A40502EAB6990A415C01131D35C32525A40AC510AB68EA415C01FA0F1EB30525A40114B4CDF8BA415C0B31DBB7D2F525A40634E31E787A415C0B68411132E525A4072052CD082A415C0837FD4AC2C525A400B0D609D7CA415C0F0FDE04B2B525A407205A05275A415C00EAD10F129525A40DF366BF46CA415C0E770399D28525A409FCBEA8763A415C093E02C5127525A40F1A0EE1259A415C0F9C4B70D26525A405CB1E99B4DA415C07B9AA1D324525A40D81AEE2941A415C0F515ACA323525A4039C2A8C433A415C042AD927E22525A4023975C7425A415C09F230A6521525A40057CDD4116A415C0301AC05720525A400DD48A3606A415C0ECA45A571F525A408FBB495CF5A315C02FE477641E525A408BED7EBDE3A315C032A3AD7F1D525A40E75A0865D1A315C0B1FB88A91C525A408B76365EBEA315C0DCFE8DE21B525A40163BC5B4AAA315C0EC63372B1B525A4044EED47496A315C0723CF6831A525A401DA6E2AA81A315C09DAE31ED19525A40A095C0636CA315C09CB5466719525A403C248EAC56A315C048E887F218525A40E0D5AF9240A315C034463D8F18525A40E208C7232AA315C04A0BA43D18525A40608DA96D13A315C0038AEEFD17525A40831D597EFCA215C0660C44D017525A40B3B9FA63E5A215C0C7BBC0B417525A4089EFCD2CCEA215C0728F75AB17525A40321024E7B6A215C02B4268B417525A40F05B57A19FA215C0B34E93CF17525A401628C26988A215C025F3E5FC17525A400305B64E71A215C0573B443C18525A4076E9725E5AA215C01512878D18525A40C5681EA743A215C037597CF018525A405BF9BA362DA215C09408E76419525A40A8501F1B17A215C0A4537FEA19525A40CBDAED6101A215C0C2D5F2801A525A4055518C18ECA115C00AC5E4271B525A408B781B4CD7A115C0882BEEDE1B525A40A2066F09C3A115C0C0269EA51C525A406BBA055DAFA115C0472D7A7B1D525A40F2A601539CA115C05E5AFE5F1E525A40B3B720F789A115C042BF9D521F525A40E772B55478A115C01ABAC25220525A40E9FD9F7667A115C04452CF5F21525A402768476757A115C0B9991D7922525A40F340933048A115C06A13009E23525A409C7BE5DB39A115C03F1EC2CD24525A404FA614722CA115C07264A80726525A408B7666FB1FA115C0264FF14A27525A4061AF8A7F14A115C0C17DD59628525A40C46396050AA115C0E44088EA29525A403698FF9300A115C0AA1838452B525A4015479930F8A015C0D3350FA62C525A4020C98FE0F0A015C0AAFD330C2E525A405CA465A8EAA015C03090C9762F525A4058C4F08BE5A015C05650F0E430525A409A1C588EE1A015C0E66DC65532525A4014B711B2DEA015C0C37068C833525A40302FE1F8DCA015C030C5F13B35525A40EB9BD663DCA015C0CC487DAF36525A407CE74DF3DCA015C0DDD7252238525A400397EEA6DEA015C0A0DA069339525A40C800AC7DE1A015C043D23C013B525A4067F2C575E5A015C031E5E56B3C525A40A6C4C98CEAA015C05A6A22D23D525A404FDE93BFF0A015C0257315333F525A40B9A3510AF8A015C0AA53E58D40525A4045D2836800A115C0F428BCE141525A401D4601D509A115C0E75CC82D43525A404D29FA4914A115C083273D7144525A406789FBC01FA115C02C0D53AB45525A403951F3322CA115C0AE5948DB46525A4058A5349839A115C0BC97610048525A40FB9F7CE847A115C07F04EA1949525A401469F71A57A115C019FF33274A525A4015A8452667A115C0BC7399274B525A408C4B820078A115C00B427C1A4C525A4073A3489F89A115C0AA9E46FF4C525A40E7C9BAF79BA115C09D6F6BD54D525A40E65688FEAEA115C04CA3669C4E525A40825AF5A7C2A115C0F481BD534F525A406B99E1E7D6A115C05FF9FEFA4F525A409607D0B1EBA115C09BE2C39150525A407F7BEEF800A215C09441AF1751525A40A3961DB016A215C0797E6E8C51525A4051DDF8C92CA215C0A198B9EF51525A40A0F8DE3843A215C0FE52534152525A401D1FFAEE59A215C0D759098152525A40609C48DE70A215C0E061B4AE52525A40CB74A5F887A215C06E4038CA52525A40981ED12F9FA215C0D8FC83D352525A40594B7A75B6A215C0F7DA91CA52525A408DBC46BBCDA215C0A45E67AF52525A40851DDCF2E4A215C06148158252525A406EDDE80DFCA215C0F78AB74252525A4007042DFE12A315C00103000000010000008100000003B7ED1FC0515A402DE74B202A9215C0DE22F8BCBF515A40399DAC90409215C00F438D48BF515A406CC244AC569215C05EE3F4C2BE515A4099E871656C9215C0AC67812CBE515A400554CEAE819215C01D998F85BD515A40133E397B969215C0E46C86CEBC515A4027EEDEBDAA9215C0C7C4D607BC515A4005A3406ABE9215C07A29FB31BB515A404E473C74D19215C0197F774DBA515A4042ED13D0E39215C0C3B3D85AB9515A40B50C7572F59215C0BF68B45AB8515A40887E7F50069315C02896A84DB7515A40F731CC5F169315C088295B34B6515A40CE967396259315C0819F790FB5515A405CB913EB339315C0CE98B8DFB3515A40B50BD654419315C0DB6AD3A5B2515A404DD974CB4D9315C043AC8B62B1515A40C7604047599315C061BDA816B0515A40B69123C1639315C0644DF7C2AE515A40136BA8326D9315C009DC4868AD515A40E4F6FB95759315C06E387307AC515A40D6E1F1E57C9315C02DFD4FA1AA515A4065AC071E839315C0300ABC36A9515A409572673A889315C06FFC96C8A7515A409E49EA378C9315C00BA4C257A6515A4066311A148F9315C00C7922E5A4515A408F9933CD909315C00E0F9B71A3515A404D772662919315C04F8811FEA1515A40C3ED96D2909315C05C086B8BA0515A404A86DD1E8F9315C0BC268C1A9F515A4032FA06488C9315C0F66158AC9D515A40808CD34F889315C04593B1419C515A4019F6B538839315C04A6377DB9A515A40C9E2D1057D9315C01CC0867A99515A40B801FABA759315C00555B91F98515A40CDA9AD5C6D9315C04604E5CB96515A40DC1316F0639315C02B63DB7F95515A406F2B037B599315C0C738693C94515A4012F9E7034E9315C0B0FF550293515A4078A8D691419315C0EF6A63D291515A40D62B7C2C349315C08FEE4CAD90515A40DE7F1BDC259315C0FE4BC7938F515A409D9388A9169315C0982280868E515A4078D6229E069315C08C841D868D515A408470CFC3F59215C074903D938C515A400B28F324E49215C0D30F76AE8B515A40B4F86BCCD19215C0AD1A54D88A515A409F5F8AC5BE9215C08CC05B118A515A401F610A1CAB9215C009B7075A89515A40FD4B0CDC969215C01F0EC9B288515A40C03E0D12829215C072EA061C88515A404174DFCA6C9215C0B5451E9687515A402B5BA213579215C051B5612187515A40F07DBAF9409215C0793719BE86515A40D240C98A2A9215C0C306826C86515A401A79A4D4139215C06874CE2C86515A4068E54DE5FC9115C03DC925FF85515A40EF89EACAE59115C0782DA4E385515A4051F7B993CE9115C056975ADA85515A4010810D4EB79115C0A2C04EE385515A40FB683F08A09115C036237BFE85515A404605AAD0889115C05DFCCE2B86515A4065E69EB5719115C02C572E6B86515A4076025EC55A9115C0C51D72BC86515A406BEB0C0E449115C07231681F87515A409D15AE9D2D9115C08789D39387515A4098331882179115C015596C1988515A40F0ADEDC8019115C02B3BE0AF88515A40ED39947FEC9015C0A365D25689515A40D8962CB3D79015C06AE2DB0D8A515A4039758A70C39015C0F3CE8BD48A515A40858D2CC4AF9015C0E1A167AA8B515A40C2EB34BA9C9015C09176EB8E8C515A40C473615E8A9015C0785E8A818D515A4071A304BC789015C00CB8AE818E515A404597FEDD679015C00C8BBA8E8F515A402F55B6CE579015C0EEE907A890515A406D621398489015C03158E9CC91515A40BAA777433A9015C06035AAFC92515A4026A8B9D92C9015C0732C8F3694515A40950D1F63209015C058A7D67995515A40088F57E7149015C05A46B9C596515A40F732786D0A9015C0115B6A1998515A4000F1F6FB009015C09E66187499515A4039B6A698F88F15C0E19AEDD49A515A40CCCDB348F18F15C0505E103B9C515A40D2AFA010EB8F15C02AD2A3A59D515A40AA3943F4E58F15C0AF5AC8139F515A406E50C2F6E18F15C007299C84A0515A4074EF931ADF8F15C07FC63BF7A1515A405AA37B61DD8F15C0D8A0C26AA3515A40297489CCDC8F15C036974BDEA4515A40143D195CDD8F15C07087F150A6515A402774D20FDF8F15C060DBCFC1A7515A408760A8E6E18F15C0DE150330A9515A40B8C0DADEE58F15C0025FA99AAA515A406FDEF6F5EA8F15C0760FE300AC515A408211D928F18F15C05E3AD361AD515A4066AFAE73F88F15C09735A0BCAE515A40CA66F8D1009015C0F41F7410B0515A4053058D3E0A9015C027657D5CB1515A40C9A69CB3149015C0FB3EEF9FB2515A40B14AB42A209015C0A63302DAB3515A401FCEC19C2C9015C0C590F409B5515A403E4818023A9015C0D8E20A2FB6515A403EC67452489015C0D6689048B7515A405E630385579015C0AE83D755B8515A40DDBA6490679015C051213A56B9515A4077AFB36A789015C026231A49BA515A40DC858B098A9015C08CBFE12DBB515A405B4D0E629C9015C036DE0304BC515A40A993EB68AF9015C0366FFCCABC515A40235F6712C39015C06CBC5082BD515A40596B6152D79015C035B58F29BE515A40B3A35C1CEC9015C0283452C0BE515A40CED68663019115C0B33E3B46BF515A40DA9EC01A179115C06F3EF8BABF515A408F79A5342D9115C01A34411EC0515A401B0A94A3439115C0F4E3D86FC0515A40CB81B6595A9115C08AFB8CAFC0515A40AF270B49719115C0C03036DDC0515A4057FC6C63889115C00D5AB8F8C0515A40EA729C9A9F9115C0D47F0202C1515A409E3A48E0B69115C0E8E60EF9C0515A404F131626CE9115C00E14E3DDC0515A406CA7AB5DE59115C098C88FB0C0515A400766B778FC9115C011F83071C0515A407457F968139215C003B7ED1FC0515A402DE74B202A9215C00103000000010000008100000029A71DC8F5525A402C88C24E108115C04A832B65F5525A409A9B2DBF268115C0A82AC4F0F4525A40B241D2DA3C8115C0DF662F6BF4525A40A2040E94528115C09599BFD4F3525A40AF1F7BDD678115C0A789D12DF3525A40F8C1F8A97C8115C0FF29CC76F2525A405D27B3EC908115C0045A20B0F1525A40E8812B99A48115C010A048DAF0525A4042AE3FA3B78115C0D6DDC8F5EF525A4096AF31FFC98115C00FFF2D03EF525A4076EDAEA1DB8115C093A20D03EE525A40722FD77FEC8115C013BE05F6EC525A406852438FFC8115C0AA3CBCDCEB525A40C4B20BC60B8215C08F98DEB7EA525A407D48CE1A1A8215C016702188E9525A406970B484278215C04716404EE8525A40E75F78FB338215C05F1FFC0AE7525A40B03E6A773F8215C066E91CBFE5525A40B2E474F1498215C03B216F6BE4525A408F382263538215C05D44C410E3525A40512B9FC65B8215C0B21FF2AFE1525A401C50BF16638215C0AD4BD249E0525A40590D004F698215C01BA641DFDE525A4091648B6B6E8215C0EEC91F71DD525A4011503A69728215C04D854E00DC525A408FB49645758215C0564EB18DDA525A4034E6DCFE768215C0D7B62C1AD9525A408FBEFC93778215C04EDFA5A6D7525A4000459A04778215C0A0E90134D6525A400AE70D51758215C0C26B25C3D4525A402E42647A728215C0C3E2F354D3525A40BB7D5D826E8215C07C264FEAD1525A4003376C6B698215C046DE1684D0525A4072FEB338638215C00CF72723CF525A40206807EE5B8215C0071B5CC8CD525A4035B0E58F538215C0812B8974CC525A4037F577234A8215C0EBBC8028CB525A40D7088EAE3F8215C09E950FE5C9525A4053DA9A37348215C08D2FFDAAC8525A40AB7CB0C5278215C0413D0B7BC7525A4005CA7B601A8215C06032F555C6525A40C2A73F100C8215C016D06F3CC5525A405EEECFDDFC8115C093B5282FC4525A408CF78BD2EC8115C000F5C52EC3525A4083D658F8DB8115C00CADE53BC2525A40A23D9B59CA8115C06DA71D57C1525A40A4153101B88115C07EFCFA80C0525A40C3C96AFAA48115C034BC01BABF525A40744D0451918115C0BA9CAC02BF525A40C9DF1D117D8115C0B6AE6C5BBE525A40B7903447688115C09617A9C4BD525A40AD8D1A00538115C0F2D1BE3EBD525A402239EF483D8115C0347400CABC525A409D12172F278115C0ACFDB566BC525A40AC7433C0108115C02BAA1C15BC525A403C2C1A0AFA8015C039CC66D5BB525A40DBF0CC1AE38015C016AEBBA7BB525A40FCC07000CC8015C07C79378CBB525A40DA2845C9B48015C04226EB82BB525A40F0789B839D8015C0E56FDC8BBB525A405FF1CD3D868015C003D205A7BB525A4001E836066F8015C0C28B56D4BB525A4061EE27EB578015C027AAB213BC525A4000FDE0FA408015C05019F364BC525A4094A987432A8015C096BCE5C7BC525A40946D1ED3138015C0708D4D3CBD525A40FD017CB7FD7F15C019C1E2C1BD525A4027D742FEE77F15C0DAF45258BE525A4069ABD8B4D27F15C0D36041FFBE525A4062485EE8BD7F15C03F1147B6BF525A40346AA7A5A97F15C0EB25F37CC0525A4023D632F9957F15C0D517CB52C1525A4037A622EF827F15C0C1044B37C2525A406FCD3493707F15C08A00E629C3525A40FFD9BBF05E7F15C0136C062AC4525A40B8F997124E7F15C086510E37C5525A40F64430033E7F15C0C3C55750C6525A4064546CCC2E7F15C0B64E3575C7525A401325AE77207F15C04D4EF2A4C8525A40554FCC0D137F15C0E571D3DEC9525A4028930C97067F15C0C7251722CB525A4074BE1E1BFB7E15C08F0CF66DCC525A4058EF17A1F07E15C0227AA3C1CD525A40BC356E2FE77E15C0E1F14D1CCF525A40B197F4CBDE7E15C0DFA71F7DD0525A40DE79D77BD77E15C0BA043FE3D1525A40616E9943D17E15C0C92BCF4DD3525A40116D1027CC7E15C05583F0BBD4525A40DE756329C87E15C07C3EC12CD6525A403D9F084DC57E15C071E85D9FD7525A403491C393C37E15C0C6F0E112D9525A40626FA4FEC27E15C05B386886DA525A40A930078EC37E15C0AF9E0BF9DB525A40D0669341C57E15C02F8FE769DD525A40BB743C18C87E15C0268E18D8DE525A408F344210CC7E15C011C5BC42E0525A407D0B3227D17E15C0E18DF4A8E1525A40A36CE859D77E15C0E3FCE209E3525A4072C892A4DE7E15C00969AE64E4525A4043E8B102E77E15C01AF280B8E5525A40F5B31C6FF07E15C0A2048904E7525A40136103E4FA7E15C02CDBF947E8525A406108F35A067F15C08BFC0B82E9525A408E9FD9CC127F15C0E1B6FDB1EA525A40C5550A32207F15C0109713D7EB525A407B4F42822E7F15C058DC98F0EC525A4071BEADB43D7F15C0CEE7DFFDED525A408D53EDBF4D7F15C070A742FEEE525A4061061C9A5E7F15C08EFC22F1EF525A407A2FD538707F15C0551DEBD5F0525A4012F13A91827F15C027F10DACF1525A40C5EAFC97957F15C0A7670773F2525A40C2335F41A97F15C027CA5C2AF3525A4055974181BD7F15C05C079DD1F3525A40820F274BD27F15C014F96068F4525A404C783D92E77F15C0D7A34BEEF4525A401F786549FD7F15C042700A63F5525A40AE973A63138015C0F45D55C6F5525A40DB831BD2298015C0F82FEF17F6525A4064763288408015C08C92A557F6525A407ABD7D77578015C0293A5185F6525A407C5FD8916E8015C0C4FBD5A0F6525A4000D402C9858015C029DE22AAF6525A4063CDAB0E9D8015C07A2432A1F6525A403D0D7954B48015C0B5510986F6525A40673E108CCB8015C05525B958F6525A40FBCE1FA7E28015C0F8905D19F6525A40F8C46797F98015C029A71DC8F5525A402C88C24E108115C0
\.


--
-- Data for Name: tugas5_centroid_wilayah; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.tugas5_centroid_wilayah (id, nama, geom) FROM stdin;
1	Tanjung Karang Pusat	0101000020E61000006F3D0AD7A3505A403433333333B315C0
2	Tanjung Karang Barat	0101000020E61000008FC2F5285C4F5A4099999999999915C0
3	Teluk Betung Selatan	0101000020E6100000E37A14AE47515A4052B81E85EBD115C0
4	Rajabasa	0101000020E610000067666666664E5A4000000000008015C0
5	Sukarame	0101000020E61000003133333333535A4086EB51B81E8515C0
6	Kedaton	0101000020E61000000000000000505A4014AE47E17A9415C0
7	Way Halim	0101000020E61000000AD7A3703D525A40285C8FC2F5A815C0
8	Panjang	0101000020E6100000ED51B81E85535A406666666666E615C0
\.


--
-- Data for Name: tugas5_tumpang_tindih; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.tugas5_tumpang_tindih (id, geom) FROM stdin;
1	0106000020E61000000B0000000103000000010000001D00000062F0114B42505A40D6B4C0B54DAB15C0AB89C36144505A40BCEB161D1EAB15C0CC4D199D46505A403EFBCB37F0AA15C057E0B2FB48505A40A2E42D22C4AA15C079251A7C4B505A402EB26CF799AA15C0BC28C41C4E505A40A9B389D171AA15C09A1012DC50505A400D7447C94BAA15C0541E52B853505A4051751AF627AA15C03B890CCC53505A40E6AA1C1727AA15C02538338F53505A40E3C3CCA432AA15C05C67960953505A40E265E85D48AA15C0295E1E7352505A4032E030A75DAA15C080E827CC51505A407A78857372AA15C073FE191551505A40DB8312B686AA15C0B384654E50505A40475059629AAA15C0F00685784F505A40E6D8376CADAA15C0466CFC934E505A40EE41F0C7BFAA15C0E3A558A14D505A406716306AD1AA15C01F582FA14C505A40BC431748E2AA15C02D7E1E944B505A40E0CE3E57F2AA15C0B208CC7A4A505A40873EBF8D01AB15C06B77E55549505A4005B736E20FAB15C02F6E1F2648505A407AC3CE4B1DAB15C0814535EC46505A4071C941C229AB15C00D97E8A845505A408D22E03D35AB15C03DC6005D44505A403CDA94B73FAB15C041854A0943505A40200CEA2849AB15C05753614A42505A40880A3DC74DAB15C062F0114B42505A40D6B4C0B54DAB15C001030000000100000069000000F112C6992C505A409880F30F549815C05CECAA2729505A40A4C95157669815C010284EA825505A40089DFCE2759815C055FAD71D22505A40B68D5DA9829815C0FF6F778A1E505A40D4A093A28C9815C09B1561F01A505A40522978C8939815C03E9BCD5117505A40A593A216989815C0C275F8B013505A40781D6B8A999815C0507E1E1010505A402B79EC22989815C010917C710C505A404F5B04E1939815C0D12B4ED708505A40EAF152C78C9815C08E0DCC4305505A40A74539DA829815C0A5D72AB901505A40E486D61F769815C096B19939FE4F5A408F4604A0669815C01CF040C7FA4F5A40419F5164549815C07118D288FA4F5A4076A49BE2529815C0758A1D4CFA4F5A409479C7E24C9815C0A344CC94F94F5A40B93EA9A2389815C04B8190EDF84F5A408E998CD8239815C04663D156F84F5A402AD743910E9815C069E2EBD0F74F5A40CD76EED9F89715C02D92325CF74F5A40E311F1BFE29715C0C46EEDF8F64F5A40E919ED50CC9715C0B0B059A7F64F5A40B06FB89AB59715C00DA7A967F64F5A409BDB54AB9E9715C07E98043AF64F5A40D669E790879715C001AB861EF64F5A4039B1AF59709715C08BD24015F64F5A409E09FF13599715C09BC6381EF64F5A4069B72FCE419715C0B3FE6839F64F5A407C119C962A9715C0BFB5C066F64F5A4032A7957B139715C076F423A6F64F5A40BD6B5C8BFC9615C090A26BF7F64F5A4048EC15D4E59615C0EE9E655AF74F5A409796C463CF9615C07FDED4CEF74F5A40E2143F48B99615C0E9917154F84F5A4095C5278FA39615C0D551E9EAF84F5A401852E4458E9615C0BD51DF91F94F5A40196C9579799615C02F99EC48FA4F5A40DEB40E37659615C04843A00FFB4F5A40E7D3CE8A519615C05EC47FE5FB4F5A40B2C2F7803E9615C0893507CAFC4F5A40FC5047252C9615C005A6A9BCFD4F5A400DE70F831A9615C01A72D1BCFE4F5A404A8A31A5099615C0689FE0C9FF4F5A402A281396F99515C0523E31E300505A40162C9C5FEA9515C05AD0150802505A40AC632E0BDC9515C01AB3D93703505A40AB35A0A1CE9515C0AD8FC17104505A40762E372BC29515C039CE0BB505505A4083E6A2AFB69515C0560DF10007505A40B544F835AC9515C0FC9CA45408505A402B20ADC4A29515C0C9FC54AF09505A40A24494619A9515C0295D2C100B505A4022DBD911939515C03C2351760C505A40F53800DA8C9515C0086FE6E00D505A400F18DDBD879515C0A7A30C4F0F505A40993997C0839515C03BF1E1BF10505A408574A4E4809515C024E0823212505A40B930C82B7F9515C053DD0AA613505A40415112977E9515C038C7941915505A402A8CDE267F9515C0177B3B8C16505A404032D4DA809515C04F621AFD17505A406D65E6B1839515C05DFF4D6B19505A4011BF54AA879515C01C7AF4D51A505A40EF63ACC18C9515C01A2B2E3C1C505A403187C9F4929515C076251E9D1D505A40FA59D93F9A9515C02FBFEAF71E505A401B675C9EA29515C05117BE4B20505A40E658290BAC9515C0E899C69721505A406D287080B69515C0398137DB22505A4035B3BDF7C19515C00D54491524505A401AB5FF69CE9515C0B4603A4525505A40E82489CFDB9515C07C344F6A26505A406BF01620EA9515C0490FD38327505A407D14D552F99515C00E53189128505A400B0F645E099615C0E1EE789129505A40B3A6DE381A9615C064C556842A505A403905E0D72B9615C04B0E1C692B505A404C208A303E9615C0B9B23B3F2C505A40666D8C37519615C046A431062D505A4006DC2AE1649615C06F2E83BD2D505A405E124521799615C04742BF642E505A40FEE75DEB8D9615C02ABC7EFB2E505A403619A332A39615C062A364812F505A408E2FF5E9B89615C07C631EF62F505A40B799EF03CF9615C030FF635930505A408EEDF072E59615C0D13CF8AA30505A40C6502329FC9615C00ECCA8EA30505A4095008518139715C0F7644E1831505A407CF5F0322A9715C03BE0CC3331505A40509C276A419715C08448133D31505A40D59FD7AF589715C0F3E41B3431505A403FBDA6F56F9715C0A33CEC1831505A402E9E3A2D879715C0421395EB30505A40B2B241489E9715C0BF5E32AC30505A40FC057C38B59715C00A36EB5A30505A402908C4EFCB9715C0FDB8F1F72F505A40BD471760E29715C06CF182832F505A40CC159F7BF89715C08BADE6FD2E505A40390EB9340E9815C09E536F672E505A401181FF7D239815C02EAF79C02D505A4042B5514A389815C0CCB76C092D505A406001DC8C4C9815C037B01EC92C505A40B227BAEA529815C0F112C6992C505A409880F30F549815C00103000000010000003F000000CCA4AC92AB4E5A40D41EEFD6DA7F15C0D6EB9620A84E5A406EA5BE1DED7F15C0D92840A1A44E5A408913D8A8FC7F15C0688CD016A14E5A40FE55A56E098015C0471F77839D4E5A404DCD4567138015C09F6968E9994E5A40E928938C1A8015C0CB16DD4A964E5A40C63225DA1E8015C09B9610AA924E5A40C386544D208015C0DFBC3F098F4E5A40FD353CE51E8015C01B60A76A8B4E5A400254BAA21A8015C034F882D0874E5A40E26D6F88138015C0F93D0B3D844E5A402AEBBC9A098015C059CC74B2804E5A409A5AC2DFFC7F15C02AC4EE327D4E5A40F8AA595FED7F15C04A73A1C0794E5A40BD531223DB7F15C0C06E4CF9774E5A40C8BC9425D07F15C0CD361A8C784E5A4001385EDCBD7F15C045312943794E5A40816AF299A97F15C04C52DE097A4E5A40821ED0ED957F15C0500DBFDF7A4E5A40433B19E4827F15C0A87A47C47B4E5A40A97C8B88707F15C0F7A8EAB67C4E5A40943579E65E7F15C010F412B77D4E5A408A54C2084E7F15C0446122C47E4E5A40A8AECDF93D7F15C0D20073DD7F4E5A40A19582C32E7F15C039545702814E5A4007BC426F207F15C03AB91A32824E5A404B6CE405137F15C042D9016C834E5A405315AD8F067F15C0E81C4BAF844E5A40F4304C14FB7E15C05F232FFB854E5A407086D69AF07E15C0623DE14E874E5A403CCCC129E77E15C072EB8FA9884E5A4096ACE0C6DE7E15C00A5F650A8A4E5A402A2E5F77D77E15C07AFE87708B4E5A403983BF3FD17E15C018EB1ADB8C4E5A40FD41D723CC7E15C079893E498E4E5A405A07CD26C87E15C0510B11BA8F4E5A408885164BC57E15C0BEFAAE2C914E5A4048FF7692C37E15C088C633A0924E5A403F32FEFDC27E15C0174FBA13944E5A40D4AE078EC37E15C0C2735D86954E5A4017A03A42C57E15C01CA038F7964E5A4030028A19C87E15C0EE586865984E5A40CB483512CC7E15C07AC80AD0994E5A401D73C929D17E15C0C64940369B4E5A40018F225DD77E15C08BF22B979C4E5A40A9A86DA8DE7E15C06F1BF4F19D4E5A405B262B07E77E15C039E6C2459F4E5A405F8E3174F07E15C0C6C1C691A04E5A405EB6B0E9FA7E15C035EB32D5A14E5A401C593561067F15C03EEC3F0FA34E5A407E10ADD3127F15C028162C3FA44E5A402FB26A39207F15C043F93B64A54E5A40CC0B2B8A2E7F15C07FD8BA7DA64E5A40FBFA19BD3D7F15C0E018FB8AA74E5A4092DFD7C84D7F15C094AC568BA84E5A403D637FA35E7F15C058792F7EA94E5A400394AB42707F15C0F7B9EF62AA4E5A40284D7E9B827F15C0B25A0A39AB4E5A4011EBA6A2957F15C03650FBFFAB4E5A409745694CA97F15C015E947B7AC4E5A40B8ECA48CBD7F15C0300AD64CAD4E5A40E630C224D07F15C0CCA4AC92AB4E5A40D41EEFD6DA7F15C0010300000001000000880000003746AA1823515A40AA58ADCC8BC915C03F3A150A20515A40C961359E8AC915C090F4A9C31F515A40DA6C6C4B8AC915C00AF6BFBF1F515A400BA390098AC915C06800DBCC1E515A407A18AF6A78C915C0D6D40EE81D515A404A18231266C915C03C8EE8111D515A40A0223D0B53C915C0CA3EEC4A1C515A40863EB9613FC915C08A9E94931B515A4036BDB7212BC915C0ADBF52EC1A515A405CBFB55716C915C0D2C88D551A515A40A781851001C915C067B5A2CF19515A4046744659EBC815C0561CE45A19515A40ED225D3FD5C815C010FD99F718515A40BFF26AD0BEC815C02D9301A618515A40A3B9451AA8C815C0A4304D6618515A408336EF2A91C815C0CB1EA43818515A40846D8C107AC815C01586221D18515A40F0EE5CD962C815C0BB5CD91318515A409D0DB2934BC815C0465CCE1C18515A405E0AE64D34C815C007FEFB3718515A401B3A53161DC815C0857E516518515A40AF2B4BFB05C815C0D0E7B2A418515A404FD30D0BEFC715C0C322F9F518515A40B5C0C053D8C715C0200FF25819515A40B86566E3C1C715C07EA260CD19515A401D72D5C7ABC715C0EC0DFD521A515A40634BB00E96C715C03DEA74E91A515A4077A35CC580C715C0DA6A6B901B515A400836FBF86BC715C0FF9679471C515A40BFAF5FB657C715C03D892E0E1D515A40F7C4080A44C715C01CB50FE41D515A40547D180031C715C0AE3299C81E515A401CB84CA41EC715C0EA0F3EBB1F515A406EEEF7010DC715C099A768BB20515A40C237FA23FCC615C0A0FD7AC821515A40D894BA14ECC615C07220CFE122515A40988520DEDCC615C0628FB70624515A4035ED8D89CEC615C0A9A57F3625515A401549D91FC1C615C0CB096C7026515A404B3D48A9B4C615C02521BBB327515A40ED7A8A2DA9C615C04F87A5FF28515A406A02B5B39EC615C015895E532A515A403CC53D4295C615C0B9A214AE2B515A404CAAF7DE8CC615C02101F20E2D515A407BF60E8F85C615C0BC051D752E515A40961B06577FC615C0B4CCB8DF2F515A40A4F0B23A7AC615C028B5E54D31515A4066543C3D76C615C016EBC1BE32515A40D03B186173C615C09FF2693134515A402E2D0AA871C615C05234F9A435515A40382A221371C615C0288A8A1837515A40DF07BCA271C615C0CDCC388B38515A40F6357F5673C615C0FF601FFC39515A4087F55E2D76C615C07CC45A6A3B515A4008FF9A257AC615C0571A09D53C515A403D96C03C7FC615C044B64A3B3E515A402E0DAC6F85C615C085A6429C3F515A40A3B38ABA8CC615C02D3C17F740515A40BA32DD1895C615C06191F24A42515A40BC527A859EC615C03F0D039743515A403B2A92FAA8C615C021E57BDA44515A40B7B3B171B4C615C0ED9A951446515A406BC7C6E3C0C615C016788E4447515A40E6772449CEC615C01A05AB6948515A40F1CD8799DCC615C01A7D368349515A409AE01CCCEBC615C0563D83904A515A402E4784D7FBC615C04930EB904B515A40BEE0D8B10CC715C00D34D0834C515A407EEEB5501EC715C0E97B9C684D515A40997C3DA930C715C0B0ECC23E4E515A40DC151FB043C715C0C973BF054F515A40FABD9E5957C715C0A25817BD4F515A402D2E9C996BC715C05F88596450515A40D24F9A6380C715C09CDB1EFB50515A40BAEFC6AA95C715C006560A8151515A40A3A60262ABC715C0B55FC9F551515A4012F1E87BC1C715C022F8135952515A405971D8EAD7C715C08BE2ACAA52515A403558FBA0EEC715C0BBCB61EA52515A4075EC4F9005C815C013690B1853515A40B42EB1AA1CC815C0C5908D3353515A407092DFE133C815C0384BD73C53515A408CC789274BC815C07EDDE23353515A40D58E556D62C815C0707BA21B53515A40BC024B2577C815C0EB9FF49252515A401A7770897EC815C0DFC1AFB64F515A405D95EC5CA2C815C04E933BBF4C515A40DD2E3DE5C3C815C03C756CAE49515A40EBFDB30DE3C815C01C6C268646515A402C9E19C3FFC815C04CF55B4843515A400B67B9F319C915C0A1D30CF73F515A40CB566C8F31C915C0CBD344943C515A407909A38746C915C03C891A2239515A40C5B36ECF58C915C07518403236515A4081895FDD65C915C05816D54039515A402985D00B67C915C000E189DF3C515A40094B364D6BC915C0147ACB7940515A4044A3626672C915C02E1D610D44515A40CEDEF4527CC915C02E23169847515A40652DCE0C89C915C0685308C94A515A4038B07B2F97C915C0E5164E954A515A40C8876A979AC915C006C13B8849515A4027A7AEA6AAC915C01290E76E48515A4033334DDDB9C915C0D904FF4947515A40AF3DE431C8C915C065C4361A46515A40373E9D9BD5C915C09B284AE044515A40FC853212E2C915C0A8CCFA9C43515A407559F48DEDC915C09D15105142515A402FAECD07F8C915C075B756FD40515A402B89487901CA15C0D336A0A23F515A4092FA91DC09CA15C0CD67C2413E515A404EB57D2C11CA15C00BEA96DB3C515A401840896417CA15C08DA2FA703B515A4049BDDE801CCA15C07133CD023A515A406A48577E20CA15C00572F09138515A40BDE77C5A23CA15C081DB471F37515A4037118C1325CA15C0B408B8AB35515A4067C074A825CA15C00E21263834515A40B31EDB1825CA15C0464D77C532515A40B4BB176523CA15C0092A905431515A40E056378E20CA15C0F63A54E62F515A405D39FA951CCA15C0545EA57B2E515A400822D37E17CA15C0BA4163152D515A4097C2E54B11CA15C025D86AB42B515A40EDCF04010ACA15C0ABD195592A515A409AA6AFA201CA15C03F15BA0529515A40E4840F36F8C915C0C03CA9B927515A40A85BF4C0EDC915C0B913307626515A409238D149E2C915C00B19163C25515A40454CB8D7D5C915C0EF031D0C24515A40B28D5672C8C915C0704C00E722515A400FFEEE21BAC915C0D6B774CD21515A40B19055EFAAC915C025E927C020515A400FB9E9E39AC915C02E9D058820515A400CC3633397C915C03746AA1823515A40AA58ADCC8BC915C001030000000100000064000000AA93394F06525A407D74999D5CB115C0A3D2742B09525A40751EECC938B115C0451ADF220C525A4095B6664117B115C08A11A4330F525A40CC70B718F8B015C0C0BCDF5B12525A405DA31563DBB015C006A89F9915525A4006ED3532C1B015C0A71AE4EA18525A40524A3F96A9B015C0B452A14D1C525A402F1FC19D94B015C001C8C0BF1F525A405E3CAA5582B015C0CB75223F23525A4026E640C972B015C02F2A9EC926525A4036E01B0266B015C0B5DA045D2A525A40AF831C085CB015C00FFD21F72D525A408EE369E154B015C039E3BC9531525A40EE006D9250B015C0301A9A3635525A404713CE1D4FB015C052CA7CD738525A40ABE4728450B015C035DC391E39525A40421E95D750B015C07B87002239525A40AD561E1751B015C060C8E4143A525A40FECBE4B562B015C01081B0F93A525A40E902570E75B015C0B996D6CF3B525A406693241588B015C0F9F6D2963C525A40888D91BE9BB015C057E92A4E3D525A4006B67DFEAFB015C0F35A6DF53D525A40E2006CC8C4B015C03B24338C3E525A40B8448A0FDAB015C097481F123F525A401B23B9C6EFB015C0B62FDF863F525A40842094E005B115C08BD82AEA3F525A4040E6794F1CB115C0AB05C53B40525A4007AB940533B115C01B637B7B40525A40B3BAE2F449B115C055A526A940525A40EB193F0F61B115C08BA1AAC440525A40313F6A4678B115C0035FF6CD40525A4070DC128C8FB115C0922104C540525A4077B3DED1A6B115C0256DD9A940525A40F66F7309BEB115C05D02877C40525A4085817F24D5B115C03AD4283D40525A4048F0C214ECB115C0E0F6E5EB3F525A40CE2618CC02B215C08387F0883F525A407CAB7C3C19B215C0768D85143F525A40C9C419582FB215C093D4EC8E3E525A4080014D1145B215C0EEC078F83D525A401DA2B05A5AB215C00A1C86513D525A4090DB23276FB215C09EDB7B9A3C525A401AF0D26983B215C019E2CAD33B525A40B5183F1697B215C001B9EDFD3A525A4082394620AAB215C0614568193A525A40B25D2A7CBCB215C07876C72639525A4057F5981ECEB215C0C6EEA02638525A4000D1B1FCDEB215C0CAA7921937525A4002D70D0CEFB215C09090420036525A40AD6DC542FEB215C05F275EDB34525A404E9776970CB315C0B80E9AAB33525A4071BB4A011AB315C0EB9DB17132525A40871AFC7726B315C0976D662E31525A40B6E7DAF331B315C036E07FE22F525A40AE06D26D3CB315C033A7CA8E2E525A400E6A6BDF45B315C0A24418342D525A402F0FD4424EB315C00D8A3ED32B525A40B595DF9255B315C09914176D2A525A40C3700BCB5BB315C0C6C67E0229525A40B9AE81E760B315C04140559427525A40EF561BE564B315C0ED537C2326525A40365B62C167B315C0A37CD7B024525A40E71C937A69B315C0E3504B3D23525A40CF829D0F6AB315C0DCF5BCC921525A4088A1258069B315C01392115720525A40D1F383CC67B315C017C02DE61E525A405524C5F564B315C07B01F5771D525A407A67A9FD60B315C08C32490D1C525A408267A3E65BB315C000FF09A71A525A40ACC1D6B355B315C00858144619525A40B21616694EB315C006EC41EB17525A4028AFE00A46B315C052A0689716525A40BFB55F9E3CB315C04A0D5A4B15525A401208632932B315C011FDE20714525A40FCA05DB226B315C040EDCACD12525A40C09E61401AB315C0DD93D39D11525A4073E61BDB0CB315C0E467B87810525A40FF67CF8AFEB215C0A92D2E5F0F525A4001065058EFB215C05B87E2510E525A40DC23FD4CDFB215C0F0897B510D525A4007DEBB72CEB215C0B356975E0C525A40A4EFF0D3BCB215C0C6B9CB790B525A40AB497A7BAAB215C0B8CDA5A30A525A40175FA87497B215C082A4A9DC09525A408D2A37CB83B215C016F6512509525A40C5F1468B6FB215C0AFD40F7E08525A40BDCA54C15AB215C016674AE707525A4062E8327A45B215C003A95E6107525A4007B200C32FB215C0C9319FEC06525A407AAB22A919B215C06301548906525A40E7323A3A03B215C01254BA3706525A4038181D84ECB115C0987C04F805525A405B15CD94D5B115C02CC559CA05525A40752A6F7ABEB115C04B57D6AE05525A40D3E44243A7B115C04C2A8BA505525A40549599FD8FB115C0F9F87DAE05525A40DF7BCDB778B115C09D84BDC605525A40B6662FFF63B115C0AA93394F06525A407D74999D5CB115C001030000000100000061000000825015901F525A40B1DD90B291A115C040F1EC3023525A408284FD3D90A115C00202CAD126525A40A306AEA491A115C042AB6F702A525A40F62BC5E595A115C05F73A20A2E525A40B349A3FE9CA115C0139F299E31525A40E1E0E7EAA6A115C02290D02835525A40E95074A4B3A115C08F2168A838525A40359E6F23C3A115C06600C81A3C525A40A2484B5ED5A115C05E00D07D3F525A406630C949EAA115C0666B69CF42525A403A8502D901A215C0694B880D46525A40C2BA6FFD1BA215C06BAD2C3649525A40497EF1A638A215C03CDD63474C525A4084A8DAC357A215C00C99493F4F525A409D23FB4079A215C0063C091C52525A40B1C0AB099DA215C0E64E2ECD52525A400FD89B99A6A215C0D8FC83D352525A40594B7A75B6A215C0F7DA91CA52525A408DBC46BBCDA215C0A45E67AF52525A40851DDCF2E4A215C06148158252525A406EDDE80DFCA215C0F78AB74252525A4007042DFE12A315C0493A75F151525A4071FB82B529A315C03073808E51525A409649E82540A315C09B3C161A51525A407334864156A315C0E9617E9450525A40584ABAFA6BA315C0A8460BFE4F525A4039CB1E4481A315C0C0B319574F525A4082EB921096A315C0419E10A04E525A40E3EC4253AAA315C0DFE760D94D525A40CC07B0FFBDA315C05A1985034D525A40CB1FB809D1A315C0EA16011F4C525A40763F9D65E3A315C0E6CE612C4B525A404AD60C08F5A315C0E1E23C2C4A525A403FB426E605A415C0594B301F49525A4007BF83F515A415C052F6E10548525A40585C3C2C25A415C0FD60FFE046525A40E18DEE8033A415C0B82C3DB145525A4089BAC3EA40A415C0ACAF567744525A40242276614DA415C03F810D3443525A403AF755DD58A415C0B30229E841525A40D21C4E5763A415C029E4759440525A40F384E8C86CA415C06BA6C5393F525A40522C522C75A415C0B119EED83D525A40FAB15E7C7CA415C0C6D9C8723C525A406A888BB482A415C0CFC732083B525A4074BD02D187A415C015820B9A39525A40CF579DCE8BA415C019DA342938525A40B948E5AA8EA415C04D4992B636525A40FAF0166490A415C0CB64084335525A40D13622F990A415C056507CCF33525A40502EAB6990A415C01131D35C32525A40AC510AB68EA415C01FA0F1EB30525A40114B4CDF8BA415C0B31DBB7D2F525A40634E31E787A415C0B68411132E525A4072052CD082A415C0837FD4AC2C525A400B0D609D7CA415C0F0FDE04B2B525A407205A05275A415C00EAD10F129525A40DF366BF46CA415C0E770399D28525A409FCBEA8763A415C093E02C5127525A40F1A0EE1259A415C0F9C4B70D26525A405CB1E99B4DA415C07B9AA1D324525A40D81AEE2941A415C0F515ACA323525A4039C2A8C433A415C042AD927E22525A4023975C7425A415C09F230A6521525A40057CDD4116A415C0301AC05720525A400DD48A3606A415C0ECA45A571F525A408FBB495CF5A315C02FE477641E525A408BED7EBDE3A315C032A3AD7F1D525A40E75A0865D1A315C0B1FB88A91C525A408B76365EBEA315C0DCFE8DE21B525A40163BC5B4AAA315C0EC63372B1B525A4044EED47496A315C0723CF6831A525A401DA6E2AA81A315C09DAE31ED19525A40A095C0636CA315C09CB5466719525A403C248EAC56A315C048E887F218525A40E0D5AF9240A315C034463D8F18525A40E208C7232AA315C04A0BA43D18525A40608DA96D13A315C0038AEEFD17525A40831D597EFCA215C0660C44D017525A40B3B9FA63E5A215C0C7BBC0B417525A4089EFCD2CCEA215C0728F75AB17525A40321024E7B6A215C02B4268B417525A40F05B57A19FA215C0B34E93CF17525A401628C26988A215C025F3E5FC17525A400305B64E71A215C0573B443C18525A4076E9725E5AA215C01512878D18525A40C5681EA743A215C037597CF018525A405BF9BA362DA215C09408E76419525A40A8501F1B17A215C0A4537FEA19525A40CBDAED6101A215C0C2D5F2801A525A4055518C18ECA115C00AC5E4271B525A408B781B4CD7A115C0882BEEDE1B525A40A2066F09C3A115C0C0269EA51C525A406BBA055DAFA115C0472D7A7B1D525A40F2A601539CA115C0682028E71D525A40D7BC5EAC93A115C0825015901F525A40B1DD90B291A115C00103000000010000004F00000039FEC36AF5525A40520ACE1A638015C096A71908F2525A40EF738B13788015C0DE130D96EE525A406F3CE05B8A8015C03741BE16EB525A4058D685E8998015C04A5B558CE7525A40A439E5AFA68015C0B36601F9E3525A403ACE1CAAB08015C037E8F65EE0525A40DB4705D1B78015C093886EC0DC525A404E723520BC8015C0C7B5A31FD9525A4062E90495BD8015C09842D37ED5525A40F0BC8D2EBC8015C04D053AE0D1525A4094FEACEDB78015C056761346CE525A407F3902D5B08015C0D74F98B2CA525A40ECD3EDE8A68015C0E12EFD27C7525A40AC5C8E2F9A8015C0323771A8C3525A4055C4BCB08A8015C058BA1C36C0525A40CA860776788015C008E31FD3BC525A400CC6AC8A638015C0F34DDCCBBB525A408DD7BB3D5C8015C0C28B56D4BB525A4061EE27EB578015C027AAB213BC525A4000FDE0FA408015C05019F364BC525A4094A987432A8015C096BCE5C7BC525A40946D1ED3138015C0708D4D3CBD525A40FD017CB7FD7F15C019C1E2C1BD525A4027D742FEE77F15C0DAF45258BE525A4069ABD8B4D27F15C0D36041FFBE525A4062485EE8BD7F15C03F1147B6BF525A40346AA7A5A97F15C0EB25F37CC0525A4023D632F9957F15C0D517CB52C1525A4037A622EF827F15C0C1044B37C2525A406FCD3493707F15C08A00E629C3525A40FFD9BBF05E7F15C0136C062AC4525A40B8F997124E7F15C086510E37C5525A40F64430033E7F15C0C3C55750C6525A4064546CCC2E7F15C0B64E3575C7525A401325AE77207F15C04D4EF2A4C8525A40554FCC0D137F15C0E571D3DEC9525A4028930C97067F15C0C7251722CB525A4074BE1E1BFB7E15C08F0CF66DCC525A4058EF17A1F07E15C0227AA3C1CD525A40BC356E2FE77E15C0E1F14D1CCF525A40B197F4CBDE7E15C0DFA71F7DD0525A40DE79D77BD77E15C0BA043FE3D1525A40616E9943D17E15C0C92BCF4DD3525A40116D1027CC7E15C05583F0BBD4525A40DE756329C87E15C07C3EC12CD6525A403D9F084DC57E15C071E85D9FD7525A403491C393C37E15C0C6F0E112D9525A40626FA4FEC27E15C05B386886DA525A40A930078EC37E15C0AF9E0BF9DB525A40D0669341C57E15C02F8FE769DD525A40BB743C18C87E15C0268E18D8DE525A408F344210CC7E15C011C5BC42E0525A407D0B3227D17E15C0E18DF4A8E1525A40A36CE859D77E15C0E3FCE209E3525A4072C892A4DE7E15C00969AE64E4525A4043E8B102E77E15C01AF280B8E5525A40F5B31C6FF07E15C0A2048904E7525A40136103E4FA7E15C02CDBF947E8525A406108F35A067F15C08BFC0B82E9525A408E9FD9CC127F15C0E1B6FDB1EA525A40C5550A32207F15C0109713D7EB525A407B4F42822E7F15C058DC98F0EC525A4071BEADB43D7F15C0CEE7DFFDED525A408D53EDBF4D7F15C070A742FEEE525A4061061C9A5E7F15C08EFC22F1EF525A407A2FD538707F15C0551DEBD5F0525A4012F13A91827F15C027F10DACF1525A40C5EAFC97957F15C0A7670773F2525A40C2335F41A97F15C027CA5C2AF3525A4055974181BD7F15C05C079DD1F3525A40820F274BD27F15C014F96068F4525A404C783D92E77F15C0D7A34BEEF4525A401F786549FD7F15C042700A63F5525A40AE973A63138015C0F45D55C6F5525A40DB831BD2298015C0F82FEF17F6525A4064763288408015C08C92A557F6525A407ABD7D77578015C0E1FC1C61F6525A40D82267415C8015C039FEC36AF5525A40520ACE1A638015C0010300000001000000A9000000A607F95AD3505A402AB2AEB90BB915C097A95CD5D2505A40DA74D07221B915C006F3E43ED2505A40FB0F20BC36B915C0B3AFEE97D1505A40D8C47C884BB915C091D7E0E0D0505A4088E312CB5FB915C0464F2C1AD0505A4062B4637773B915C08AA24B44CF505A40692C4D8186B915C096B8C25FCE505A400A6911DD98B915C0CA821E6DCD505A4003EE5D7FAAB915C0BFA5F46CCC505A40EAA0525DBBB915C0041DE35FCB505A405A7E886CCBB915C0A8D98F46CA505A40280418A3DAB915C0E75BA821C9505A405C4D9FF7E8B915C02848E1F1C7505A4055DB4761F6B915C095F7F5B7C6505A406509CCD702BA15C08F04A874C5505A4097267C530EBA15C049D3BE28C4505A40673343CD18BA15C0CB1607D5C2505A402040AB3E22BA15C0B952527AC1505A408B68E1A12ABA15C0165A7619C0505A40786BB9F131BA15C067CB4CB3BE505A40CFDBB02938BA15C07B8AB248BD505A4053E8F1453DBA15C0313887DABB505A402CB9554341BA15C087A8AC69BA505A406961661F44BA15C05B5706F7B8505A40F16360D845BA15C017DC7883B7505A4060C9336D46BA15C0B65CE90FB6505A4041C884DD45BA15C073003D9DB4505A405EFDAB2944BA15C07762582CB3505A406935B65241BA15C0D2041FBEB1505A40B1C6635A3DBA15C033C47253B0505A40427D274338BA15C0974C33EDAE505A40E017251032BA15C0588F3D8CAD505A406E582FC52ABA15C0E63A6B31AC505A4049A8C56622BA15C0893492DDAA505A40655211FA18BA15C076148491A9505A401254E2840EBA15C088A40D4EA8505A4037C7AB0D03BA15C0F261F613A7505A4070E87F9BF6B915C03F0200E4A5505A405DBA0B36E9B915C0CFFBE5BEA4505A408C4992E5DAB915C041125DA5A3505A405D94E7B2CBB915C0F2E61298A2505A40E8186BA7BBB915C0EF8DAD97A1505A40500D02CDAAB915C08027CBA4A0505A404345112E99B915C0A97E01C09F505A400BC976D586B915C0C3ACDDE99E505A40BC2183CE73B915C07DC2E3229E505A40CF5EF22460B915C065768E6B9D505A4068D9E4E44BB915C03DD94EC49C505A4096B9D71A37B915C03F108C2D9C505A40E5429DD321B915C08215A3A79B505A40CFEB541C0CB915C0A47EE6329B505A40B8456302F6B815C0DB499ECF9A505A40E8BA6993DFB815C08FB1077E9A505A40C7253EDDC8B815C09A06553E9A505A402749E2EDB1B815C04191AD109A505A407B2C7BD39AB815C0FA782DF599505A40AD62489C83B815C011B3E5EB99505A409C409B566CB815C035F8DBF499505A407D08CE1055B815C0EFC00A109A505A40EB0F3BD93DB815C00E49613D9A505A40E4E533BE26B815C0019AC37C9A505A40047EF8CD0FB815C0159C0ACE9A505A40D566AE16F9B715C0922E04319B505A40531058A6E2B715C0A84673A59B505A40CA27CC8ACCB715C01515102B9C505A409E0FADD1B6B715C0703288C19C505A40FC756088A1B715C0F9D17E689D505A40381207BC8CB715C0DBFA8C1F9E505A400B8C747978B715C0A8C741E69E505A403E9227CD64B715C000AC22BC9F505A405B2642C351B715C020C0ABA0A0505A40F92082673FB715C043125093A1505A40F1F339C52DB715C085FD7993A2505A40FFAE49E71CB715C039868BA0A3505A40964A18D80CB715C04DBBDEB9A4505A40DC3D8DA1FDB615C0AA1CC6DEA5505A40C1620A4DEFB615C02E068D0EA7505A40FE2C66E3E1B615C0171F7848A8505A408736E66CD5B615C08ECDC58BA9505A40EB253AF1C9B615C008AEAED7AA505A40B5F07677BFB615C0440E662BAC505A40217D1206B6B615C0EE8FD611AD505A407D24EC72B0B615C0250DC336AD505A400FB0E813A8B615C0A7ED31ABAD505A406B065CF891B615C0DE82CE30AE505A40C20D3C3F7CB615C0856546C7AE505A40CD74EEF566B615C001C93C6EAF505A4080F3932952B615C0A0B44A25B0505A40423200E73DB615C01C43FFEBB0505A409FE0B13A2AB615C03AE8DFC1B1505A40F600CB3017B615C05FBC68A6B2505A40C16C09D504B615C0ECCD0C99B3505A40D596BF32F3B515C026783699B4505A40EE8FCD54E2B515C087BF47A6B5505A409A519A45D2B515C027B39ABFB6505A4021540D0FC3B515C015D381E4B7505A40A77288BAB4B515C05A7B4814B9505A402122E250A7B515C05A53334EBA505A40D2FD5FDA9AB515C066C18091BB505A40A2ADB15E8FB515C01D6269DDBC505A407D28ECE484B515C063832031BE505A400F5685737BB515C0A1A2D48BBF505A402113501073B515C0F6EDAFECC0505A40349A78C06BB515C018C8D852C2505A407B52818865B515C0874E72BDC3505A402908406C60B515C0C4E19C2BC5505A40FC8EDB6E5CB515C03FAF769CC6505A40C0D0C99259B515C0933C1C0FC8505A406A48CED957B515C0D8F3A882C9505A4055ECF84457B515C094B037F6CA505A40E785A5D457B515C0114DE368CC505A4073797B8859B515C0AC2FC7D9CD505A4068FC6D5F5CB515C0CBD7FF47CF505A40B2BBBC5760B515C0346AABB2D0505A408BEFF46E65B515C04B3CEA18D2505A407DDEF2A16BB515C00D5EDF79D3505A40F1CCE3EC72B515C04422B1D4D4505A40C158484B7BB515C0D4A48928D6505A400F3FF7B784B515C0974E9774D7505A407A8B202D8FB515C0A5560DB8D8505A40B82D51A49AB515C09E4024F2D9505A407FF37616A7B515C0B1571A22DB505A4007E5E47BB4B515C010263447DC505A40150158CCC2B515C08BE8BC60DD505A40FC54FCFED1B515C011FE066EDE505A409F6E720AE2B515C0C0526C6EDF505A40F523D5E4F2B515C050C64E61E0505A4082ADBF8304B615C09C8D1846E1505A40140F54DC16B615C0028F3C1CE2505A408ECB41E329B615C069B936E3E2505A402BDFCC8C3DB615C0B5558C9AE3505A4010FCD4CC51B615C07252CC41E4505A40FB04DD9666B615C098898FD8E4505A40A5C012DE7BB615C01F00795EE5505A4026C2569591B615C0601F36D3E5505A40E78044AFA7B615C003E87E36E6505A40969A3A1EBEB615C0631E1688E6505A40DE3B63D4D4B615C05770C9C7E6505A4001A8BCC3EBB615C03C9471F5E6505A409CDC21DE02B715C02F61F210E7505A40B44A53151AB715C06CE03A1AE7505A404DA0FF5A31B715C0C9574511E7505A40E79CCCA048B715C0394D17F6E6505A406FEB5FD85FB715C06E83C1C8E6505A4056FC67F376B715C07BEF5F89E6505A4034DAA4E38DB715C09DA71938E6505A4099F3F09AA4B715C022CB20D5E5505A4084D4490BBBB715C07C63B260E5505A408CCAD826D1B715C0A23E16DBE4505A40336DFBDFE6B715C0C4C29E44E4505A4027074C29FCB715C07FBBA89DE3505A4010D9A9F510B815C0A1209BE6E2505A405A32413825B815C0ABD6E61FE2505A409E5A93E438B815C02E69064AE1505A4002467EEE4BB815C03BBF7D65E0505A401811444A5EB815C00BCAD972DF505A40A53E92EC6FB815C0102EB072DE505A4038B388CA80B815C0B0E69E65DD505A40576AC0D990B815C0D1E44B4CDC505A40B8E05110A0B815C088A86427DB505A402B30DB64AEB815C013D69DF7D9505A40D0D885CEBBB815C072C6B2BDD8505A40B1340C45C8B815C0E213657AD7505A407F91BEC0D3B815C06A227C2ED6505A4051EE873ADEB815C0EDA4C4DAD4505A40065AF2ABE7B815C08B0854F4D3505A408E811C3FEDB815C0DFA667CFD3505A40B37C209EF5B815C0A607F95AD3505A402AB2AEB90BB915C0010300000001000000DE000000D77EA07D9C505A40AE23A719C2AF15C09335A71A9C505A40F8A6FD89D8AF15C0067238A69B505A4080A889A5EEAF15C061029C209B505A4095C1A85E04B015C0014D248A9A505A40143FF5A719B015C0A81D2EE399505A4030644E742EB015C03D6C202C99505A403783E0B642B015C04C1D6C6598505A40FCE62C6356B015C06DBC8B8F97505A403387116D69B015C0A73003AB96505A405084D0C87BB015C0236B5FB895505A404D65176B8DB015C0331036B894505A40391306499EB015C0171B25AB93505A40698E3558AEB015C0817CD29192505A40A558BE8EBDB015C049B4EB6C91505A401C913EE3CBB015C06666253D90505A408BBDDF4CD9B015C089EB3A038F505A40D63D5CC3E5B015C08DDDEDBF8D505A40C265043FF1B015C019A005748C505A40B93AC3B8FBB015C09FE54E208B505A4014D2222A05B115C022319BC589505A40DF4C508D0DB115C00055C06488505A403F6F1FDD14B115C00CEF97FE86505A409AD10D151BB115C05FE2FE9385505A404BA8453120B115C018CFD42584505A402B21A02E24B115C07488FBB482505A400C55A70A27B115C08289564281505A40AECC97C328B115C0DD68CACE7F505A408E96615829B115C0A94B3C5B7E505A4026EFA8C828B115C0495891E87C505A403579C61427B115C00329AE777B505A406607C73D24B115C0083F76097A505A40FBF56A4520B115C02176CB9E78505A40F916252E1BB115C062798D3877505A40072F19FB14B115C03B3999D775505A40E9051AB00DB115C03163C87C74505A40C70AA75105B115C0A1DBF02873505A40568EE9E4FBB015C0D339E4DC71505A408393B16FF1B015C0B5466F9970505A40C63972F8E5B015C0917E595F6F505A4022C33D86D9B015C00796642F6E505A408337C120CCB015C090024C0A6D505A40A3A83FD0BDB015C0E486C4F06B505A40E2198D9DAEB015C083C37BE36A505A402B0E09929EB015C097CB17E369505A404AC098B78DB015C092BE36F068505A406108A1187CB015C09F666E0B68505A4009F3FFBF69B015C04BDC4B3567505A40610D06B956B015C0782F536E66505A40B56A6F0F43B015C0F315FFB665505A40CC675CCF2EB015C0BE9FC00F65505A4015304A051AB015C060F1FE7864505A403C0A0BBE04B015C0400417F363505A409B6FBE06EFAF15C0576D5B7E63505A403CF4C8ECD8AF15C03B2A141B63505A40BC04CC7DC2AF15C0C2747EC962505A40997D9DC7ABAF15C0389DCC8962505A4076233FD894AF15C062EB255C62505A4049FFD5BD7DAF15C03B86A64062505A4042A5A18666AF15C0A3625F3762505A402D6BF3404FAF15C0E338564062505A40F39325FB37AF15C02D81855B62505A408C7592C320AF15C00077DC8862505A40059F8BA809AF15C089233FC862505A40D10351B8F2AE15C0DA6E861963505A40F6310801DCAE15C01338807C63505A40A998B390C5AE15C03C74EFF063505A4020E42975AFAE15C003548C7664505A4063750DBC99AE15C0F06F040D65505A40FCF8C37284AE15C046FBFAB365505A4055246EA66FAE15C03DFD086B66505A40F49CDF635BAE15C08090BD3167505A40310F97B747AE15C0D0289E0768505A40D279B6AD34AE15C09CDE26EC68505A407EB2FB5122AE15C057C0CADE69505A40CF27B9AF10AE15C06429F4DE6A505A4007E6CED1FFAD15C0651E05EC6B505A40EEE1A3C2EFAD15C0A4AE57056D505A40AF8E1F8CE0AD15C0705A3E2A6E505A4025C2A337D2AD15C0167E045A6F505A40A7EB06CEC4AD15C04FC1EE9370505A40A1A08E57B8AD15C0C58A3BD771505A40EE82EADBACAD15C07F77232373505A402F832F62A2AD15C0D1D5D97674505A409582D3F098AD15C097238DD175505A403F57A98D90AD15C0D02F1DE475505A40A3EC302B90AD15C02A881F8475505A40535596FE7DAD15C0DD37D82075505A4025149A8F67AD15C03C7042CF74505A40FB1C6CD950AD15C0A081908F74505A4020340EEA39AD15C0D9B3E96174505A404162A5CF22AD15C0F72D6A4674505A405D3B71980BAD15C0ECE4223D74505A402415C352F4AC15C01A91194674505A406E32F50CDDAC15C0CBAA486174505A403EE961D5C5AC15C09B6D9F8E74505A40BCC85ABAAEAC15C0D7E201CE74505A4088C41FCA97AC15C0B5F2481F75505A40E76AD61281AC15C0747C428275505A40662B81A26AAC15C04C75B1F675505A40A0B2F68654AC15C00C0E4E7C76505A401862D9CD3EAC15C06DDFC51277505A40EAE68E8429AC15C0DF1CBCB977505A4011F737B814AC15C0C9CDC97078505A40CA38A87500AC15C0070D7E3779505A402A595EC9ECAB15C0914E5E0D7A505A40CF577CBFD9AB15C00AABE6F17A505A40350BC063C7AB15C01B318AE47B505A40F1E27BC1B5AB15C0613CB3E47C505A4041EC8FE3A4AB15C0B6D1C3F17D505A40F91C63D494AB15C0A200160B7F505A4066E9DC9D85AB15C0AD49FC2F80505A4084285F4977AB15C06309C25F81505A40E24AC0DF69AB15C0B9E7AB9982505A402EE745695DAB15C0994BF8DC83505A408DA09FED51AB15C047D2DF2885505A40F368E27347AB15C054CA957C86505A40F22284023EAB15C0E0B148D787505A4010A6579F35AB15C0CBB7223889505A406827894F2EAB15C0943F4A9E8A505A40A4089B1728AB15C08A67E2088C505A40561063FB22AB15C007910B778D505A407A0C08FE1EAB15C059EAE3E78E505A400CE1FF211CAB15C001FA875A90505A401D030E691AAB15C0022B13CE91505A400C6342D419AB15C0D359A04193505A404AC4F8631AAB15C0B3614AB494505A401A85D8171CAB15C0F6A92C2596505A40E5D4D4EE1EAB15C003B3639397505A408B5A2DE722AB15C09BA20DFE98505A4042486FFE27AB15C029CF4A649A505A4094DE76312EAB15C05FAF17A69B505A4006B6AAD734AB15C0C34A49E19C505A40B0D59D4F2EAB15C077C370479E505A4098D8AC1728AB15C09CDE08B29F505A40F9F671FB22AB15C093FD3120A1505A409E0014FE1EAB15C0B24E0A91A2505A4052DB08221CAB15C07D58AE03A4505A40FFFD13691AAB15C0FC853977A5505A40DA5A45D419AB15C0A9B3C6EAA6505A402DB7F8631AAB15C0C1BC705DA8505A401B73D5171CAB15C09B0853CEA9505A40E9BFCEEE1EAB15C098178A3CAB505A40514624E722AB15C0780F34A7AC505A405F3A63FE27AB15C09E46710DAE505A4075DE67312EAB15C002CE646EAF505A40D7725F7C35AB15C06FF934C9B0505A404791CADA3DAB15C0C0E50B1DB2505A40D6F27F4747AB15C0CDFC1769B3505A40229FAFBC51AB15C0A5768CACB4505A40F881E6335DAB15C0DED7A1E6B5505A40286512A669AB15C0966C9616B7505A402E4D860B77AB15C0F0BFAE3BB8505A401735FF5B85AB15C0A60F3655B9505A40A826A98E94AB15C08BBB7E62BA505A4044AC249AA4AB15C09AB0E262BB505A408E988C74B5AB15C065CFC355BC505A40CF207C13C7AB15C09A4D8C3ABD505A40BF45156CD9AB15C06312AF10BE505A404F870773ECAB15C0680DA8D7BE505A40EADE961C00AC15C04888FC8EBF505A4015FCA25C14AC15C044723B36C0505A4018BFAE2629AC15C0FBA5FDCCC0505A4057ECE76D3EAC15C00729E652C1505A40CB142F2554AC15C05665A2C7C1505A40E7AD1F3F6AAC15C01C5CEA2AC2505A409B5318AE80AC15C037D2807CC2505A40F730436497AC15C0F47533BCC2505A40DD879E53AEAC15C01CFEDAE9C2505A40BB54056EC5AC15C02B425B05C3505A40990738A5DCAC15C0B34BA30EC3505A40B34DE5EAF3AC15C0D360AD05C3505A40ECE5B2300BAD15C0BB077FEAC2505A40D97A466822AD15C04B0329BDC2505A40BD7C4E8339AD15C0BC48C77DC2505A4037F68A7350AD15C066EE802CC2505A401656D62A67AD15C0A01388C9C1505A40C8282E9B7DAD15C0D9C11955C1505A4090BCBBB693AD15C0FEC67DCFC0505A40C6A9DC6FA9AD15C025890639C0505A402B3C2BB9BEAD15C0C4D31092BF505A40A6B58685D3AD15C0789E03DBBE505A4018671BC8E7AD15C082CD4F14BE505A40BC996A74FBAD15C028EC6F3EBD505A408F43527E0EAE15C028E1E759BC505A40248314DA20AE15C0559D4467BB505A4074DD5E7C32AE15C0B6C41B67BA505A406A39515A43AE15C038520B5AB9505A401495846953AE15C03E36B940B8505A40DB6F11A062AE15C050F0D21BB7505A406BE695F470AE15C013240DECB5505A40E27B3B5E7EAE15C0E62923B2B4505A40688DBCD48AAE15C0599BD66EB3505A40FA6B695096AE15C0C1DBEE22B2505A40121A2DCAA0AE15C0449D38CFB0505A4011AA913BAAAE15C098628574AF505A40EF39C49EB2AE15C0CFFDAA13AE505A40AC8A98EEB9AE15C0730C83ADAC505A4081318C26C0AE15C05671EA42AB505A40855FC942C5AE15C050CCC0D4A9505A40443F2940C9AE15C059F0E763A8505A403EE6351CCCAE15C0405843F1A6505A40D2D92BD5CDAE15C05D9AB77DA5505A401C25FB69CEAE15C09DDB290AA4505A40360148DACDAE15C023427F97A2505A406E0D6B26CCAE15C001689C26A1505A400A19714FC9AE15C031CE64B89F505A40F07C1A57C5AE15C04C50BA4D9E505A40BD07DA3FC0AE15C037997CE79C505A40C47AD30CBAAE15C0E20177BD9B505A4060EE69E4B3AE15C0DC96C5189C505A400439ED2DC5AE15C0B5520D7C9C505A40637FE79CDBAE15C03E88A3CD9C505A40D1BA1353F2AE15C0E9E5550D9D505A40532C704209AF15C0AC22FD3A9D505A40AACFD75C20AF15C033167D569D505A405B140B9437AF15C03FCAC45F9D505A4040A7B8D94EAF15C02285CE569D505A401447861F66AF15C047CD9F3B9D505A40639E19577DAF15C0C965490E9D505A40921D217294AF15C01C44E7CE9C505A4094CF5C62ABAF15C0D77EA07D9C505A40AE23A719C2AF15C0010300000001000000810000009A390F5540515A407E2C4A697ACE15C0387116F23F515A404EBEA5D990CE15C042F0A77D3F515A40E73338F5A6CE15C0BF840BF83E515A40A1225FAEBCCE15C0089593613E515A4083D2B4F7D1CE15C004ED9CBA3D515A400E8118C4E6CE15C0E3848E033D515A40107AB606FBCE15C0A141D93C3C515A400B0110B30ECF15C06BAFF7663B515A40940503BD21CF15C007B66D823A515A40399FD11834CF15C07A47C88F39515A40534B29BB45CF15C020099D8F38515A408FE8299956CF15C062F7898237515A40296C6CA866CF15C03E04356936515A402A4C09DF75CF15C0FEB04B4435515A40589B9E3384CF15C028A3821434515A4063D2559D91CF15C0203595DA32515A409443E9139ECF15C09302459731515A408334A98FA9CF15C01871594B30515A40E59B8009B4CF15C030359FF72E515A40EA7FF97ABDCF15C008D4E79C2D515A40F7F140DEC5CF15C03E22093C2C515A4028A62A2ECDCF15C008C0DCD52A515A407D243466D3CF15C0F3923F6B29515A408D908782D8CF15C0AB3D11FD27515A402C07FE7FDCCF15C00B96338C26515A40E08F215CDFCF15C0D9198A1925515A40E9A12E15E1CF15C07462F9A523515A40233A15AAE1CF15C0D697663222515A403B83791AE1CF15C045E3B6BF20515A40110EB466DFCF15C0F7E1CE4E1F515A406E9BD18FDCCF15C0151892E01D515A40B0759297D8CF15C06B64E2751C515A40FE5C6980D3CF15C018759F0F1B515A4044047A4DCDCF15C0983DA6AE19515A40A8219702C6CF15C0826ED05318515A40E11240A4BDCF15C044EFF3FF16515A406C179E37B4CF15C0365AE2B315515A40442181C2A9CF15C0567B687014515A40363F5C4B9ECF15C0F9D14D3613515A40F7A241D991CF15C0BE15540612515A408944DE7384CF15C01ABF36E110515A401C26752376CF15C0B893AAC70F515A40043CDAF066CF15C0F9365DBA0E515A409DFA6CE556CF15C0DFBEF4B90D515A40AD8E120B46CF15C0A04D0FC70C515A40DCC22F6C34CF15C022B042E20B515A40E096A21322CF15C090011C0C0B515A40998BBB0C0FCF15C05B541F450A515A40BAA83663FBCE15C0C760C78D09515A401C403423E7CE15C0383985E608515A40FA723159D2CE15C07904C04F08515A40837E0012BDCE15C020BED4C907515A405BD3C05AA7CE15C035FD155507515A4094FDD64091CE15C042C1CBF106515A40A562E4D17ACE15C0EE4533A006515A40B6D8BE1B64CE15C040DD7E6006515A40E11E682C4DCE15C08CD0D53206515A406F39051236CE15C04648541706515A40BCB8D5DA1ECE15C0993A0B0E06515A409CEF2A9507CE15C0FF60001706515A40D91E5F4FF0CD15C0B2342E3206515A40349BCC17D9CD15C018F2835F06515A405AF3C4FCC1CD15C01BA3E59E06515A40441B880CABCD15C06A302CF006515A4059A23B5594CD15C09779255307515A4010FAE1E47DCD15C0FC7394C707515A40C0D151C967CD15C06950314D08515A40698E2D1052CD15C06CA7A9E308515A406CE1DAC63CCD15C022ACA08A09515A40DA857AFA27CD15C07865AF410A515A40B427E0B713CD15C0A4ED64080B515A409A7A8A0B00CD15C0D2B746DE0B515A4070859B01EDCC15C0B4DBD0C20C515A40A726D1A5DACC15C0DA6676B50D515A407ED67D03C9CC15C0A1B3A1B50E515A4085AB8125B8CC15C07FC5B4C20F515A408AA54316A8CC15C073AA09DC10515A407043ABDF98CC15C059E1F20012515A4063671A8B8ACC15C0EDC4BB3013515A40B38D67217DCC15C037FBA86A14515A405C59D8AA70CC15C010E9F8AD15515A404D7A1C2F65CC15C08D29E4F916515A40CEEF48B55ACC15C0F4089E4D18515A4025AAD34351CC15C0FC0255A819515A40038F8FE048CC15C0044433091B515A400FE2A89041CC15C0EE2C5F6F1C515A40D313A2583BCC15C056D9FBD91D515A4015FA503C36CC15C0CFA729481F515A404D72DC3E32CC15C0C9C306B920515A402C70BA622FCC15C0D7B0AF2B22515A40AE78AEA92DCC15C0FDD63F9F23515A40458CC8142DCC15C0A30FD21225515A40977E64A42DCC15C0ED32818526515A4033BE29582FCC15C00BA568F627515A40D48A0B2F32CC15C035E3A46429515A40B79B492736CC15C0F80F54CF2A515A405B33713E3BCC15C0817E96352C515A408EA25E7141CC15C0923C8F962D515A40E1373FBC48CC15C0BE9A64F12E515A40459B931A51CC15C0AFB2404530515A40D49332875ACC15C00AEB519131515A4003374CFC64CC15C0B778CBD432515A40357E6D7370CC15C02BDDE50E34515A40954084E57CCC15C06D61DF3E35515A40A58FE34A8ACC15C0938DFC6336515A403473489B98CC15C05C9C887D37515A405D01DFCDA7CC15C0ADEAD58A38515A407FD047D9B7CC15C0A8623E8B39515A40D1BE9DB3C8CC15C015E2237E3A515A40B90C7C52DACC15C0EF9BF0623B515A4096C504ABECCC15C0C37417393C515A408073E7B1FFCC15C0B65914003D515A408819685B13CD15C0FD916CB73D515A404370669B27CD15C08A0AAF5E3E515A40846065653CCD15C0CB9B74F53E515A409DB692AC51CD15C04449607B3F515A40DD0ACF6367CD15C0F17A1FF03F515A4066D9B57D7DCD15C032306A5340515A403BC4A5EC93CD15C0312C03A540515A40D8FBC8A2AACD15C0AF1BB8E440515A40D5C61D92C1CD15C007B4611241515A40B6257FACD8CD15C072CBE32D41515A40DD8BADE3EFCD15C05F6A2D3741515A402CA9572907CE15C0F0D5382E41515A40863E236F1ECE15C084930B1341515A40B9F7B5A635CE15C04E65B6E540515A409545BEC14CCE15C0024055A640515A408632FCB163CE15C09A390F5540515A407E2C4A697ACE15C001030000000100000081000000313EA93DF8505A407AA33BBBE5A815C0750BB1DAF7505A40295A952BFCA815C08D684366F7505A40F32F254712A915C0F522A8E0F6505A40C4BB480028A915C055A0314AF6505A40C5479A493DA915C0B2AB3CA3F5505A400A14F91552A915C02F3C30ECF4505A40666F915866A915C093357D25F4505A40D7A0E4047AA915C0AB229E4FF3505A40E19BD00E8DA915C0B1E9166BF2505A40707C976A9FA915C0F97A7478F1505A40A3C4E60CB1A915C0077A4C78F0505A405C58DEEAC1A915C041E13C6BEF505A40733217FAD1A915C085A0EB51EE505A40ECCEA930E1A915C0D236062DED505A40EA463485EFA915C0464741FDEB505A40D419E0EEFCA915C0BA2958C3EA505A40FEA0676509AA15C033770C80E9505A4064291BE114AA15C07F922534E8505A4066B1E55A1FAA15C03D2D70E0E6505A402E4751CC28AA15C09DC9BD85E5505A4058048B2F31AA15C02B39E424E4505A407FA5667F38AA15C0F018BDBEE2505A4052BB61B73EAA15C03C4B2554E1505A405672A6D343AA15C0676FFCE5DF505A406FF00DD147AA15C0EE572475DE505A40684622AD4AAA15C0267F8002DD505A40E5F41F664CAA15C0F37AF58EDB505A403902F7FA4CAA15C0CC6F681BDA505A40B3A24B6B4CAA15C06983BEA8D8505A40DB7076B74AAA15C06D4FDC37D7505A40293784E047AA15C06F54A5C9D5505A40BB4935E843AA15C0A36DFB5ED4505A407572FCD03EAA15C09345BEF8D2505A40F06DFD9D38AA15C02CCCCA97D1505A4001FC0A5331AA15C078AEFA3CD0505A40F283A4F428AA15C062D023E9CE505A40BD4EF3871FAA15C0C8C8179DCD505A40BC57C71215AA15C03C60A359CC505A40FBB6939B09AA15C0B1128E1FCB505A4042A76A29FDA915C07B9499EFC9505A407029F9C3EFA915C0D15A81CAC8505A406C488273E1A915C03628FAB0C7505A40FE00DA40D2A915C0FB9CB1A3C6505A40B8CF5F35C2A915C029CC4DA3C5505A4053E9F85AB1A915C018D56CB0C4505A4026200ABC9FA915C0E881A4CBC3505A403E7B71638DA915C021EB81F5C2505A408B827F5C7AA915C0AF20892EC2505A407644F0B266A915C070D83477C1505A403219E47252A915C08322F6CFC0505A40FC27D8A83DA915C097233439C0505A409BB39E6128A915C047D54BB3BF505A40EB3157AA12A915C0C3CC8F3EBF505A40CE336690FCA815C0EC0748DBBE505A4021236D21E6A815C0E6C0B189BE505A4000DA416BCFA815C05848FF49BE505A400F1BE67BB8A815C069E6571CBE505A40A8ED7E61A1A815C083C2D700BE505A40C9E44B2A8AA815C0FBD18FF7BD505A4071559EE472A815C097CD8500BE505A401F82D09E5BA815C0112EB41BBE505A40CDC03C6744A815C0782F0A49BE505A40EDA0344C2DA815C08EDB6B88BE505A40C116F85B16A815C0071BB2D9BE505A4082B1ACA4FFA715C0A3CDAA3CBF505A40FFE15434E9A715C01CE918B1BF505A406D56C718D3A715C0CB9EB436C0505A403272A65FBDA715C0F6872BCDC0505A409DE45716A8A715C09AD82074C1505A403966FC4993A715C0B2982D2BC2505A400FA067077FA715C0AFE3E0F1C2505A404B42185B6BA715C01E2EC0C7C3505A40F54F305158A715C0399147ACC4505A4037A36DF545A715C0451CEA9EC5505A4090AF225334A715C07A2B129FC6505A4072862F7523A715C04DC421ACC7505A402322FB6513A715C0E0F672C5C8505A409DFB6C2F04A715C0584458EAC9505A40C2EEE6DAF5A615C0DB091D1ACB505A4044713F71E8A615C0F9EF0554CC505A40201FBCFADBA615C0365E5197CD505A40F9A00C7FD0A615C06BF237E3CE505A407BEE4505C6A615C0C0FBEC36D0505A4008F0DD93BCA615C0E8F89E91D1505A402983A730B4A615C0521978F2D2505A4018E3CEE0ACA615C00BC19E58D4505A40BC77D6A8A6A615C0ED0E36C3D5505A40020E948CA1A615C0D8645E31D7505A40557A2E8F9DA615C09AF135A2D8505A4032A71BB39AA615C0363CD914DA505A403F101FFA98A615C025B06388DB505A4070AC486598A615C0552AF0FBDC505A40DA45F4F498A615C07386996EDE505A406441C9A89AA615C03E2C7BDFDF505A401ED5BA7F9DA615C07F9CB14DE1505A407FAE0878A1A615C058FD5AB8E2505A405106408FA6A615C088A5971EE4505A40A6233DC2ACA615C05FA68A7FE5505A40634B2D0DB4A615C0FA535ADAE6505A40DA1B916BBCA615C086CB302EE8505A40A3523FD8C5A615C01F773C7AE9505A40C0FB674DD0A615C0178FB0BDEA505A40510798C4DBA615C03F98C5F7EB505A405F43BD36E8A615C0F0DEB927ED505A407BB82A9CF5A615C079EED14CEE505A40AF659DEC03A715C0BF045966EF505A409358411F13A715C0B781A173F0505A403C1FB72A23A715C07C520574F1505A40D98F190534A715C0B557E666F2505A4014E303A445A715C021C7AE4BF3505A40D71C98FC57A715C0F087D121F4505A401EC085036BA715C0D089CAE8F4505A4030C910AD7EA715C05B161FA0F5505A4033EA18ED92A715C0C61C5E47F6505A40E60521B7A7A715C09F7720DEF6505A40F3E256FEBCA715C0692C0964F7505A4056149BB5D2A715C0F3A4C5D8F7505A405C1189CFE8A715C04CE20D3CF8505A4091777F3EFFA715C026A9A48DF8505A406973A8F415A815C09CA757CDF8505A40EF4702E42CA815C04294FFFAF8505A407EF267FE43A815C053468016F9505A40D7E399355BA815C020C7C81FF9505A40A7C9467B72A815C07A5CD316F9505A40176314C189A815C0468CA5FBF8505A40B75AA8F8A0A815C0101950CEF8505A408E20B113B8A815C0B6F7EE8EF8505A40C7BEEE03CFA815C0313EA93DF8505A407AA33BBBE5A815C0
\.


--
-- Data for Name: tugas5_zona_layanan_halte; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.tugas5_zona_layanan_halte (id, geom) FROM stdin;
1	0106000020E610000010000000010300000001000000810000007581783D80505A4041B2DF7935C115C0AEBC45727F505A40A69F16446EC115C06C56D47A7E505A4004B3EB5CA6C115C093E6BC577D505A40A52CC6A1DDC115C082F0B2097C505A40960690F013C215C0657484917A505A40AAF9CA2749C215C0367019F078505A403B26A5267DC215C0A650732677505A4070510DCDAFC215C06352AC3575505A40CDACC6FBE0C215C012D4F61E73505A40A3197C9410C315C055999CE370505A40EEDED2793EC315C079FFFD846E505A405FC37C8F6AC315C0232491046C505A403A8349BA94C315C09AFEE06369505A406E9437E0BCC315C02D6C8CA466505A40823184E8E2C315C0603045C863505A40729EBABB06C415C05DE9CED060505A4077A0C24328C415C076F9FDBF5D505A40BB1EEE6B47C415C03F66B6975A505A406CE3052164C415C00AAEEA5957505A400D7655517EC415C076949A0854505A407806B6EC95C415C0CAE6D1A550505A409F6398E4AAC415C0E438A7334D505A4056F60D2CBDC415C0899B3AB449505A40F2BAD0B7CCC415C0CC4CB42946505A407C354A7ED9C415C07963439642505A40E35B9977E3C415C03C761CFC3E505A408571979DEAC415C0693F785D3B505A4005D3DBEBEEC415C0333E92BC37505A40FAADBE5FF0C415C03156A71B34505A4085A45AF8EEC415C0026EF47C30505A40CA5A8DB6EAC415C0F50DB5E22C505A4042EEF69CE3C415C086FF214F29505A400157F8AFD9C415C08BEE6FC425505A40B8B4B0F5CCC415C0ED0CCE4422505A40B187F975BDC415C0C5B964D21E505A40E8D9613AABC415C0A62C546F1B505A408659284E96C415C0F925B31D18505A40316934BE7EC415C028A58DDF14505A40F32A0E9964C415C072A5E3B611505A40D289D5EE47C415C021E2A7A50E505A40524738D128C415C0F3A2BEAD0B505A409C14675307C415C06B91FCD008505A403EBC098AE3C315C0C397251106505A40F964328BBDC315C039CAEB6F03505A40D3F44F6E95C315C0525BEEEE00505A40EB9C1F4C6BC315C0CE9BB88FFE4F5A400E989D3E3FC315C0D906C153FC4F5A400C23F56011C315C0165B683CFA4F5A40BCBB6FCFE1C215C019C1F84AF84F5A40FAAD63A7B0C215C0C8FFA480F64F5A4072FC21077EC215C02ABF87DEF44F5A401BADE30D4AC215C020DAA265F34F5A403C88B6DB14C215C05BBFDE16F24F5A40DF526991DEC115C008E209F3F04F5A4075937750A7C115C08D3AD8FAEF4F5A40BBEAF43A6FC115C086D7E22EEF4F5A402F10787336C115C06C7FA78FEE4F5A403C7C051DFDC015C00863881DEE4F5A40FBCFF95AC3C015C0F2E0CBD8ED4F5A401806F45089C015C02A5A9CC1ED4F5A40767ABF224FC015C0041808D8ED4F5A402ED73DF414C015C05E43011CEE4F5A405EF350E9DABF15C030ED5D8DEE4F5A40DDB1C425A1BF15C07228D82BEF4F5A40FDED38CD67BF15C045350EF7EF4F5A40C6820B032FBF15C041BD82EEF04F5A40417B42EAF6BE15C0CA209D11F24F5A40717976A5BFBE15C03BD5A95FF34F5A409C5FBD5689BE15C0A2D3DAD7F44F5A40A84B951F54BE15C0D8174879F64F5A40B0EECF2020BE15C09F2FF042F84F5A403E507E7AEDBD15C06DD9B833FA4F5A403707DD4BBCBD15C081B26F4AFC4F5A40F3F640B38CBD15C0E0F3CA85FE4F5A40EC9904CE5EBD15C0B63D6AE400505A4055E875B832BD15C0AB70D76403505A40E0E2C48D08BD15C0A394870506505A403FCFF267E0BC15C051CCDBC408505A40EB2DC25FBABC15C0115522A10B505A40E775A78C96BC15C0719297980E505A40AD9DBA0475BC15C0B02467A911505A401A7BA9DC55BC15C09809ADD114505A400503AB2739BC15C0FAC6760F18505A408A6F73F71EBC15C01B9EC4601B505A40A855295C07BC15C044C78AC31E505A400BAF5B64F2BB15C0CCB4B23522505A40CCDFF81CE0BB15C0B85C1CB525505A4053BD4691D0BB15C040889F3F29505A40989ADBCAC3BB15C054280DD32C505A404D5E98D1B9BB15C063AE306D30505A40B6A7A3ABB2BB15C07B68D10B34505A401603665DAEBB15C003E0B3AC37505A40383287E9ACBB15C01D3A9B4D3B505A400589EC50AEBB15C0EC984AEC3E505A402460B892B2BB15C0DA7C868642505A40AC9D4AACB9BB15C00325161A46505A40DA534299C3BB15C0F3EDC4A449505A40F5738053D0BB15C0D6AD63244D505A4023952BD3DFBB15C04E0DCA9650505A401BCBB40EF2BB15C00EDCD7F953505A405E8BDDFA06BC15C07060764B57505A40959CBE8A1EBC15C039A199895A505A403D0BD0AF38BC15C0B8A841B25D505A40971FF25955BC15C07EC07BC360505A40C34F777774BC15C0EBA463BB63505A40E8252FF595BC15C0D2AF249866505A40021672BEB9BC15C07FF9FA5769505A406C3A2EBDDFBC15C06A6F34F96B505A402CF0F4D907BD15C0E2DF317A6E505A407F4A09FC31BD15C025FA67D970505A40A0536F095EBD15C02842601573505A40B313FCE68BBD15C08DF7B92C75505A403B516678BBBD15C032EF2A1E77505A40480358A0ECBD15C0D35E80E878505A40376880401FBE15C0439A9F8A7A505A4066B8A63953BE15C0C0C186037C505A40BA66BD6B88BE15C009614D527D505A4091E5F5B5BEBE15C0B8FE24767E505A4083E1D4F6F5BE15C0A19B596E7F505A4018E8460C2EBF15C0DE21523A80505A40D56AB5D366BF15C038C390D980505A40AB141C2AA0BF15C0CA46B34B81505A40E0611EECD9BF15C09B45739081505A40E46E1DF613C015C01156A6A781505A4070F04D244EC015C01F263E9181505A406046CE5288C015C02584484D81505A40CE9CBC5DC2C015C07156EFDB80505A404F0D4D21FCC015C07581783D80505A4041B2DF7935C115C001030000000100000034010000C92A389776505A4016B3D16365B715C0445663D773505A404DEE17653FB715C0F06D2B3671505A408FCE514817B715C028A32FB56E505A4078733C26EDB615C0AB45FB556C505A401F07D418C1B615C0C9CF041A6A505A4082B6433B93B615C077FFAC0268505A4087F0D4A963B615C0C4FC3D1166505A4011F3DD8132B615C03A8EEA4664505A40C1B3AFE1FFB515C0B05BCDA462505A40932C83E8CBB515C0FE3FE82B61505A40D11A66B696B515C0FAA923DD5F505A409A39276C60B515C0210D4EB95E505A408E06422B29B515C04C621BC15D505A40B11ACA15F1B415C0BEB824F55C505A40E426564EB8B415C0B9D7E7555C505A40229EEAF77EB415C0FEF0C6E35B505A40371DE43545B415C03D64089F5B505A40AA9BE12B0BB415C0BE93D6875B505A406773AEFDD0B315C03ECA3F9E5B505A40BA4D2CCF96B315C02D3236E25B505A4023023DC45CB315C038DE8F535C505A400975AC0023B315C034E306F25C505A4075841AA8E9B215C03B8339BD5D505A40560FE5DDB0B215C0056AAAB45E505A40C02512C578B215C033FAC0D75F505A40E06F3A8041B215C0EA18A1E860505A40A4A2EB2215B215C0680FFB3460505A4085097C2710B215C0BE4EDBF65C505A40D66A6902F6B115C053D536CE59505A4045DA4358D9B115C0095B00BD56505A40760DB93ABAB115C05A241CC553505A401DAAF9BC98B115C0ADD75EE850505A40B36FADF374B115C04F5C8C284E505A40517AE6F44EB115C0B5C356874B505A40CDA513D826B115C0D03D5D0649505A408F19F2B5FCB015C0F3182BA746505A402C077EA8D0B015C015CE366B44505A40CAA2E2CAA2B015C0D319E15342505A401B62693973B015C0ED22746240505A406E89681142B015C0ABAE22983E505A40701431710FB015C0AB6307F63C505A40C502FC77DBAF15C09B1B247D3B505A40F016D745A6AF15C02E44612E3A505A40DF1091FB6FAF15C0CF4F8D0A39505A409072A5BA38AF15C056365C1238505A40F4D827A500AF15C00806674637505A4068F8AEDDC7AE15C044852BA736505A40E1463F878EAE15C0EFE40B3536505A40BB6335C554AE15C0F3834EF035505A40874830BB1AAE15C0DFC31DD935505A40C450FB8CE0AD15C0CAEE87EF35505A40D926785EA6AD15C08C2E7F3336505A40E3A288536CAD15C05195D9A436505A4062A9F88F32AD15C07937514337505A4004186837F9AC15C0BE56840E38505A40DCCC346DC0AC15C08C9EF50539505A40A0D6645488AC15C04A710C293A505A40B4DB900F51AC15C0874615773B505A405EC3CEC01AAC15C0B51942EF3C505A4022B19C89E5AB15C043E9AA903E505A40605CCC8AB1AB15C0B1454E5A40505A4081D36EE47EAB15C062F0114B42505A40D6B4C0B54DAB15C0AB89C36144505A40BCEB161D1EAB15C0CC4D199D46505A403EFBCB37F0AA15C057E0B2FB48505A40A2E42D22C4AA15C079251A7C4B505A402EB26CF799AA15C0BC28C41C4E505A40A9B389D171AA15C09A1012DC50505A400D7447C94BAA15C0541E52B853505A4051751AF627AA15C075B9C0AF56505A4046B91A6E06AA15C0528689C059505A407F21F645E7A915C0E63CA89E5A505A4075454F62DFA915C091D66E015B505A40C4EF9A34D8A915C0258DD5815D505A40FB4FD509AEA915C03B027F2260505A4042A7EDE385A915C0A45CCCE162505A407883A6DB5FA915C0F8DD0BBE65505A409A6974083CA915C018EE79B568505A409D5E6F801AA915C0AF3142C66B505A405C474558FBA815C004AB80EE6E505A4023282DA3DEA815C07EE4422C72505A40EB4ADB72C4A815C0FD23897D75505A40F45476D7ACA815C07AA647E078505A4085508DDF97A815C0FFE267527C505A409AB20E9885A815C04ED4C9D17F505A40C861400C76A815C05C48455C83505A4060C2B84569A815C0DB34ABEF86505A40ADCC584C5FA815C0F20FC7898A505A40A131472658A815C06C2C60288E505A40448FECD753A815C0E75B01A691505A40231B0C7252A815C06B60CCAF91505A404E6D2A0439A815C01660C1F391505A405D7239F9FEA715C0266E196592505A40515CA635C5A715C06DA08E0393505A40D00A11DD8BA715C02A3ABFCE93505A40E55ED71253A715C054E82DC694505A404C6BFFF91AA715C0EF0E42E995505A405EDB21B5E3A615C02D27483797505A405E9C5466ADA615C0352E72AF98505A40BED8152F78A615C02B24D8509A505A40BF4F373044A615C0549B781A9C505A409B18CA8911A615C0DA56390B9E505A405EDB0A5BE0A515C0E2F8E721A0505A40FB8D4EC2B0A515C07FBF3A5DA2505A40F6BEEFDC82A515C01A50D1BBA4505A40E07B3CC756A515C0BB90353CA7505A4015DC649C2CA515C0C88EDCDCA9505A40393D6A7604A515C09572279CAC505A40DF380F6EDEA415C0407F6478AF505A404660C89ABAA415C02D1ED06FB2505A4033C5AD1299A415C087F59580B5505A40D3596DEA79A415C01309D2A8B8505A4032303E355DA415C0AFE491E6BB505A4080A0D40443A415C0B4CFD537BF505A40955E57692BA415C08608929AC2505A40B383557116A415C09B07B00CC6505A402594BD2904A415C012C90F8CC9505A401386D59DF4A315C03B1C8916CD505A40ABCD33D7E7A315C014F8ECA9D0505A404573B9DDDDA315C00DD40644D4505A4012388DB7D6A315C029049EE2D7505A407DCA1769D2A315C0AA177783DB505A40AB0E01F5D0A315C07B395524DF505A40E67A2E5CD2A315C06A91FBC2E2505A403C8AC29DD6A315C071A52E5DE6505A4005451DB7DDA315C014BAB5F0E9505A40A4DFDDA3E7A315C029315C7BED505A40366DE55DF4A315C0FBE5F2FAF0505A4066A65ADD03A415C01E86516DF4505A4007C0AE1816A415C00AE657D0F7505A403950A3042BA415C0AF50EF21FB505A40AC3D519442A415C030D10B60FE505A403EB430B95CA415C00676AD8801515A40E41A226379A415C0B18CE19904515A409405788098A415C044D5C39107515A40811B02FEB9A415C00AAD7F6E0A515A40B9EC18C7DDA415C0842F512E0D515A40A5AEAAC503A515C01A4D86CF0F515A4054D848E22BA515C0D0D67F5012515A40EA95360456A515C0497EB2AF14515A404E09781182A515C09FC9A7EB16515A402451E2EEAFA515C04CFAFE0219515A4015492C80DFA515C0C1E66DF41A515A400FFCFFA710A615C0FFC5C1BE1C515A40D7BA0C4843A615C0D1ECDF601E515A40CECE194177A615C0257CC6D91F515A4066BA1973ACA615C01B008D2821515A40FBFD3DBDE2A615C061FF644C22515A40A4520BFE19A715C0947A9A4423515A40CD506E1352A715C0475B941024515A404B73D0DA8AA715C073D2D4AF24515A40B56C2D31C4A715C015A6F92125515A405EBF28F3FDA715C0CA6DBC6625515A40128C23FD37A815C045BEF27D25515A403E8A522B72A815C07A438E6725515A40C51AD459ACA815C084C99C2325515A401969C664E6A815C0273448B224515A407A8C5D2820A915C0FE64D61324515A40419BF98059A915C07310A94823515A40C9A33C4B92A915C07D813D5122515A403E7C2064CAA915C0684C2C2E21515A40F35B0CA901AA15C0BDF028E01F515A406132EAF737AA15C09B6A01681E515A402AAC3B2F6DAA15C0ADB39DC61C515A40EADB2E2EA1AA15C02634FFFC1A515A408477B2D4D3AA15C00224400C19515A40B39F890305AB15C0FFDC92F516515A408A235F9C34AB15C0B21D41BA14515A405E36D88162AB15C0293EAB5B12515A40DF89A6978EAB15C0A65647DB0F515A40F4C399C2B8AB15C0EB58A03A0D515A40EF42B0E8E0AB15C09F1C557B0A515A40832827F106AC15C0825F179F07515A40B19E89C42AAC15C0E0B9AAA704515A40A34FBF4C4CAC15C01888E39601515A4062061A756BAC15C0B8C9A56EFE505A401070622A88AC15C000F7E330FB505A403DF6E35AA2AC15C072CD9DDFF7505A40F9A977F6B9AC15C02D14DF7CF4505A40B23A8EEECEAC15C0EB58BE0AF1505A400AF13836E1AC15C049A65B8BED505A408EA831C2F0AC15C03834DF00EA505A40FFC3E188FDAC15C06B13786DE6505A408A17688207AD15C082D45AD3E2505A407AC49DA80EAD15C0D52BC034DF505A4018051AF712AD15C0825F1DB7DB505A403355185D14AD15C0432653ADDB505A40EA84F9CA2DAD15C0B7DD5F69DB505A40EDAFEAD567AD15C0326509F8DA505A40225E7F99A1AD15C07C9F9559DA505A4064A717F2DAAD15C03342668ED9505A404A9C55BC13AE15C09099F896D8505A40201633D54BAE15C0283BE573D7505A401650171A83AE15C0DBA7DF25D6505A404A3EEC68B9AE15C023DDB5ADD4505A40DA9233A0EEAE15C016D64F0CD3505A4096661B9F22AF15C052FCAE42D1505A405076924555AF15C04789ED51CF505A4080EA5B7486AF15C02CD83D3BCD505A409D9A220DB6AF15C0AF63DA91CB505A40D2344639D8AF15C0B8B4F188CE505A4070F9A64DF6AF15C0E4F7D680D1505A40E8053FCB17B015C0749E955DD4505A40D14763943BB015C02DC2691DD7505A405EEC019361B015C0D951A1BED9505A40B862ACAF89B015C0F61C9D3FDC505A4079CFA5D1B3B015C0C6D3D19EDE505A40634DF2DEDFB015C01AFBC8DAE0505A4056F466BC0DB115C04AD321F2E2505A40A099BA4D3DB115C0BA3192E3E4505A40424297756EB115C08A4CE7ADE6505A408239AC15A1B115C0C1770650E8505A40BBC3C00ED5B115C0ACD3EDC8E9505A40C35EC7400AB215C0E7EBB417EB505A40E186F18A40B215C0C7468D3BEC505A408FF1C3CB77B215C0ACE4C233ED505A400F342BE1AFB215C014AFBCFFED505A4099C690A8E8B215C003D7FC9EEE505A40A659F0FE21B315C0A4222111EF505A40E76DEDC05BB315C0E929E355EF505A401023E9CA95B315C0F781186DEF505A40F72F18F9CFB315C0A9C1715AEF505A4001D4986C00B415C0896C5BDBF1505A40BF1081B91FB415C04E2C319BF4505A40019415B845B415C007536A3CF7505A408B48B6D46DB415C039AF67BDF9505A40FF58A6F697B415C02EF09D1CFC505A40EBE5E903C4B415C0C5999658FE505A40BA0C56E1F1B415C065EBF06F00515A40FDA7A17221B515C08DB9626102515A40AAC1769A52B515C07839B92B04515A40BFA9843A85B515C052BED9CD05515A40F2A89233B9B515C09167C24607515A4030419365EEB515C006C08A9508515A4071F2B7AF24B615C03D4D64B909515A40987585F05BB615C0DC0E9BB10A515A40F962E80594B615C0AAED957D0B515A4079354ACDCCB615C0011AD71C0C515A40E89FA62306B715C06C59FC8E0C515A40EF24A1E53FB715C04443BFD30C515A40DDE59AEF79B715C0236CF5EA0C515A40C39AC81DB4B715C0168090D40C515A404DA5484CEEB715C0794B9E900C515A40D531395728B815C080B2481F0C515A40AC58CE1A62B815C06897D5800B515A40603168739BB815C061AFA6B50A515A409ACBA83DD4B815C05C4639BE09515A40FDFE89560CB915C0C5F1259B08515A407404739B43B915C07632204D07515A4027CD4DEA79B915C00006F6D405515A4091079C21AFB915C0B5678F3304515A4039C88B20E3B915C08DC1ED6902515A4012C70BC715BA15C0784D2B7900515A400027DFF546BA15C047677A62FE505A4059B9B08E76BA15C0CBCF2427FC505A40CFB32574A4BA15C073E18AC8F9505A4085CAEF89D0BA15C001B72248F7505A40ECA5DEB4FABA15C0D44477A7F4505A40F6A6F0DA22BB15C0586527E8F1505A4008F262E348BB15C026D9E40BEF505A40EBB3C0B66CBB15C0843B7314EC505A409C99F13E8EBB15C0E0EBA603E9505A400C714767ADBB15C0F5EC63DBE5505A404EEA8A1CCABB15C040BA9C9DE2505A40F071074DE4BB15C09214514CDF505A400B1C96E8FBBB15C072C68CE9DB505A40199BA7E010BC15C00C616677D8505A40DA3A4D2823BC15C07CF2FDF7D4505A40F3D940B432BC15C03FB67B6DD1505A4041DEEB7A3FBC15C09EC00EDACD505A40121F6D7449BC15C0D1A5EB3FCA505A40D2C09D9A50BC15C0D11D4BA1C6505A40E50015E954BC15C08AA56800C3505A406AED2A5D56BC15C0621E815FBF505A40F608FAF554BC15C0E36CD1C0BB505A4003D85FB450BC15C05F179526B8505A407D58FC9A49BC15C070E50493B4505A40ED6230AE3FBC15C028815508B1505A40B8F71AF432BC15C0CA1AB688AD505A401B78957423BC15C0E60F4F16AA505A4053CF2E3911BC15C0A69640B3A6505A40358D254DFCBB15C02C6EA161A3505A4094F660BDE4BB15C0BA947D23A0505A402F106998CABB15C08B04D5FA9C505A4064A85DEEADBB15C006789AE999505A40BC64ECD08EBB15C02B36B2F196505A402ADB45536DBB15C0E1E7F01494505A40E0BB118A49BB15C0EA761A5591505A402414628B23BB15C033F7E0B38E505A4072B1A56EFBBA15C00F9BE3328C505A4069AD994CD1BA15C037B3ADD389505A40602C3A3FA5BA15C0EFBAB59787505A40DB55B26177BA15C01A715C8085505A408C934BD047BA15C0AFFEEB8E83505A406E1E5CA816BA15C01A2B97C481505A407BE73408E4B915C0119F782280505A4063E40E0FB0B915C03F3692A97E505A4074CEF7DC7AB915C04660CC5A7D505A40215DBE9244B915C06B91F5367C505A40B20ADE510DB915C043C3C13E7B505A40356D6A3CD5B815C0C205CA727A505A40E932FA749CB815C0D5208CD379505A4080CC911E63B815C0DD466A6179505A40DDD48D5C29B815C020D8AA1C79505A40FF418D52EFB715C07037780579505A40A26C5B24B5B715C0BE4D211879505A405005DAB084B715C0C92A389776505A4016B3D16365B715C001030000000100000081000000DC05F4AB11505A400D761A68AFB215C03D4D81B410505A40E5D0E680E7B215C003D868910F505A405B55B6C51EB315C0332A5E430E505A403B04731455B315C06F442FCB0C505A40789E9E4B8AB315C0EF24C4290B505A40E64D674ABEB315C07A381E6009505A4076E2BBF0F0B315C0A1BB576F07505A40CA995F1F22B415C0B90CA35805505A409062FDB751B415C0E8EE491D03505A4068923A9D7FB415C0CCBEACBE00505A40D9FFC8B2ABB415C02D99413EFE4F5A40217878DDD5B415C04374939DFB4F5A4051834703FEB415C0252C41DEF84F5A40236F730B24B515C0EB82FC01F64F5A40CD9387DE47B515C02C15890AF34F5A40C9CB6B6669B515C07743BBF9EF4F5A406814728E88B515C0731177D1EC4F5A40DE4E6343A5B515C05FFBAE93E94F5A40901A8B73BFB515C098C26242E64F5A40F4BFC20ED7B515C003329EDFE24F5A404C277B06ECB515C0F4DA776DDF4F5A406FD3C54DFEB515C07FCB0FEEDB4F5A403CDB5CD90DB615C0E73E8E63D84F5A40C9DDA99F1AB615C0094922D0D44F5A4088ECCB9824B615C0807D0036D14F5A40C2669CBE2BB615C075936197CD4F5A404AC5B20C30B615C0D40681F6C94F5A402B52678031B615C0D2B79B55C64F5A4028CCD41830B615C09C89EEB6C24F5A4020F4D8D62BB615C0F400B51CBF4F5A40530414BD24B615C0BAE32789BB4F5A408A11E7CF1AB615C017DA7BFEB74F5A401B5871150EB615C03A12E07EB44F5A40C6748C95FEB515C076E77C0CB14F5A40B98DC759ECB515C08F8D72A9AD4F5A40066D616DD7B515C019C1D757AA4F5A40DA9041DDBFB515C0A77DB819A74F5A405336F0B7A5B515C09ABA14F1A34F5A400D638D0D89B515C0612FDFDFA04F5A4083F2C6EF69B515C0E21FFCE79D4F5A4042AFCD7148B515C0CF31400B9B4F5A40807C49A824B515C0974B6F4B984F5A40E7984CA9FEB415C0B77D3BAA954F5A409601468CD6B415C001F74329934F5A40ECFDF269ACB415C08D0414CA904F5A40FFDD4F5C80B415C0F31D228E8E4F5A40F9F2877E52B415C057FECE768C4F5A4001CEE4EC22B415C0DECA64858A4F5A4039CDBCC4F1B315C01B4716BB884F5A406A046124BFB315C0DA17FE18874F5A4095890A2B8BB315C0DB141EA0854F5A40CB33C7F855B315C0CDA95E51844F5A40AFD565AE1FB315C0FC468E2D834F5A400502626DE8B215C00AE26035824F5A40A064CF57B0B215C0F5866F69814F5A40B6BE449077B215C0BAF937CA804F5A402091C6393EB215C0CF681C58804F5A400A84B17704B215C09C306313804F5A40D297A46DCAB115C01EB036FC7F4F5A40B32C6B3F90B115C0CC2EA512804F5A40B1EFE61056B115C0D4D3A056804F5A4075B9F9051CB115C0AAAEFFC7804F5A40FB6C6F42E2B015C0EED07B66814F5A4057E4E7E9A8B015C09779B331824F5A40E6F7C01F70B015C042512929834F5A40ADAE000738B015C088B7444C844F5A4043A53FC200B015C02321529A854F5A4029B79373CAAF15C0B8868312874F5A4020FA7A3C95AF15C0DFE3F0B3884F5A40D415C73D61AF15C04EC6987D8A4F5A40090789972EAF15C09FEC606E8C4F5A409D58FD68FDAE15C063F416858E4F5A409BE078D0CDAE15C0221771C0904F5A40FE0A56EB9FAE15C0BAF50E1F934F5A4047C0E2D573AE15C0B7717A9F954F5A404DF04EAB49AE15C009942840984F5A40D3CE9B8521AE15C0A2807AFF9A4F5A404BC98B7DFBAD15C04B76BEDB9D4F5A40B44293AAD7AD15C027DA30D3A04F5A40851CCA22B6AD15C0374EFDE3A34F5A40AB16DEFA96AD15C031D23F0CA74F5A40340F06467AAD15C0FCED054AAA4F5A409D28F61560AD15C019E54F9BAD4F5A4083DFD47A48AD15C036F211FEB04F5A408414318333AD15C0308A3570B44F5A40FB11F93B21AD15C0B9A59AEFB74F5A40079372B011AD15C0D310197ABB4F5A40C8CF33EA04AD15C05CBF810DBF4F5A40AF931DF1FAAC15C0CD25A0A7C24F5A40526256CBF3AC15C05C953B46C64F5A40F4AB467DEFAC15C0B19A18E7C94F5A4022169609EEAC15C0485EFA87CD4F5A4053D82971EFAC15C0B505A426D14F5A409E2E24B3F3AC15C0E314DAC0D44F5A4077E2E4CCFAAC15C086CE6354D84F5A4089E90ABA04AD15C0CF920CDFDB4F5A408818777411AD15C0A13BA55EDF4F5A4043EA4FF420AD15C0597505D1E24F5A404356063033AD15C073130D34E64F5A402EB65B1C48AD15C01A60A585E94F5A4026B568AC5FAD15C0E565C2C3EC4F5A408E44A5D179AD15C0F83264ECEF4F5A400E92F17B96AD15C0B91498FDF24F5A40B0F99F99B5AD15C05CCB79F5F54F5A402AEC7F17D7AD15C081B434D2F84F5A40B1C4E9E0FAAD15C03CEC0492FB4F5A409385CBDF20AE15C0BE633833FE4F5A409474B6FC48AE15C00DED2FB400505A40898EED1E73AE15C0053B601303505A402DC8742C9FAE15C030D5524F05505A401C15210ACDAE15C0B0FEA66607505A404828A99BFCAE15C0CE8F125809505A4049E6B6C32DAF15C09BC162220B505A401A7CF96360AF15C025EB7CC40C505A40D511385D94AF15C0CD2F5F3D0E505A40550B658FC9AF15C0541E218C0F505A4017CDB1D9FFAF15C03940F4AF10505A4029F7A21A37B015C0179924A811505A40B70B25306FB015C0AA15197412505A405372A1F7A7B015C03BEA531313505A4041CD134EE1B015C03EE0728513505A407C911F101BB115C0EC922FCA13505A4088D5251A55B115C0B79A5FE113505A4096495B488FB115C073A7F4CA13505A406A4ADE76C9B115C03589FC8613505A406502CD8103B215C0D927A11513505A40D38A5B453DB215C02B69287712505A4030FFE99D76B215C0DC05F4AB11505A400D761A68AFB215C001030000000100000081000000999068D46D4F5A406030D556D6A315C0D147F3DC6C4F5A40E135946F0EA415C0B393D8B96B4F5A40462E53B445A415C0AAF9CB6B6A4F5A408D24FC027CA415C0887B9BF3684F5A40C4E5103AB1A415C088182F52674F5A40D1A9BF38E5A415C0383E8888654F5A40AB50F7DE17A515C0BF29C197634F5A40C5297B0D49A515C0D1390C81614F5A407E37F6A578A515C0BF31B3455F4F5A40E5E40D8BA6A515C01D6E16E75C4F5A40B21F74A0D2A515C0700BAC665A4F5A40F8CDF8CAFCA515C07BFFFEC5574F5A4041929AF024A615C0A825AE06554F5A4040D696F84AA615C02F3F6B2A524F5A40AF0F79CB6EA615C091E7F9324F4F5A40DD37295390A615C0167E2E224C4F5A40536CF97AAFA615C0E804EDF9484F5A40BBAFB22FCCA615C099F627BC454F5A4018C4A05FE6A615C0A812DF6A424F5A4098159DFAFDA615C0EA211E083F4F5A4031B118F212A715C077B3FB953B4F5A40563F253925A715C0F9D29716384F5A4051FD7CC434A715C01FB91A8C344F5A4067B1898A41A715C00477B3F8304F5A40CC946A834BA715C05C9D965E2D4F5A40132FF9A852A715C041E0FCBF294F5A40D321CDF656A715C06CB8211F264F5A4027E03E6A58A715C0BF02427E224F5A401E52690257A715C0EC9E9ADF1E4F5A4005622AC052A715C0230E67451B4F5A40967322A64BA715C09212E0B1174F5A40FFC4B2B841A715C097503A27144F5A40CFBBFAFD34A715C081F2A4A7104F5A40B71DD47D25A715C0AA4F48350D4F5A408139CE4113A715C0CE9744D2094F5A4059012855FEA615C06583B080064F5A40FB1AC9C4E6A615C0DA099842034F5A4069EA399FCCA615C05C1EFB19004F5A40619B9AF4AFA615C02074CC08FD4E5A40AE2E99D690A615C0CD4AF010FA4E5A40329366586FA615C0CF433B34F74E5A407DCFAA8E4BA615C053417174F44E5A407044788F25A615C0924F44D3F14E5A4037103E72FDA515C023995352EF4E5A40EF99B94FD3A515C0E8662AF3EC4E5A401F50E741A7A515C0502C3FB7EA4E5A40F2A0F26379A515C05EA0F29FE84E5A40123925D249A515C029E48EAEE64E5A409A90D5A918A515C046B746E4E44E5A40A8D35409E6A415C099BA3442E34E5A40F22EDC0FB2A415C011C25AC9E14E5A407B8E79DD7CA415C0A035A17AE04E5A4012D8FB9246A415C0F681D656DF4E5A40DFAFDE510FA415C03599AE5EDE4E5A402AD1353CD7A315C0F883C292DD4E5A40CF0A98749EA315C0FF0290F3DC4E5A404EE9091E65A315C0A4417981DC4E5A40921EE85B2BA315C05999C43CDC4E5A40B7B2D151F1A215C04D669C25DC4E5A40B00B9223B7A215C052ED0E3CDC4E5A4048DA0AF57CA215C01A530E80DC4E5A40E0F81DEA42A215C0CEA470F1DC4E5A402A4A972609A215C0ECF1EF8FDD4E5A40EAA516CECFA115C079772A5BDE4E5A402DE0F90397A115C052DCA252DF4E5A40A3F946EB5EA115C07F7EC075E04E5A40998696A627A115C05ED1CFC3E14E5A404A58FE57F1A015C064CC023CE34E5A404278FC20BCA015C0376A71DDE44E5A400E80622288A015C0C8371AA7E64E5A40795C417C55A015C022F3E297E84E5A408A86D54D24A015C07D3999AEEA4E5A40B1C073B5F49F15C03D44F3E9EC4E5A40896176D0C69F15C051B49048EF4E5A40823A2BBB9A9F15C0886BFBC8F14E5A40C122C290709F15C05173A869F44E5A40C1333C6B489F15C04CF0F828F74E5A4028BF5B63229F15C025223B05FA4E5A40B30A9590FE9E15C0196FABFCFC4E5A4034D9FF08DD9E15C0727A750D004F5A40ACCA49E1BD9E15C06345B535034F5A40F69BA92CA19E15C083597873064F5A403C4DD3FC869E15C02EFCBEC4094F5A40B637ED616F9E15C0206A7D270D4F5A409517866A5A9E15C0731A9D99104F5A40F2118C23489E15C03E08FE18144F5A40C7BB4498389E15C0190278A3174F5A40672646D22B9E15C09CFEDB361B4F5A40C6F570D9219E15C02575F5D01E4F5A407C85EBB31A9E15C0F2B98B6F224F5A405C1D1E66169E15C0D95C6310264F5A402A3AB0F2149E15C0A6893FB1294F5A4052EA865A169E15C05D69E34F2D4F5A40C040C49C1A9E15C0798313EA304F5A40AADDC7B6219E15C0561E977D344F5A40878D30A42B9E15C0EA9D3908384F5A4009FCDE5E389E15C0EFDFCB873B4F5A40297BF9DE479E15C0B89425FA3E4F5A4001DAF01A5A9E15C0BF93265D424F5A40334A86076F9E15C0432BB8AE454F5A40654FD297869E15C0FB69CEEC484F5A401AB44CBDA09E15C0376269154C4F5A40DD7FD567BD9E15C0926596264F4F5A4065E9BE85DC9E15C07838711E524F5A40013DD803FE9E15C0C93C25FB544F5A4078B279CD219F15C0D492EEBA574F5A40BF2991CC479F15C00A301B5C5A4F5A4071C7AFE96F9F15C0A5EA0BDD5C4F5A407168180C9A9F15C0B779353C5F4F5A40DAE2CE19C69F15C0F0682178614F5A400F0DA8F7F39F15C08CFF6E8F634F5A403F7E5A8923A015C0E319D480654F5A40CD0090B154A015C002F51D4B674F5A4009A9F75187A015C0DFEB31ED684F5A401C88584BBBA015C0AF250E666A4F5A409CECA47DF0A015C0EB34CAB46B4F5A4089270EC826A115C0B4A697D86C4F5A403EC718095EA115C02782C2D06D4F5A401E3EB11E96A115C063B7B19C6E4F5A40C6E540E6CEA115C0F47DE73B6F4F5A408054C33C08A215C06FA201AE6F4F5A4040F5DBFE41A215C007C3B9F26F4F5A407CD6EB087CA215C0027BE509704F5A4062A22737B6A215C0DE7C76F36F4F5A40A9B1AD65F0A215C0309B7AAF6F4F5A40BF2C9C702AA315C02AC01B3E6F4F5A40F82C273464A315C0C0D39F9F6E4F5A40F5CFAE8C9DA315C0999068D46D4F5A406030D556D6A315C001030000000100000081000000011BB1FC4A4E5A40046C6413BB9B15C00B8473314A4E5A40678B77DDF39B15C0001EF839494E5A40BFD31DF62B9C15C0F786D716484E5A40FEA1BE3A639C15C0FC47C5C8464E5A4096134489999C15C060668F50454E5A40660B30C0CE9C15C0B3E41DAF434E5A406ADAB0BE029D15C0AF3372E5414E5A40D47CB564359D15C07A93A6F43F4E5A4086610193669D15C09865EDDD3D4E5A4054AD3F2B969D15C0FD6F90A23B4E5A40C1F01510C49D15C0A811F043394E5A40D8413625F09D15C05D6982C3364E5A40D2B1704F1A9E15C0E66ED222344E5A400111C474429E15C07EFF7E63314E5A4089F96D7C689E15C0F9DD39872E4E5A40F113FA4E8C9E15C039A7C68F2B4E5A40C28E50D6AD9E15C0B0BBF97E284E5A40E9BEC3FDCC9E15C07A1EB756254E5A4089E01CB2E99E15C0DB4AF118224E5A400CF1A7E1039F15C0D100A8C71E4E5A40D7993E7C1B9F15C06F09E7641B4E5A40B2265273309F15C0D3F3C4F2174E5A406580F4B9429F15C072CB6173144E5A40E625E044529F15C088C8E5E8104E5A4048207F0A5F9F15C084FB7F550D4E5A40A1ECF002699F15C036F464BB094E5A402E570F28709F15C09465CD1C064E5A40E4467275749F15C002C7F47B024E5A40BE7472E8759F15C0CDF317DBFE4D5A40050F2B80749F15C0E1C9733CFB4D5A4064467A3D709F15C06EC843A2F74D5A40F5C40023699F15C06EAFC00EF44D5A401C0F20355F9F15C0D9201F84F04D5A4044D0F779529F15C060448E04ED4D5A40771362F9429F15C0986E3692E94D5A40266CEEBC309F15C041CC372FE64D5A404F10DCCF1B9F15C0B112A9DDE24D5A4075E8123F049F15C00036969FDF4D5A40409A1B19EA9E15C0E425FF76DC4D5A40B191166ECD9E15C0F491D665D94D5A40600EB24FAE9E15C011B6006ED64D5A405A3C1FD18C9E15C0C22F5291D34D5A40835D0607699E15C02DDD8ED1D04D5A40310C7A07439E15C06BC66830CE4D5A40E89DE9E91A9E15C0D3117FAFCB4D5A40EAAE12C7F09D15C0F4035D50C94D5A4092E0F1B8C49D15C0D10B7914C74D5A4069D1B2DA969D15C0F2DB33FDC44D5A40DF5B9F48679D15C0E190D70BC34D5A402E230E20369D15C09AE59641C14D5A40CA7B507F039D15C05F768C9FBF4D5A40D7B79F85CF9C15C07212BA26BE4D5A40D4E509539A9C15C01B1D08D8BC4D5A40000B5E08649C15C05AFE44B4BB4D5A40CEE717C72C9C15C0A0A324BCBA4D5A40A8504BB1F49B15C0E31040F0B94D5A403F2A8FE9BB9B15C03D021551B94D5A40AA13E892829B15C0749E05DFB84D5A4005CEB2D0489B15C06F3A589AB84D5A40426D8EC60E9B15C0E12D3783B84D5A40CC5F4698D49A15C035B9B099B84D5A40655BBC699A9A15C0CCFCB6DDB84D5A40013CD25E609A15C09001204FB94D5A407AE2539B269A15C0E5D2A5EDB94D5A404221E142ED9915C0C9A9E6B8BA4D5A40B3C3D778B49915C0372965B0BB4D5A405DBE3D607C9915C077AB88D3BC4D5A401496AB1B459915C048A09D21BE4D5A40490937CD0E9915C0ABFBD599BF4D5A40710B5E96D99815C0F6B4493BC14D5A40CF1CF297A59815C0F755F704C34D5A40B40D04F2729815C0C199C4F5C44D5A409637D0C3419815C0C61A7F0CC74D5A40553AAB2B129815C0D00FDD47C94D5A400647EF46E49715C066177EA6CB4D5A40BF06EA31B89715C02411EC26CE4D5A408F25CB078E9715C07A049CC7D04D5A402D8F93E2659715C03C14EF86D34D5A40FF6405DB3F9715C0837E3363D64D5A400EBA94081C9715C02FA8A55AD94D5A40301C5981FA9615C06733716BDC4D5A4041F4FF59DB9615C07420B293DF4D5A40ECC5BFA5BE9615C03AF875D1E24D5A4046564C76A49615C0A0FFBC22E64D5A40A9C1CBDB8C9615C024737B85E94D5A40DC85CCE4779615C0DEC99AF7EC4D5A4002883C9E659615C01DFFFA76F04D5A40E21B6113569615C0EAE17301F44D5A406410D04D499615C08A69D694F74D5A4021C669553F9615C0410EEE2EFB4D5A4076545430389615C06B2582CDFE4D5A4054BEF7E2339615C03640576E024E5A40113BFB6F329615C0FE8B300F064E5A40649343D8339615C08933D1AD094E5A404394F21A389615C04EC0FD470D4E5A40FC9767353F9615C0D97A7DDB104E5A403C254123499615C081C91B66144E5A4042A25FDE559615C0958CA9E5174E5A400B1CE95E659615C02777FE571B4E5A40671D4E9B779615C0A863FABA1E4E5A4072944F888C9615C071A3860C224E5A4050C20519A49615C08548974A254E5A402630E83EBE9615C0A3682C73284E5A4066A5D6E9DA9615C0FE5853842B4E5A40201A2308FA9615C0BDE1277C2E4E5A409E9D9C861B9715C09F68D558314E5A40552C9B503F9715C0F2119818344E5A40D56C0C50659715C040D7BDB9364E5A40564C816D8D9715C0FA92A73A394E5A4084723C90B79715C07F00CA993B4E5A408482419EE39715C0E0AFAED53D4E5A403622657C119815C0D3ECF4EC3F4E5A40CCBA5D0E419815C0359852DE414E5A4046EBD436729815C0A5F394A8434E5A405D9F79D7A49815C0B95EA14A454E5A4074C212D1D89815C04A0576C3464E5A404A8092030E9915C07E7E2A12484E5A400F0A2A4E449915C0225CF035494E5A4069D15D8F7B9915C0FDA9132E4A4E5A40302F1AA5B39915C0D95CFBF94A4E5A40B266C86CEC9915C0E1B029994B4E5A4031FB63C3259A15C043773C0B4C4E5A40F44790855F9A15C0BE52ED4F4C4E5A40244FAE8F999A15C014E311674C4E5A4003B2F2BDD39A15C02EDF9B504C4E5A40D2C37BEC0D9B15C0F81D990C4C4E5A40F6AA67F7479B15C0E08D339B4B4E5A403382EABA819B15C0011BB1FC4A4E5A40046C6413BB9B15C0010300000001000000ED0000003ED988A5FF4F5A40A67C68D0F39B15C075A117AEFE4F5A40EF4734E92B9C15C03D18018BFD4F5A403791022E639C15C070C0F83CFC4F5A40165ABD7C999C15C04099CCC4FA4F5A40BE64E6B3CE9C15C0389F6423F94F5A40A4DCABB2029D15C02F3DC259F74F5A40CE93FC58359D15C08BADFF68F54F5A4058CA9B87669D15C0344C4F52F34F5A40C9713420969D15C0ACD9FA16F14F5A4003E36B05C49D15C0B0AF62B8EE4F5A4038F8F31AF09D15C0F0E7FC37EC4F5A40A3829C451A9E15C054755497E94F5A40BA0E646B429E15C0713008D8E64F5A40F0EE8773689E15C0A8D7C9FBE34F5A40928093468C9E15C0AC035D04E14F5A4079A36ECEAD9E15C0F71096F3DD4F5A40A85A6BF6CC9E15C0F5FE58CBDA4F5A405A8D52ABE99E15C07A45988DD74F5A4036E16FDB039F15C05AA1533CD44F5A4041A59C761B9F15C0CAD896D9D04F5A408CC8496E309F15C04E787867CD4F5A40F2D488B5429F15C0108918E8C94F5A408AE81341529F15C04D419F5DC64F5A40E6A954075F9F15C0C4AF3BCAC24F5A400D326A00699F15C0E1622230BF4F5A400BE82D26709F15C08C0C8C91BB4F5A40A14C3774749F15C06223B4F0B74F5A40E1B1DEE7759F15C04582D74FB44F5A40ADDE3E80749F15C0FF0633B1B04F5A40179C353E709F15C0F5300217AD4F5A40AA2C6324699F15C0A5C07D83A94F5A407BAD28375F9F15C0D958DAF8A54F5A403563A57C529F15C06D224779A24F5A40EAF2B2FC429F15C06773EC069F4F5A401D8BE0C0309F15C04E7AEAA39B4F5A4026FE6CD41B9F15C086EE5752984F5A4062D23F44049F15C089C64014954F5A401A4DE11EEA9E15C0B7F4A4EB914F5A40EE7B7174CD9E15C0962B77DA8E4F5A404D429E56AE9E15C044AA9BE28B4F5A408A7298D88C9E15C0C611E705894F5A4082F7070F699E15C006441D46864F5A405917FF0F439E15C01E4DF0A4834F5A407AD6ECF21A9E15C0A857FF23814F5A4053838ED0F09D15C0B1ACD5C47E4F5A40DE74E0C2C49D15C0F1BFE9887C4F5A40EA020EE5969D15C0DD489C717A4F5A40FCC46053679D15C01E693780784F5A40581F2F2B369D15C0FEE0EDB5764F5A40A02BCA8A039D15C03A52DA13754F5A4064056B91CF9C15C0B891FE9A734F5A40F2881F5F9A9C15C08808434C724F5A40E58DB614649C15C097247628714F5A409CABABD32C9C15C05ED94B30704F5A402F9212BEF49B15C0F5305D646F4F5A40C70682F6BB9B15C0B3ED27C56E4F5A40D08DFE9F829B15C0A83C0E536E4F5A40B0D2E4DD489B15C01779560E6E4F5A409ED8D3D30E9B15C01B012BF76D4F5A40490297A5D49A15C08B1B9A0D6E4F5A40D5FE0F779A9A15C038EF95516E4F5A409AA8206C609A15C07E8BF4C26E4F5A40EBE394A8269A15C0250270616F4F5A40BE8B0C50ED9915C09392A62C704F5A400279E585B49915C014E61A24714F5A40D3B2256D7C9915C0345D3447724F5A4088D56528459915C0E26D3F95734F5A40F4BBBBD90E9915C035126E0D754F5A40CA7AA5A2D99815C07F47D8AE764F5A403EB8F4A3A59815C0689D7C78784F5A403B6FBAFD729815C0BBD440697A4F5A40602833CF419815C07B8DF27F7C4F5A401AB7B336129815C0D70348BB7E4F5A4062849651E49715C092DBE019814F5A405675293CB89715C04FF9469A834F5A4014769C118E9715C05169EF3A864F5A4041B6F0EB659715C00C533BFA884F5A40E49EE8E33F9715C0FCF878D68B4F5A402A8EF8101C9715C02CC4E4CD8E4F5A4071603889FA9615C0AB5AAADE914F5A403DD05561DB9615C069C0E506954F5A40DAB587ACBE9615C0B281A444984F5A40C12D827CA49615C08BE6E6959B4F5A4041AE6BE18C9615C04C2EA1F89E4F5A406511D3E9779615C09BD2BC6AA24F5A40BD9AA6A2659615C00DD119EAA54F5A4054FE2B17569615C0A5FA8F74A94F5A400B6DF950499615C05448F007AD4F5A40D8AAEF573F9615C0BA3306A2B04F5A40AE333532389615C046139940B44F5A40FE6F32E4339615C0E2786DE1B74F5A4061FD8E70329615C05B924682BB4F5A40360B30D8339615C0968AE720BF4F5A4064CD371A389615C0DAEA14BBC24F5A40170506343F9615C030FB954EC64F5A409F9F3921499615C01E2136D9C94F5A404A69B3DB559615C0D33BC658CD4F5A407AD4995B659615C0F0FC1DCBD04F5A4049D05D97779615C02A3D1D2ED44F5A40F7ADC0838C9615C0E7DB5335D74F5A409001F503A29615C030D7FB31D64F5A407C4E26F88A9615C06DAB9640D44F5A405C0F07D0599615C0B0AC4C76D24F5A403021B32F279615C0FE7C38D4D04F5A4006956336F39515C0A4F15B5BCF4F5A40923D2604BE9515C030749F0CCE4F5A40B4E9C9B9879515C02573D1E8CC4F5A400929CA78509515C0AFE2A5F0CB4F5A40CDA43A63189515C0AFCDB524CB4F5A404B1CB29BDF9415C05FF77E85CA4F5A40060F3545A69415C0C98D6313CA4F5A40762420836C9415C040EDA9CEC94F5A40E95C1279329415C006757CB7C94F5A402319D74AF89315C0316DE9CDC94F5A405707501CBE9315C0E3FDE211CA4F5A40F8015F11849315C0DC373F83CA4F5A4073EECF4D4A9315C0612EB821CB4F5A40D8A942F5109315C06022ECECCB4F5A402D10152BD89215C0C4BE5DE4CC4F5A40A82C4D12A09215C0C4657407CE4F5A40ACA083CD689215C00E8F7C55CF4F5A401A4DCE7E329215C08236A8CDD04F5A409D4DAB47FD9115C04A5B0F6FD24F5A405850EC48C99115C0F38EB038D44F5A400A59A2A2969115C034947129D64F5A400DFA0974659115C00A0D2040D84F5A40651178DB359115C0A537727BDA4F5A407A1347F6079115C0CEB907DADC4F5A40ACF1C4E0DB9015C0387A6A5ADF4F5A4021A521B6B19015C037870FFBE14F5A404C6B5E90899015C0530A58BAE44F5A40AFBB3D88639015C025489296E74F5A40AF0334B53F9015C0CBABFA8DEA4F5A407C2F592D1E9015C070DDBC9EED4F5A40110A5B05FF8F15C019E3F4C6F04F5A40B77C7050E28F15C0274BB004F44F5A407AB54D20C88F15C0AC5FEF55F74F5A40AD3C1985B08F15C00C62A6B8FA4F5A40D7FE618D9B8F15C0EFCDBE2AFE4F5A4060521646898F15C0E6A218AA01505A4097FE7BBA798F15C0E6B38B3405505A40DB4729F46C8F15C0C5FBE8C708505A40F005FFFA628F15C001F6FB610C505A40C9C823D55B8F15C0D9FA8B0010505A40040D0087578F15C0F89D5DA113505A407F843B13568F15C0DB0E344217505A40F672BB7A578F15C00E7AD2E01A505A40AF20A2BC5B8F15C0676AFD7A1E505A402B634FD6628F15C06F297C0E22505A40FD3B62C36C8F15C01A1E1A9925505A409E8BBB7D798F15C0EF28A81829505A405DD881FD888F15C0D7FCFD8A2C505A401E2526399B8F15C0B573FBED2F505A4092D66925B08F15C0F1DD893F33505A40A3A265B5C78F15C03A4C9D7D36505A40298591DAE18F15C09CD235A639505A40F8B5CD84FE8F15C034C460B73C505A40E09A6CA21D9015C0B7E639AF3F505A400CAE3D203F9015C00F9DEC8B42505A40AE5399E9629015C05F08B54B45505A40B4966DE8889015C0A51EE1EC47505A4012C54B05B19015C076B6D16D4A505A4059E37627DB9015C0F886FBCC4C505A407DEDF234079115C0B51BE8084F505A40E5DD9412359115C08ABB362051505A40C56D13A4649115C029429D1153505A40788718CC959115C0C5EBE8DB54505A402C5D536CC89115C03812FF7D56505A40B11B8B65FC9115C061DBDDF657505A40022BB297319215C029D89C4559505A402EF3F9E1679215C0E7936D695A505A404417E7229F9215C0B2139C615B505A40E51B6638D79215C06D458F2D5C505A40766AE0FF0F9315C0335EC9CC5C505A4089A65156499315C0F127E83E5D505A40C0455D18839315C0FF3DA5835D505A40C15E6422BD9315C09638D69A5D505A403AA19B50F79315C0F9C66C845D505A40DB68217F319415C055B876405D505A405CDE138A6B9415C043F31DCF5C505A40CC18A74DA59415C0F95BA8305C505A40D5303BA6DE9415C037A977655B505A40A2397270179515C00E28096E5A505A40BD1046894F9515C09D6EF54A59505A4046F71DCE869515C000FEEFFC57505A40FCE8E31CBD9515C09FD3C68456505A403BA11954F29515C02FEA61E354505A40B943ED52269615C0A2AAC21953505A40CF994DF9589615C06F4D032951505A40FDD9FD278A9615C0842C56124F505A4060EBA8C0B99615C0620605D74C505A40871BF4A5E79615C0BE3270784A505A407E3891BB139715C035C90DF847505A40990650E63D9715C09EBA685745505A4095042F0C669715C074DD1F9842505A407B766B148C9715C0FDEDE4BB3F505A4077AA90E7AF9715C0D2827BC43C505A409670866FD19715C050F6B7B339505A406EBB9E97F09715C0C8457E8B36505A403E61A24C0D9815C0FAE6C04D33505A4022F6DC7C279815C0A5947FFC2F505A4011B727183F9815C0F112C6992C505A409880F30F549815C05CECAA2729505A40A4C95157669815C010284EA825505A40089DFCE2759815C055FAD71D22505A40B68D5DA9829815C0FF6F778A1E505A40D4A093A28C9815C09B1561F01A505A40522978C8939815C03E9BCD5117505A40A593A216989815C0C275F8B013505A40781D6B8A999815C0507E1E1010505A402B79EC22989815C010917C710C505A404F5B04E1939815C0D12B4ED708505A40EAF152C78C9815C08E0DCC4305505A40A74539DA829815C0A5D72AB901505A40E486D61F769815C096B19939FE4F5A408F4604A0669815C01CF040C7FA4F5A40419F5164549815C093C04064F74F5A40A94FFD773F9815C09F62095DF44F5A40CCFDD3F7299815C014D56160F54F5A4040F99E03419815C00911C851F74F5A40EA77B62B729815C06D45131CF94F5A40535302CCA49815C064CC28BEFA4F5A40CEAD49C5D89815C02DCC0637FC4F5A40AFE57EF70D9915C02BD6C485FD4F5A404E5AD341449915C04A7694A9FE4F5A40DCA6CB827B9915C04EB2C1A1FF4F5A4018495498B39915C0E278B36D00505A4070A4D65FEC9915C0FEFFEB0C01505A4072574EB6259A15C08512097F01505A40BDD35E785F9A15C0E04CC4C301505A40EA2C6982999A15C06948F3DA01505A409A10A2B0D39A15C09EB587C401505A406ED927DF0D9B15C0FB648F8001505A4011B018EA479B15C07C3E340F01505A407BACA8AD819B15C0CF27BC7000505A4050E93706BB9B15C03ED988A5FF4F5A40A67C68D0F39B15C001030000000100000081000000005A9FDFF04D5A40B5E91B25578F15C09A7D6014F04D5A4064AD29EF8F8F15C0A711E41CEF4D5A40ABC7C807C88F15C0DEB4C2F9ED4D5A40E699604CFF8F15C0C8F0AFABEC4D5A400F47DB9A359015C00ECB7933EB4D5A40ACB8BAD16A9015C066460892E94D5A406F472DD09E9015C091D35CC8E74D5A4059F82176D19015C08FB291D7E54D5A4029445CA4029115C09944D9C0E34D5A40935A873C329115C02B4F7D85E14D5A40FBD74821609115C0AC30DE26DF4D5A404BDF52368C9115C0180772A6DC4D5A40828F7560B69115C04FC9C305DA4D5A40AAC7AF85DE9115C07B537246D74D5A4073313F8D049215C037672F6AD44D5A40D685AF5F289215C00BA0BE72D14D5A408804E9E6499215C0E85CF461CE4D5A4067143E0E699215C0459FB439CB4D5A40420478C2859215C0A2E0F1FBC74D5A40D2E4E2F19F9215C016DFABAAC44D5A406773588CB79215C0AC61EE47C14D5A404D104A83CC9215C05CF5CFD5BD4D5A404CB9C9C9DE9215C058A37056BA4D5A40CF029254EE9215C07DA1F8CBB64D5A40D40B0D1AFB9215C0C2FD9638B34D5A40A4675A12059315C06345809EAF4D5A400CF953370C9315C0AE28EDFFAB4D5A40CDBD9184109315C0441C195FA84D5A40DD856CF7119315C0A1F840BEA44D5A40A096FF8E109315C0CB98A11FA14D5A40F837294C0C9315C0FC7876859D4D5A403B2B8A31059315C02956F8F1994D5A40F90B8443FB9215C038CF5B67964D5A40BC9C3688EE9215C0BF08D0E7924D5A4081FF7B07DF9215C02C547D758F4D5A407BDEE3CACC9215C015DB83128C4D5A402986ADDDB79215C09D4FFAC0884D5A4042F5C04CA09215C0ACA2EC82854D5A4043E7A626869215C0C0C05A5A824D5A4095DD7F7B699215C03D5637497F4D5A40C62CFA5C4A9215C0D59B66517C4D5A404D1547DE289215C0E12BBD74794D5A40F2EC0E14059215C065E1FEB4764D5A4049616414DF9115C05CC1DD13744D5A406CDAB6F6B69115C00FEFF892714D5A408406C4D38C9115C007ACDB336F4D5A400E9888C5609115C05364FCF76C4D5A40ED3D30E7329115C094C7BBE06A4D5A401BE20455039115C085EF63EF684D5A407D365D2CD29015C063942725674D5A404E9D8A8B9F9015C0C44F2183654D5A408275C6916B9015C05DEE520A644D5A407FD91E5F369015C0FBD0A4BB624D5A4067D96214009015C03F5DE597614D5A408D3F0ED3C88F15C05B7EC89F604D5A4036E934BD908F15C01D36E7D35F4D5A40D9C26DF5578F15C09C3EBF345F4D5A404472BD9E1E8F15C0B5BCB2C25E4D5A4032BE80DCE48E15C08903087E5E4D5A4017BF56D2AA8E15C02A69E9665E4D5A40C7E60AA4708E15C0822C657D5E4D5A404EED7E75368E15C0956C6DC15E4D5A40C7AF946AFC8D15C01731D8325F4D5A40120F18A7C28D15C056845FD15F4D5A4088DCA84E898D15C0699EA19C604D5A4049E1A484508D15C082212194614D5A40900E126C188D15C04C6745B7624D5A40B8E48827E18C15C012DF5A05644D5A40A31C1FD9AA8C15C0827C937D654D5A4028A352A2758C15C0CD36071F674D5A40CEF0F4A3418C15C0C497B4E8684D5A4023CD16FE0E8C15C0A15A81D96A4D5A40D787F4CFDD8B15C0271A3BF06C4D5A40F1B5E237AE8B15C09A0D982B6F4D5A40C57C3B53808B15C021D4378A714D5A40A8784C3E548B15C01F4EA40A744D5A40004845142A8B15C0F18352AB764D5A40FAC726EF018B15C07F99A36A794D5A408E0AB3E7DB8A15C01BCEE5467C4D5A4089125E15B88A15C00288553E7F4D5A40C05C3F8E968A15C0DC6A1E4F824D5A404E400467778A15C095785C77854D5A40682EE3B25A8A15C0D73B1DB5884D5A4005D98F83408A15C06EFB60068C4D5A40CC4830E9288A15C0DFF51B698F4D5A4037E752F2138A15C063A437DB924D5A409D84E5AB018A15C08C04945A964D5A40825F2D21F28915C0BDE708E5994D5A402131C05BE58915C0B24767789D4D5A4005447E63DB8915C03C9F7A12A14D5A4030998D3ED48915C05E460AB1A44D5A40F51C56F1CF8915C002D1DA51A84D5A40DFEF7E7ECE8915C04F6FAFF2AB4D5A40A0C3ECE6CF8915C0EF4E4B91AF4D5A402C4EC129D48915C047FC722BB34D5A40A8D25B44DB8915C0E5C2EDBEB64D5A40B3C05A32E58915C02A0C8749BA4D5A4080679EEDF18915C07CBB0FC9BD4D5A402EBD4C6E018A15C00D875F3BC14D5A40D035D6AA138A15C0744C569EC44D5A400DA9FB97288A15C03760DDEFC74D5A40D141D528408A15C085D7E82DCB4D5A406873DA4E5A8A15C04FCB7856CE4D5A40D4EFEAF9768A15C0F6939A67D14D5A40239A5818968A15C0CEFC695FD44D5A40166DF296B78A15C0BD6E123CD74D5A4035511061DB8A15C03211D0FBD94D5A40AAD99F60018B15C0D0E0F09CDC4D5A40F7E0317E298B15C015BBD51DDF4D5A40BFFC08A1538B15C0635EF37CE14D5A40D9BE28AF7F8B15C0BF5DD3B8E34D5A409CBC658DAD8B15C0C20715D0E54D5A40854F761FDD8B15C01A406EC1E74D5A40B50704480E8C15C0274BAC8BE94D5A40F2C2BDE8408C15C0258BB42DEB4D5A408F5F6AE2748C15C0832E85A6EC4D5A4035FDFB14AA8C15C0DECE35F5ED4D5A40FCC1A35FE08C15C06500F818EF4D5A407115E6A0178D15C025D11711F04D5A406247AFB64F8D15C00C38FCDCF04D5A401A93687E888D15C05473277CF14D5A40FB740DD5C18D15C0115637EEF14D5A407A424197FB8D15C0CE84E532F24D5A400CF964A1358E15C0F3A0074AF24D5A406636ADCF6F8E15C0F1628F33F24D5A40584B38FEA98E15C015A38AEFF14D5A40FD5C2409E48E15C00951237EF14D5A40F485A5CC1D8F15C0005A9FDFF04D5A40B5E91B25578F15C001030000000100000011010000C581F190C14E5A40A89FE8DE127F15C03BADB7B4BE4E5A40B2B79AB1367F15C0380050BDBB4E5A40DF821839587F15C00DD48EACB84E5A40F43DB460777F15C093245884B54E5A402F0C3715947F15C0B1659E46B24E5A405ED1EC44AE7F15C0EC4F61F5AE4E5A409A1CAFDFC57F15C0CCA4AC92AB4E5A40D41EEFD6DA7F15C0D6EB9620A84E5A406EA5BE1DED7F15C0D92840A1A44E5A408913D8A8FC7F15C0688CD016A14E5A40FE55A56E098015C0471F77839D4E5A404DCD4567138015C09F6968E9994E5A40E928938C1A8015C0CB16DD4A964E5A40C63225DA1E8015C09B9610AA924E5A40C386544D208015C0DFBC3F098F4E5A40FD353CE51E8015C01B60A76A8B4E5A400254BAA21A8015C034F882D0874E5A40E26D6F88138015C0F93D0B3D844E5A402AEBBC9A098015C059CC74B2804E5A409A5AC2DFFC7F15C02AC4EE327D4E5A40F8AA595FED7F15C04A73A1C0794E5A40BD531223DB7F15C00000AD5D764E5A40706F2B36C67F15C05219280C734E5A409ACB8CA5AE7F15C04AAD1ECE6F4E5A4080F3BE7F947F15C0CAA590A56C4E5A406A39E2D4777F15C0D2AC7094694E5A40E5C3A4B6587F15C0F8F8A29C664E5A40B8A63738377F15C0B722FCBF634E5A40660C436E137F15C07B034000614E5A40BA78D96EED7E15C0EA9E205F5E4E5A409D2B6A51C57E15C03D173DDE5B4E5A40C3ACB22E9B7E15C035AD207F594E5A40FA89AF206F7E15C05BCC4143574E5A40604F8C42417E15C01624012C554E5A401BC692B0117E15C02BCEA83A534E5A404B811988E07D15C025836B70514E5A408CC671E7AD7D15C036DD63CE4F4E5A4060DAD4ED797D15C0ECA993554E4E5A40FCBE50BB447D15C03A4BE3064D4E5A40A56EB4700E7D15C0282821E34B4E5A4030A07B2FD77C15C0932D01EB4A4E5A40C81FBA199F7C15C0385F1C1F4A4E5A404ACB0652667C15C05D79F07F494E5A405D3C66FB2C7C15C04FA3DF0D494E5A4020303539F37B15C0DF3230C9484E5A40F7B7122FB97B15C00A810CB2484E5A402B41CA007F7B15C0E1CF82C8484E5A40D9813DD2447B15C0C941850C494E5A40BC574EC70A7B15C00BE2E97D494E5A40DEA6C803D17A15C0C4BE6A1C4A4E5A405E464CAB977A15C00614A6E74A4E5A40A20737E15E7A15C034881EDF4B4E5A40B4E68EC8267A15C053793B024D4E5A404171EC83EF7915C0345B49504E4E5A40ED6F6535B97915C034267AC84F4E5A40BAE177FE837915C05AD6E569514E5A40C653F5FF4F7915C067FA8A33534E5A407FA4EE591D7915C0AE524F24554E5A40B53CA02BEC7815C01F7F003B574E5A40D6CC5E93BC7815C048BC5476594E5A40B19784AE8E7815C0ACAEEBD45B4E5A402B595F99627815C0213C4F555E4E5A4037D11E6F387815C08272F4F5604E5A407300C449107815C03F7B3CB5634E5A40231E1142EA7715C03F9B7591664E5A4019547A6FC67715C0543EDC88694E5A40CA4717E8A47715C0BF0D9C996C4E5A40847A95C0857715C00111D1C16F4E5A4016892B0C697715C054D888FF724E5A406C528DDC4E7715C00CB0C350764E5A40590DE141377715C027DC75B3794E5A409952B54A227715C049DB88257D4E5A40D222F803107715C05BB0DCA4804E5A40A8EDEE78007715C00332492F844E5A40469E2FB3F37615C0245F9FC2874E5A40C5B19ABAE97615C099B7AA5C8B4E5A40405C5695E27615C0519832FB8E4E5A4082BDCA47DE7615C0764CB639924E5A4061C5E4FBDC7615C059345FCE924E5A402A8BCC0AD17615C0FBACF42C954E5A4064E599F5A47615C03EC556AD974E5A40B4294BCB7A7615C0E58BFA4D9A4E5A407E61E1A5527615C0422B410D9D4E5A4041CD1E9E2C7615C01AE978E99F4E5A407DA077CB087615C01932DEE0A24E5A40C58A0344E77515C056B09CF1A54E5A40E217701CC87515C0206CD019A94E5A408AEFF367AB7515C07BF68657AC4E5A40DFFB4238917515C07C9CC0A8AF4E5A403C7F839D797515C0DFA2710BB34E5A40381E44A6647515C0FC88837DB64E5A408DE5725F527515C06952D6FCB94E5A403B5155D4427515C070D64187BD4E5A40EF58810E367515C09014971AC14E5A407E86D7152C7515C0378DA1B4C44E5A40DF1A7EF0247515C0E09D2853C84E5A40D442DDA2207515C0B8DFF0F3CB4E5A40BB5F9C2F1F7515C00188BD94CF4E5A405364A097207515C04DC95133D34E5A409C470BDA247515C0B03472CDD64E5A40B78D3CF42B7515C02D1AE660DA4E5A40FCE6D2E1357515C064E778EBDD4E5A40EBE2AE9C427515C0B783FB6AE14E5A405DB7F61C527515C019A945DDE44E5A406B171B59647515C098383740E84E5A40E218DD45797515C0F289B991EB4E5A40D42355D6907515C046B5C0CFEE4E5A4085E7FAFBAA7515C02BD64CF8F14E5A40A150AEA6C77515C05E476B09F54E5A40737BC1C4E67515C044D63701F84E5A40669A0343087615C088EDDDDDFA4E5A40EACBCC0C2C7615C00DB6999DFD4E5A404CD70A0C527615C09E2DB93E004F5A402BC94E297A7615C08F329DBF024F5A403667DB4BA47615C0C883BA1E054F5A402271B459D07615C085B49A5A074F5A40D2A7AE37FE7615C04313DD71094F5A40E08D80C92D7715C0458337630B4F5A4012DAD3F15E7715C02E48772D0D4F5A402D8E5792917715C02FC381CF0E4F5A40DAA9D28BC57715C041C8CED40F4F5A408D332D6FEA7715C08416865B104F5A40DB3259B0B97715C07999BC26114F5A408F6E36E6807715C0E939301E124F5A402E327DCD487715C0D4584841134F5A400E16C688117715C0036D518F144F5A40AAEF263ADB7615C0CA717D07164F5A4004CD1D03A67615C01E66E4A8174F5A404C4C7C04727615C0ACDB8472194F5A40205F535E3F7615C0A79544631B4F5A407F83DF2F0E7615C0D836F1791D4F5A4001817597DE7515C098FE40B51F4F5A4084B36FB2B07515C02A94D313224F5A40E2F11B9D847515C012E03294244F5A40C018AA725A7515C0C7F2D334274F5A402E471B4D327515C047F817F4294F5A4082D431450C7515C0EF374DD02C4F5A40350C6272E87415C0F51FB0C72F4F5A40E1B6C3EAC67415C0E55B6CD8324F5A40547A04C3A77415C071F59D00364F5A4041195B0E8B7415C0ED7E523E394F5A40A1997BDE707415C0AA468A8F3C4F5A407C5A8C43597415C0889239F23F4F5A40CD1D1C4C447415C0F1E24964434F5A40610E1905327415C0733C9BE3464F5A40E5C6C879227415C03B77056E4A4F5A40395EC1B3157415C0909359014E4F5A40DA7DE3BA0B7415C09512639B514F5A40C0865595047415C05B52E939554F5A4007C67F47007415C095ECB0DA584F5A4097BD09D4FE7315C0E7167D7B5C4F5A40DE80D83B007415C03204111A604F5A40A0270E7E047415C0BE4531B4634F5A40C3560A980B7415C0AA2BA547674F5A403EDF6B85157415C0922338D26A4F5A4014711340227415C0C214BB516E4F5A405F6227C0317415C0F6B805C4714F5A40238618FC437415C0F1F0F726754F5A40B311A8E8587415C008147B78784F5A402F8CEE78707415C0DA3983B67B4F5A4060C3639E8A7415C0657D10DF7E4F5A40D4C1E748A77415C0B53830F0814F5A4006C1CC66C67415C06338FEE7844F5A40CF0FE2E4E77415C037E6A5C4874F5A4040E87FAE0B7515C01C6A63848A4F5A40562C94AD317515C0CBC084258D4F5A406F02B0CA597515C075C76AA68F4F5A40F74816ED837515C0C43B8A05924F5A4046D7CAFAAF7515C0A5AF6C41944F5A40C284A2D8DD7515C03070B158964F5A4056E9536A0D7615C0335F0E4A984F5A40DBCF88923E7615C0C7BE50149A4F5A40D64CF032717615C083EE5DB69B4F5A406B71512CA57615C0CE19342F9D4F5A40DB8B9E5EDA7615C0E4D6EA7D9E4F5A4096EC08A9107715C032B6B3A19F4F5A40282115EA477715C0ABC1DA99A04F5A40E09AAFFF7F7715C0D0EBC665A14F5A4010B241C7B87715C0116EFA04A24F5A406EFBC61DF27715C072161377A24F5A4020E0E2DF2B7815C01584CABBA24F5A40996CF6E9657815C0B452F6D2A24F5A40BE483618A07815C0C63488BCA24F5A40D2CAC046DA7815C05FFC8D78A24F5A408618B451147915C0AE923107A24F5A404D4844154E7915C02BDEB868A14F5A409D74D16D877915C08997859DA04F5A40D6B4FD37C07915C0730D15A69F4F5A401DEDC250F87915C04DD7FF829E4F5A408E6788952F7A15C02177F9349D4F5A40432B38E4657A15C0F3EACFBC9B4F5A404401541B9B7A15C0B62D6B1B9A4F5A40431D0A1ACF7A15C045A8CC51984F5A40D75A49C0017B15C0A6920E61964F5A40FB04D5EE327B15C00646634A944F5A4069195887627B15C0C37F140F924F5A4072FE776C907B15C01E9682B08F4F5A40E99CE681BC7B15C0EE9E23308D4F5A40EDD573ACE67B15C0E988828F8A4F5A40F1461ED20E7C15C019283ED0874F5A40885423DA347C15C0023608F4844F5A40246F0EAD587C15C02746A4FC814F5A40D78AC7347A7C15C088AFE6EB7E4F5A40CCBFA05C997C15C0C66BB3C37B4F5A40470B6311B67C15C0ABECFC85784F5A40E2295A41D07C15C0B9E8C234754F5A405C825FDCE77C15C0921F11D2714F5A40381CE4D3FC7C15C0F016FE5F6E4F5A40809AF91A0F7D15C0FAD0A9E06A4F5A4009355AA61E7D15C0BA7C3C56674F5A40B8AC6F6C2B7D15C08921E5C2634F5A4068355965357D15C04846D828604F5A406551F08A3C7D15C02B954E8A5C4F5A40049DCCD8407D15C0027D83E9584F5A403D86464C427D15C0BED0B348554F5A4012F078E4407D15C029661CAA514F5A40DDBF41A23C7D15C092B4F80F4E4F5A407C544188357D15C05774817C4A4F5A406BE7D89A2B7D15C01C40EBF1464F5A40A7D927E01E7D15C093386572434F5A4077EC07600F7D15C09AAB1700404F5A405F6A0824FD7C15C09BBF229D3C4F5A4080416837E87C15C0EB239D4B394F5A40A9130FA7D07C15C003C7920D364F5A4031418581B67C15C05B9303E5324F5A4057F2EAD6997C15C0AE33E2D32F4F5A409F24EEB87A7C15C070DF12DC2C4F5A40E5C3BF3A597C15C01F306AFF294F5A40EBD30771357C15C04C00AC3F274F5A4000B3D8710F7C15C0E5548A9E244F5A40037DA154E77B15C08D51A41D224F5A4009971F32BD7B15C08D3885BE1F4F5A40D06D4F24917B15C01A77A3821D4F5A40036E5C46637B15C063BE5F6B1B4F5A40124390B4337B15C0112A047A194F5A402864418C027B15C0B274C3AF174F5A40C3FCC0EBCF7A15C0963AB80D164F5A40343948F29B7A15C0F1CD6A08154F5A40F253EE0E777A15C0597AB381144F5A40F5D8C2CDA77A15C0BBD57CB6134F5A40FCA5E597E07A15C0BDF008BF124F5A4095DA9EB0187B15C0D564F09B114F5A4036C855F54F7B15C01DB6E64D104F5A40DE7EF443867B15C0A1E4B9D50E4F5A400AD2FC7ABB7B15C05CED51340D4F5A4065019D79EF7B15C0263BB06A0B4F5A40FDF5C31F227C15C0FE07EF79094F5A40BB09354E537C15C0F9AE4063074F5A40B44A9BE6827C15C05CEFEE27054F5A40F4309CCBB07C15C03E215AC9024F5A406DB8E9E0DC7C15C03E5CF848004F5A409FD6530B077D15C0D09054A8FD4E5A409C3ED9302F7D15C0A9940DE9FA4E5A40D16BB738557D15C0EC22D50CF84E5A40B0E6790B797D15C0A8D06E15F54E5A4058BC08939A7D15C055F6AE04F24E5A40091FB6BAB97D15C0FC8E79DCEE4E5A401B274B6FD67D15C0B90DC19EEB4E5A401EAD139FF07D15C04C2A854DE84E5A409634E939087E15C081A5D1EAE44E5A4091E23C311D7E15C02606BD78E14E5A404E7820782F7E15C05C4F67F9DD4E5A40854C4E033F7E15C010B1F86EDA4E5A40773F30C94B7E15C06933A0DBD64E5A40DBA4E5C1557E15C0FB5D9241D34E5A40301F48E75C7E15C097DB07A3CF4E5A405E6BEF34617E15C0E9AF8164CC4E5A402DD6EB80627E15C0E3A6D8CFCB4E5A402DA007726E7E15C0765E4271C94E5A4005C447879A7E15C0AF23DFF0C64E5A4032B1A3B1C47E15C0EDE73950C44E5A4088231AD7EC7E15C0C581F190C14E5A40A89FE8DE127F15C0010300000001000000810000009F31409B8E535A40A5BD41D946E115C0CD95DEA38D535A401F3957F27EE115C0E421D6808C535A40EB128137B6E115C0FB4FDA328B535A407014A986ECE115C08217B9BA89535A40A9BC50BE21E215C0366E5A1988535A4020E9A5BD55E215C024B9BF4F86535A404213976488E215C0E72D035F84535A403A18E793B9E215C0A624574882535A40787C402DE9E215C0285B050D80535A40E121481317E315C07E296EAE7D535A400B62AF2943E315C0B0A8072E7B535A405C8445556DE315C013CC5C8D78535A406E82087C95E315C0AE6D0CCE75535A404A133585BBE315C0644EC8F172535A409EF05559DFE315C0710A54FA6F535A40C64E52E200E415C0E10284E96C535A40EC7D7B0B20E415C0B53C3CC169535A4077AB99C13CE415C05C366F8366535A40B7BCF7F256E415C03DB41C3263535A404B3A6E8F6EE415C01B8550CF5F535A404E476D8883E415C0FC3E215D5C535A40969C05D195E415C078F5AEDD58535A40AC82F05DA5E415C025EA215355535A4080C69625B2E415C0F537A9BF51535A4003A41620BCE415C0647A79254E535A4027A24847C3E415C03771CB864A535A402F5FC396C7E415C0B7A1DAE546535A40CE48DE0BC9E415C026F6E34443535A403640B3A5C7E415C06C5C24A63F535A400C281F65C3E415C0B164D70B3C535A403A5CC14CBCE415C0D9E0357838535A408D13FA60B2E415C0AC8574ED34535A405AADE7A7A5E415C0898EC26D31535A40DEEA622996E415C07C6448FB2D535A40C318FAEE83E415C0844926982A535A40222AEB036FE415C0E608734627535A403CC91C7557E415C052AD3A0824535A40E16216513DE415C0B13D7DDF20535A406730F7A720E415C052812DCE1D535A40A2456C8B01E415C04CCC2FD61A535A4078AAA50EE0E315C0CCD458F917535A400B854A46BCE315C0F7916C3915535A40E65C6C4896E315C034251D9812535A40747E792C6EE315C064CE091710535A4038872E0B44E315C0D2EBBDB70D535A40AD2487FE17E315C05706B07B0B535A400A0DAE21EAE215C061EA406409535A40813EEC90BAE215C05DCEBA7207535A409E8C976989E215C01A8750A805535A40438900CA56E215C087CA1C0604535A408AD15FD122E215C06481218D02535A40EBCCC29FEDE115C03328473E01535A40FBE7F755B7E115C0DF3F5C1A00535A403D597A1580E115C062CE1422FF525A403F7A5D0048E115C0C8EF0956FE525A402EC437390FE115C0CB77B9B6FD525A40367A0DE3D5E015C038A48544FD525A4057113B219CE015C06BE0B4FFFC525A406B615F1762E015C0DE9971E8FC525A40D8AC45E927E015C00F26CAFEFC525A40A38DCFBAEDDF15C0ACB9B042FD525A4041D4DEAFB3DF15C02171FBB3FD525A405E663FEC79DF15C06E6A6452FE525A40862B919340DF15C053F0891DFF525A40661432C907DF15C092B6EE1400535A40074B28B0CFDE15C03F27FA3701535A40AC990C6B98DE15C0E4C0F88502535A400C14F51B62DE15C038851CFE03535A40831260E42CDE15C035787D9F05535A4093891FE5F8DD15C02E2F1A6907535A40E5CC443EC6DD15C0916FD85909535A4006C80C0F95DD15C003DD85700B535A405DBBCC7565DD15C04EB6D8AB0D535A408786DF8F37DD15C0C5A0700A10535A40BE8E93790BDD15C09581D78A12535A405A49194EE1DC15C07F64822B15535A4010787227B9DC15C06C6FD2EA17535A405F1E621E93DC15C044E215C71A535A400B3D5D4A6FDC15C0792289BE1D535A40B75A7CC14DDC15C07CD157CF20535A4075E36D982EDC15C09EED9DF723535A40096869E211DC15C08DFC683527535A40BEC323B1F7DB15C0B63EB9862A535A40C231C414E0DB15C0E6EA82E92D535A407756DA1BCBDB15C04771AF5B31535A40C44455D3B8DB15C007C51EDB34535A40A4847B46A9DB15C0DFABA86538535A40E01EE47E9CDB15C09A121EF93B535A40E0B2708492DB15C0DC654A933F535A40049B485D8BDB15C04AEEF43143535A409E20D50D87DB15C0412FE2D246535A401AC4BE9885DB15C04147D5734A535A400799EBFE86DB15C0375191124E535A4056B87E3F8BDB15C0BEC5DAAC51535A4083C8D85792DB15C09EDB784055535A40F29B99439CDB15C084E636CB58535A4039E3A2FCA8DB15C03AB3E54A5C535A409DF31B7BB8DB15C084E05CBD5F535A40459D76B5CADB15C0BF337C2063535A40021075A0DFDB15C083E82C7266535A4036CA302FF7DB15C063FA62B069535A400C8D225311DC15C01F681ED96C535A4011522BFC2DDC15C0596F6CEA6F535A40BD3C9E184DDC15C02DC068E272535A4051804B956EDC15C0E0A73EBF75535A402C358C5D92DC15C0E8312A7F78535A40EF144F5BB8DC15C0A93E79207B535A4073162677E0DC15C02C8F8CA17D535A40EAE054980ADD15C036C5D80080535A40480CE0A436DD15C02157E73C82535A40EB279D8164DD15C0D676575484535A40A17A431294DD15C067EBDE4586535A409D747D39C5DD15C0B4DC4A1088535A40DDC5FAD8F7DD15C0B39080B289535A40A11083D12BDE15C0CB197E2B8B535A40A829090361DE15C0EDF55A7A8C535A40E1DCBE4C97DE15C0009E489E8D535A400928298DCEDE15C0410593968E535A4010E134A206DF15C05608A1628F535A4011B94B693FDF15C0C9CBF40190535A40869169BF78DF15C0AB092C7490535A401D143281B2DF15C0374E00B990535A406781068BECDF15C04C2347D090535A40DFA81BB926E015C0AB2AF2B990535A40C1FB8FE760E015C0D3260F7690535A40FAAD81F29AE015C092F2C70490535A4084D724B6D4E015C03D6762668F535A409B87D90E0EE115C09F31409B8E535A40A5BD41D946E115C00103000000010000001F0100006292361BB5515A40B7AEA0AC67D115C0F41ACB23B4515A40F14D8FC59FD115C05A38B900B3515A40B646890AD7D115C0826AB4B2B1515A40C07F78590DD215C06AAE8A3AB0515A40EF9ADE9042D215C016FF2399AE515A400F9EE98F76D215C089C681CFAC515A4036308836A9D215C0053FBEDEAA515A4063617D65DAD215C008C50BC8A8515A4002EE73FE09D315C0541AB48CA6515A40E0F410E437D315C09F9A172EA4515A405E1106FA63D315C03E62ACADA1515A4046D122258ED315C07267FD0C9F515A402379654BB6D315C0D186A94D9C515A40380F0B54DCD315C06C83627199515A408FA09E2700D415C04AFBEB7996515A40CEB807B021D415C0E2501A6993515A401E0398D840D415C03A8AD14090515A405B0B188E5DD415C05F2604038D515A409718D3BE77D415C0F9E9B1B189515A403318A25A8FD415C09EA3E64E86515A40D694F552A4D415C0C7E8B8DC82515A4066B1DE9AB6D415C01ACC485D7F515A40C2221727C6D415C0D38DBED27B515A40322408EED2D415C02B47493F78515A40B461D0E7DCD415C082911DA574515A40CAD3480EE4D415C0202A740671515A406D8B085DE8D415C06F9388656D515A40F16967D1E9D415C078B497C469515A40CCC47F6AE8D415C08A77DE2566515A403DF32E29E4D415C0E168988B62515A40CFC51410DDD415C01856FEF75E515A40CAE79123D3D415C05DEF446D5B515A40692CC569C6D415C0236B9BED57515A4010C887EAB6D415C03D2D2A7B54515A40767968AFA4D415C02272111851515A4077A4A5C38FD415C04CFF67C64D515A406C62263478D415C059D939884A515A40578D720F5ED415C0E300875F47515A40AAC9A96541D415C0A936424E44515A40DB93794822D415C000C84F5641515A40D05912CB00D415C0186484793E515A40C2A41B02DDD315C0F0FAA3B93B515A402C5CA703B7D315C09AA6601839515A40052924E78ED315C07D9F599736515A40C3014FC564D315C0483C1A3834515A4009E923B838D315C01CFE18FC31515A402AE6CDDA0AD315C093A9B6E42F515A403B449649DBD215C0366D3DF32D515A404A1FD321AAD215C00F89B7A82D515A40BAE6BAE6A1D215C006AFDCD62A515A40D8766D589CD215C09EA2434327515A40B77BD46B92D215C065518BB823515A4044C9F1B185D215C022F1E23820515A406CA19E3276D215C0F0E472C61C515A4061D069F763D215C08D685B6319515A403EC7910B4FD215C0AA40B31116515A407AACFD7B37D215C01D7186D312515A40FB6635571DD215C0A6F9D4AA0F515A40C8A758AD00D215C0319A91990C515A40AEF71490E1D115C02C9FA0A109515A409DD09A12C0D115C0E6B6D6C406515A4073C791499CD115C071D0F70404515A40FECE0B4B76D115C0EF04B66301515A40189B772E4ED115C0D78BB0E2FE505A40B32C920C24D115C0E0BA7283FC505A40799057FFF7D015C032127347FA505A4049D7F221CAD015C06D551230F8505A404755AD909AD015C021B29A3EF6505A400D2FDD6869D015C028F43E74F4505A406842D3C836D015C07BC819D2F2505A401773C8CF02D015C0DA0E2D59F1505A40BD69CA9DCDCF15C0CA3A610AF0505A407BCEA75397CF15C041C484E6EE505A40AA0DDC1260CF15C04EA84BEEED505A40BCB07AFD27CF15C029FA4E22ED505A40D05A1A36EFCE15C0C8840C83EC505A40E572BFDFB5CE15C0597DE610EC505A40A78BC61D7CCE15C0B44623CCEB505A405694CE1342CE15C0FB45EDB4EB505A4078E0A2E507CE15C07FC852CBEB505A40D71425B7CDCD15C0F2FA450FEC505A405C0637AC93CD15C0F9F19C80EC505A40B798A4E859CD15C00EC4111FED505A402DAB0D9020CD15C0A5B442EAED505A40C51FD0C5E7CC15C07B70B2E1EE505A40960BF2ACAFCC15C0E55AC804F0505A40B71D0C6878CC15C0FDEBD052F1505A408448341942CC15C05B1FFECAF2505A40E3BCE8E10CCC15C02DF3676CF4505A40DF41FBE2D8CB15C04FF70C36F6505A40CDF77C3CA6CB15C01AECD226F8505A401F91AA0D75CB15C07770873DFA505A407D0FD97445CB15C0D6BEE078FC505A40530E638F17CB15C095787ED7FE505A4059A99679EBCA15C0507FEA5701515A404607A44EC1CA15C0A2DB99F803515A4033968C2899CA15C0B4B0EDB706515A405201132073CA15C01F3C349409515A4089ECAB4C4FCA15C070E1A98B0C515A40537D6FC42DCA15C09F407A9C0F515A4085BA0B9C0ECA15C0FA56C1C412515A40CFCBB7E6F1C915C093A98C0216515A40DE1F28B6D7C915C0B578DC5319515A40E081831AC0C915C072FBA4B61C515A4033235922ABC915C0AEA2CF2820515A40F1A097DA98C915C03746AA1823515A40AA58ADCC8BC915C03F3A150A20515A40C961359E8AC915C0D367606B1C515A403584C45C86C915C053D71ED118515A40934F8A437FC915C09553893D15515A40ED82E75675C915C0F689D4B211515A403E05FB9C68C915C00DAE2F330E515A407B1E9E1D59C915C0CB20C3C00A515A40D8A05FE246C915C0C41BAF5D07515A405D037EF631C915C085610A0C04515A406D72E0661AC915C0C3F3E0CD00515A40B6DA0E4200C915C02CD032A5FD505A40FBF22898E3C815C098B4F293FA505A40A849DC7AC4C815C077EB049CF7505A402B5E59FDA2C815C019213EBFF4505A40C1CA47347FC815C0A64262FFF1505A407087B93559C815C06267235EEF505A402B4D1D1931C815C0F4C420DDEC505A40CA2130F706C815C051AFE57DEA505A40AE16EEE9DAC715C0F1A4E841E8505A404541820CADC715C0DA678A2AE6505A4008FA357B7DC715C00E241539E4505A40B2695F534CC715C0F4A3BB6EE2505A40FC714FB319C715C0219398CCE0505A4054FA3EBAE5C615C00BD0AD53DF505A40CEAE3B88B0C615C003CDE304DE505A40C23A143E7AC615C0DF0009E1DC505A40790D44FD42C615C0A967D1E8DB505A401CB3DEE70AC615C0AC13D61CDB505A4034D17A20D2C515C009CF947DDA505A40EBD01CCA98C515C032CE6F0BDA505A40CC4621085FC515C06073ADC6D9505A40B82327FE24C515C02F2378AFD9505A4082BCF9CFEAC415C0842ADEC5D9505A4001B77AA1B0C415C0C0B5D109DA505A40D6E88B9676C415C054D9287BDA505A403136F9D23CC415C0A0AB9D19DB505A40787E627A03C415C01770CEE4DB505A4099A325B0CAC315C093D33DDCDC505A403BBA489792C315C0A23953FFDD505A40C37064525BC315C0B11A5B4DDF505A408EB88E0325C315C0C67287C5E0505A4036C145CCEFC215C09640F066E2505A403C505BCDBBC215C0A1149430E4505A401484E02689C215C0FAAF5821E6505A40140D12F857C215C062B20B38E8505A4081EA445F28C215C037576373EA505A401EB5D379FAC115C0DE40FFD1EC505A40B5850C64CEC115C012526952EF505A40D57F1F39A4C115C0A19416F3F1505A40280E0E137CC115C0032D68B2F4505A4036D89A0A56C115C0335AAC8EF7505A40097E3A3732C115C02F811F86FA505A40FE2005AF10C115C07C43ED96FD505A4097C3A886F1C015C003A031BF00515A4002895CD1D4C015C0851DFAFC03515A4033DBD4A0BAC015C009FE464E07515A4079803805A3C015C0727A0CB10A515A401FA5160D8EC015C07D0534230E515A400EE15DC57BC015C06E959DA211515A408D3E54396CC015C089F3202D15515A406E4690725FC015C0A0108FC018515A400716F37855C015C0D45DB35A1C515A40F283A3524EC015C0B92855F91F515A4054540A044AC015C00DFA389A23515A404F81CF8F48C015C01FF6213B27515A406297D8F649C015C00F3ED3D92A515A40F82748384EC015C01C5111742E515A40EA517E5155C015C00A6DA30732515A4021601A3E5FC015C0E2EC549235515A40477CFDF76BC015C028A5F61139515A4087754E777BC015C0A73C60843C515A4018977EB28DC015C01A8171E73F515A404F8D4F9EA2C015C0BBB6133943515A40E454DA2DBAC015C009E23A7746515A40722F9752D4C015C0ED0AE79F49515A405E9966FCF0C015C06B7825B14C515A40A63B9B1910C115C03BE411A94F515A4023D2049731C115C067A5D78552515A400301FC5F55C115C057D1B24555515A4058116F5E7BC115C07F52F1E657515A403E8DEF7AA3C115C017F4F3675A515A403FB3C09CCDC115C02A622FC75C515A4011B7E6A9F9C115C0651D2D035F515A4064C8368727C215C012628C1A61515A402CD3671857C215C0A201030C63515A40DBF1234088C215C0552E5ED664515A40E5831AE0BAC215C07738837866515A407EE012D9EEC215C0B23C70F167515A40FC96FF0A24C315C027C33C4069515A40B43312555AC315C0D04E1A646A515A40C47ACF9591C315C0D9DC545C6B515A40960E24ABC9C315C0AF5353286C515A40FF72797202C415C075E197C76C515A408C62CBC83BC415C09F49C0396D515A407466BD8A75C415C09021867E6D515A4051A5B094AFC415C012FCBE956D515A404BDBD9C2E9C415C086835C7F6D515A40E46C57F123C515C0C6826C3B6D515A400C8847FC5DC515C0A4DC18CA6C515A406445DEBF97C515C02A72A72B6C515A4089BB7B18D1C515C07AF779606B515A40F2F7C1E209C615C0A2B70D696A515A40D2CEAAFB41C615C05447FB4569515A405C749D4079C615C0D926F6F767515A40D5D3838FAFC615C06253CC7F66515A408794DFC6E4C615C006C865DE64515A40ABC2DEC518C715C0AFEEC31463515A40A50C706C4BC715C06B01012461515A40AC8A569B7CC715C0555C4F0D5F515A4041023D34ACC715C0B1C0F8D15C515A402D9CC819DAC715C08D895D735A515A4090FEAA2F06C815C075D2F3F257515A40D2C2B35A30C815C0BD90465255515A40DE39E18058C815C0EB9FF49252515A401A7770897EC815C0DFC1AFB64F515A405D95EC5CA2C815C04E933BBF4C515A40DD2E3DE5C3C815C03C756CAE49515A40EBFDB30DE3C815C01C6C268646515A402C9E19C3FFC815C04CF55B4843515A400B67B9F319C915C0A1D30CF73F515A40CB566C8F31C915C0CBD344943C515A407909A38746C915C03C891A2239515A40C5B36ECF58C915C07518403236515A4081895FDD65C915C05816D54039515A402985D00B67C915C000E189DF3C515A40094B364D6BC915C0147ACB7940515A4044A3626672C915C02E1D610D44515A40CEDEF4527CC915C02E23169847515A40652DCE0C89C915C06A5EBB174B515A403E64158C98C915C08773288A4E515A409AD43BC7AAC915C0162E3DED51515A40CF3003B3BFC915C032D0E23E55515A407F7B8442D7C915C0405C0D7D58515A402BFC3767F1C915C012D8BCA55B515A400035FE100ECA15C0A288FEB65E515A40B6D4292E2DCA15C0A425EEAE61515A40B49C8AAB4ECA15C02D04B78B64515A40A836797472CA15C0B637954B67515A40F3F0E37298CA15C0D9A8D6EC69515A40DE5A5C8FC0CA15C0FC20DC6D6C515A4001B825B1EACA15C06B4A1ACD6E515A40E14044BE16CB15C024A41A0971515A40D8298D9B44CB15C0D3687C2073515A405363B72C74CB15C05C68F51175515A40000C6D54A5CB15C0214E7B5C75515A40E1EB828FADCB15C0FB2B542E78515A40B9D5BB1DB3CB15C0ECD4EAC17B515A40DBFB370ABDCB15C0D8EFA04C7F515A406C5AFBC3C9CB15C06B4E47CC82515A402DD42C43D9CB15C09894B53E86515A40BAC73D7EEBCB15C0358DCBA189515A40A9F4EF6900CC15C0987972F38C515A40AB6A5CF917CC15C05B5B9E3190515A40117EFB1D32CC15C07E374F5A93515A409DBDADC74ECC15C02252926B96515A4057E4C5E46DCC15C01E62836399515A40AEBF13628FCC15C0A1BB4D409C515A40F404F02AB3CC15C03D712D009F515A40DA0D4929D9CC15C09B6A70A1A1515A409674B04501CD15C034707722A4515A403E8769672BCD15C05B2BB781A6515A406888787457CD15C01B1AB9BDA8515A4004B6B25185CD15C023761CD5AA515A409E09CFE2B4CD15C05F0E97C6AC515A4074AA770AE6CD15C09E12F690AE515A4018045CAA18CE15C0CAD01E33B0515A40097943A34CCE15C046630FACB1515A401DA320D581CE15C00150DFFAB2515A405018251FB8CE15C0DA17C01EB4515A408DA5D55FEFCE15C0FDB5FD16B5515A4028F51E7527CF15C0F50EFFE2B5515A40FB916A3C60CF15C01A4F4682B6515A40A83CB49299CF15C0363871F4B6515A408F839F54D3CF15C01F5E3939B7515A4085918D5E0DD015C033527450B7515A40EC25B38C47D015C084BD133AB7515A4093A72EBB81D015C0BD6925F6B6515A40BA451EC6BBD015C0AC38D384B6515A405719B689F5D015C06D0A63E6B5515A40633856E22ED115C06292361BB5515A40B7AEA0AC67D115C0010300000001000000810000009DA91FC87D525A4088FB529ED7B515C04DB2F9FC7C525A402BC1AB6810B615C0A03195057C525A4071F2AB8148B615C081B78AE27A525A4056B5BAC67FB615C053BF8D9479525A40F1E3C115B6B615C03D416C1C78525A408111434DEBB615C032330E7B76525A4052336C4C1FB715C0E1F974B174525A4011DE2BF351B715C003CABAC072525A407F0D452283B715C04FFA11AA70525A40FF6762BBB2B715C09446C46E6E525A409CF428A1E0B715C0610432106C525A403D354AB70CB815C0B949D18F69525A409D9C95E236B815C062062DEF66525A40A15209095FB815C05510E42F64525A406A3FE21185B815C0E423A85361525A407550ABE5A8B815C03ED83C5C5E525A4081F04B6ECAB815C0E788764B5B525A408AA81597E9B815C0E234392358525A4016E1D04C06B915C0295477E554525A40C1BCC87D20B915C044A4309451525A407403D61938B915C0A7EC70314E525A40721969124DB915C0A7BB4EBF4A525A4064FA925A5FB915C0C51CEA3F47525A4036330DE76EB915C025496BB543525A4092D640AE7BB915C0F052012240525A4053674CA885B915C086CCE0873C525A4063B408CF8CB915C0466C42E938525A40CCA40C1E91B915C0C7AD614835525A40B8EFAF9292B915C05F717BA731525A4049C00C2C91B915C0CA9ACC082E525A40694300EB8CB915C0D4AF906E2A525A405B1F2AD285B915C0D67700DB26525A404BD5EAE57BB915C0E69C505023525A40A10E612C6FB915C0924FB0D01F525A4046D665AD5FB915C0F8ED475E1C525A4005C287724DB915C01AAF37FB18525A40420D058738B915C0325396A915525A40A6A9C4F720B915C0E0D96F6B12525A40474A4ED306B915C0003FC4420F525A40776DC129EAB815C0DD3E86310C525A40956ACB0CCBB815C099229A3909525A407A8B9C8FA9B815C07F95D45C06525A406F36DCC685B815C0F683F99C03525A4041319CC85FB815C0C404BBFB00525A408A044BAC37B815C0594DB87AFE515A40C387A58A0DB815C0BCB17C1BFC515A4006A0A77DE1B715C0BAB07EDFF9515A40AD387CA0B3B715C0F30C1FC8F7515A4071826C0F84B715C04BF3A7D6F5515A40A980CEE752B715C04D2F4C0CF4515A4033F2F24720B715C0F86D266AF2515A402A9E124FECB615C06E8F38F1F0515A40FE123B1DB7B615C0ED076BA2EF515A401CE13AD380B615C07C508C7EEE515A40A25F8D9249B615C092675086ED515A407005467D11B615C0256250BAEC515A40AC65FBB5D8B515C0400D0A1BEC515A4004DAB15F9FB515C079A0DFA8EB515A408DEAC59D65B515C062811764EB515A40A37ED6932BB515C02718DC4CEB515A40ACE4AE65F1B415C075B53B63EB515A4010BF3037B7B415C0A38928A7EB515A4011E33D2C7DB415C047AD7818EC515A408C37A26843B415C0153BE6B6EC515A409CA1FD0F0AB415C0FE7A0F82ED515A40E70BAE45D1B315C07D1E7779EE515A40D496B92C99B315C0ED8D849CEF515A407AFFB8E761B315C0A04684EAF0515A40D448C2982BB315C0A549A862F2515A4007B75361F6B215C0D69A0804F4515A40E9263F62C2B215C0ECCFA3CDF5515A4012D195BB8FB215C04EAF5FBEF7515A40B582948C5EB215C01ADE09D5F9515A40905A90F32EB215C0209D5810FC515A407713E40D01B215C04194EB6EFE515A40C2EADDF7D4B115C0B8AB4CEF00525A40E82AAECCAAB115C0DCF2F08F03525A40D56756A682B115C0AA93394F06525A407D74999D5CB115C0A3D2742B09525A40751EECC938B115C0451ADF220C525A4095B6664117B115C08A11A4330F525A40CC70B718F8B015C0C0BCDF5B12525A405DA31563DBB015C006A89F9915525A4006ED3532C1B015C0A71AE4EA18525A40524A3F96A9B015C0B452A14D1C525A402F1FC19D94B015C001C8C0BF1F525A405E3CAA5582B015C0CB75223F23525A4026E640C972B015C02F2A9EC926525A4036E01B0266B015C0B5DA045D2A525A40AF831C085CB015C00FFD21F72D525A408EE369E154B015C039E3BC9531525A40EE006D9250B015C0301A9A3635525A404713CE1D4FB015C052CA7CD738525A40ABE4728450B015C0A01828763C525A4031447EC554B015C00488601040525A40518E50DE5BB015C0BD59EDA343525A40614B89CA65B015C014EC992E47525A401DE2098472B015C0971637AE4A525A40415EF90282B015C0DF829C204E525A40F946C93D94B015C03801AA8351525A40C6833B29A9B015C031D848D554525A40A04B69B8C0B015C05D0E6D1358525A404D19CBDCDAB015C077AD163C5B525A4036A14186F7B015C018FE524D5E525A4007C31FA316B115C043BB3D4561525A40C76F352038B115C0103D022264525A404C7FDBE85BB115C0AE99DCE166525A408F6C00E781B115C010BC1A8369525A40C0F13503AAB115C0AE6F1D046C525A40977BBF24D4B115C08A6059636E525A40DF69A13100B215C0030F589F70525A403716B10E2EB215C0D0B6B8B672525A404794A59F5DB215C08A2831A874525A40CF2329C78EB215C057958E7276525A402847EB66C1B215C01F4CB61478525A40DD75B35FF5B215C0ED67A68D79525A40095D74912AB315C0FD6E76DC7A525A4014A45FDB60B315C022E257007C525A406A27FA1B98B315C023BC96F87C525A40039F3031D0B315C0CCE099C47D525A405AA16CF808B415C0607BE3637E525A40C7F8A94E42B415C0384C11D67E525A40503B8C107CB415C065E5DC1A7F525A407099741AB6B415C027D61B327F525A4026D69748F0B415C020C5BF1B7F525A40CB5914772AB515C03979D6D77E525A402353088264B515C026D189667E525A4098D8A7459EB515C09DA91FC87D525A4088FB529ED7B515C001030000000100000081000000FE2ACBF66A525A40032AF98951A715C07F7467FF69525A405C55F8A289A715C0C10A5EDC68525A40877D05E8C0A715C07B68628E67525A409D7D0A37F7A715C00785421666525A4042EA886E2CA815C05955E67464525A4080BAAE6D60A815C0FD3C4FAB62525A4018856A1493A815C05D6F97BA60525A4043487F43C4A815C0B841F1A35E525A402AAD97DCF3A815C03E6EA6685C525A40F9BD58C221A915C0BA48170A5A525A40040074D84DA915C043E5B98957525A40CEE9B80378A915C0913119E954525A404BA7252AA0A915C06901D42952525A40FC24F732C6A915C0CB0E9C4D4F525A400555B806EAA915C070EE34564C525A4013A7508F0BAA15C04BF9724549525A4055A911B82AAA15C0AE2B3A1D46525A40BDC9C36D47AA15C0C8FA7CDF42525A409230B29E61AA15C03C213B8E3F525A40ABABB53A79AA15C08163802B3C525A405AA53E338EAA15C0D84C63B938525A40971F5E7BA0AA15C09BE5033A35525A40C4ADCD07B0AA15C0B4638AAF31525A402A69F6CEBCAA15C003D6251C2E525A406DDBF6C8C6AA15C090CB0A822A525A4053DAA7EFCDAA15C056F771E326525A40EA53A03ED2AA15C07DD1964223525A40700638B3D3AA15C0E636B6A11F525A403A24894CD2AA15C0D2070D031C525A405FE1700BCEAA15C08EC6D66818525A4070EB8EF2C6AA15C0F2364CD514525A40D7CA4306BDAA15C095FFA14A11525A405030AE4CB0AA15C0874D07CB0D525A40052EA7CDA0AA15C0727BA4580A525A40FF60BD928EAA15C0E5BC99F506525A40D50B2FA779AA15C0B5CEFDA303525A405127E31762AA15C029ADDC6500525A40986D61F347AA15C0CE50363DFD515A40F163C9492BAA15C0B072FD2BFA515A408F68C82C0CAA15C0C9581634F7515A4001CC8EAFEAA915C04BAB5557F4515A4022FBC3E6C6A915C099537F97F1515A4023C279E8A0A915C0916545F6EE515A40DAAF1ECC78A915C0D1134775EC515A40C6A16FAA4EA915C0A8AF0F16EA515A40D982689D22A915C04CB515DAE7515A40094434C0F4A815C0DFE4B9C2E5515A40721B1C2FC5A815C0EC6846D1E3515A408F11760794A815C0C30AEE06E2515A401EEA926761A815C04B75CB64E0515A40DD70AB6E2DA815C0B386E0EBDE515A409238CD3CF8A715C06BB1159DDD515A40B9D5C6F2C1A715C0D16C3979DC515A4035A313B28AA715C0DCB5FF80DB515A40601BC79C52A715C02AA001B5DA515A407BD477D519A715C094F7BC15DA515A40142B2A7FE0A615C0ABF293A3D9515A40B9A93ABDA6A615C024F6CC5ED9515A40F83948B36CA615C07E699247D9515A400B2C1E8532A615C0DC9CF25DD9515A40DC239E56F8A515C03CC0DFA1D9515A40D5F7A94BBEA515C007EC2F13DA515A409C8F0D8884A515C0EA3A9DB1DA515A40C8D0682F4BA515C004F5C57CDB515A401DA6196512A515C023CC2C74DC515A40C02F264CDAA415C01F293997DD515A40332A2707A3A415C0F98937E5DE515A40819732B86CA415C096F0595DE0515A4089BAC68037A415C0CC61B8FEE1515A407F6EB58103A415C0837451C8E3515A4004EA0FDBD0A315C06EF00AB9E5515A4001F812AC9FA315C02B7CB2CFE7515A408DB4131370A315C0285AFE0AEA515A408CD76C2D42A315C00E348E69EC515A400C9B6C1716A315C004F4EBE9EE515A40ED4543ECEBA215C072AB8C8AF1515A403C68F2C5C3A215C08686D149F4515A40BFD03CBD9DA215C015CC0826F7515A40894897E979A215C00FE96E1DFA515A40BD1B1A6158A215C000872F2EFD515A404479733839A215C0E7AC665600525A4020B2DA821CA215C0A7E9219403525A408C5F045202A215C06E8761E506525A405D7817B6EAA115C048C719480A525A408A5AA3BDD5A115C0182434BA0D525A40B4D09675C3A115C03C9C903911525A40C81838E9B3A115C0060107C414525A40F9EF1D22A7A115C0444B685718525A40B9A829289DA115C0F9F37FF11B525A403D4F820196A115C0825015901F525A40B1DD90B291A115C040F1EC3023525A408284FD3D90A115C00202CAD126525A40A306AEA491A115C042AB6F702A525A40F62BC5E595A115C05F73A20A2E525A40B349A3FE9CA115C0139F299E31525A40E1E0E7EAA6A115C02290D02835525A40E95074A4B3A115C08F2168A838525A40359E6F23C3A115C06600C81A3C525A40A2484B5ED5A115C05E00D07D3F525A406630C949EAA115C0666B69CF42525A403A8502D901A215C0694B880D46525A40C2BA6FFD1BA215C06BAD2C3649525A40497EF1A638A215C03CDD63474C525A4084A8DAC357A215C00C99493F4F525A409D23FB4079A215C0063C091C52525A40B1C0AB099DA215C056DFDEDB54525A4023F4DA07C3A215C0DF70187D57525A40C3711A24EBA215C0E5BE16FE59525A400CA0AD4515A315C021784E5D5C525A40C5D8985241A315C08C1F49995E525A40C16FB12F6FA315C05AF3A5B060525A401573AEC09EA315C080C61AA262525A40311D3AE8CFA315C061CC746C64525A405CEB038802A415C0FE55990E66525A405A50D38036A415C05B80868767525A40BEF49AB26BA415C083D353D668525A40BB7B8CFCA1A415C0F8D132FA69525A40D6BD2C3DD9A415C005786FF26A525A406C6F685211A515C0D4AA70BE6B525A40B823A9194AA515C0DD96B85D6C525A401FA2EA6F83A515C084FDE4CF6C525A40107ED031BDA515C0BD71AF146D525A40C3E5BB3BF7A515C07D83ED2B6D525A405A9AE16931A615C0F4D990156D525A40A00260986BA615C0693CA7D16C525A402C4C55A3A5A615C0C5895A606C525A409A8CF566DFA615C0C89EF0C16B525A40D7D4A0BF18A715C0FE2ACBF66A525A40032AF98951A715C001030000000100000081000000C2D723BBFA535A40037D1D40FA8B15C08FACCBC3F9535A4067EE3D59328C15C02D31CEA0F8535A40632F739E698C15C0FDD8DE52F7535A40A002A7ED9F8C15C0C293CBDAF5535A4020E05A25D58C15C0AA4E7C39F4535A40389EBC24098D15C04865F26FF2535A40F6AEBACB3B8D15C0E202487FF0535A40E8E717FB6C8D15C07274AF68EE535A40C6C57E949C8D15C0BE6B722DEC535A408722947ACA8D15C00A34F1CEE9535A40AF4F0991F68D15C0D7D8A14EE7535A40768CADBC208E15C02F3F0FAEE4535A402FCA7EE3488E15C02132D8EEE1535A4076B7B9EC6E8E15C0F262AE12DF535A408305E9C0928E15C09D5D551BDC535A402DE0F349B48E15C05D72A10AD9535A40048F2B73D38E15C0D69476E2D5535A40D6365829F08E15C09A31C7A4D2535A404FB4C45A0A8F15C0C2FA9253CF535A40768749F7218F15C058ACE5F0CB535A40D1CA56F0368F15C04CC9D57EC8535A40A52EFD38498F15C0D15183FFC4535A4001F3F5C5588F15C0CD731675C1535A4070DCA98D658F15C05436BEE1BD535A40911E37886F8F15C0CD20AF47BA535A402A3876AF768F15C0CFDE21A9B6535A406EBFFDFE7A8F15C05BE15108B3535A402F1A25747C8F15C06BFE7B67AF535A40E521060E7B8F15C0A10FDDC8AB535A40B2B17DCD768F15C0F490B02EA8535A402A1E2BB56F8F15C033402F9BA4535A400B976EC9658F15C03EBE8D10A1535A40DA746610598F15C0C732FB909D535A403D72EB91498F15C06CF39F1E9A535A409AD58B57378F15C0122F9CBB96535A40148C856C228F15C03E9E066A93535A40483ABFDD0A8F15C04A39EB2B90535A40B647C0B9F08E15C03AF549038D535A40BEE8A710D48E15C0FB8715F289535A40A32C23F4B48E15C0C43432FA86535A4013176277938E15C07BA1741D84535A4065CA0BAF6F8E15C09AB5A05D81535A40C2CA31B1498E15C0838368BC7E535A4099614295218E15C0C53C6B3B7C535A40E829FA73F78D15C0123234DC79535A4013CF5467CB8D15C069DF39A077535A40AE057D8A9D8D15C02C05DD8875535A40BBCABBF96D8D15C08BCE679773535A4018F166D23C8D15C0ED050DCD71535A40620ACF320A8D15C0BD57E72A70535A40F9B32C3AD68C15C017A4F8B16E535A4005568D08A18C15C0C65F29636D535A40505EBFBE6A8C15C0E604483F6C535A400D053E7E338C15C09B9308476B535A40EEA51C69FB8B15C00E23047B6A535A40C2BCF1A1C28B15C00B83B8DB69535A40CD8FC14B898B15C072EE876969535A409997E8894F8B15C0A8CEB82469535A4009B00580158B15C03590750D69535A40F51FE451DB8A15C09C88CC2369535A4047866523A18A15C094EDAF6769535A40C7B86B18678A15C088DDF5D869535A40D0A2C2542D8A15C07B7958776A535A4015320AFCF38915C0241076426B535A40BC5DA031BB8915C0345AD1396C535A40A7568B18838915C0A6C7D15C6D535A4049EE63D34B8915C0D6DDC3AA6E535A40E43F4084158915C03EA6D92270535A40A1AB9E4CE08815C07E2D2BC471535A40142E514DAC8815C07212B78D73535A40442369A6798815C0F124637E75535A40547F2377488815C0D713FD9477535A406D8BD5DD188815C0F9293BD079535A402A30DAF7EA8715C07A19BD2E7C535A40E5DB7FE1BE8715C017D50CAF7E535A40390DF7B5948715C0D6769F4F81535A40388F418F6C8715C09233D60E84535A40D06E2286468715C0D05AFFEA86535A404BB60EB2228715C0306257E289535A40CBF51E29018715C0ECFB09F38C535A40ECA20100E28615C09D37331B90535A40E957EE49C58615C0B9ACE05893535A4088F99918AB8615C0EAAD12AA96535A404FCC2B7C938615C09784BD0C9A535A40E37D33837E8615C0E5B3CA7E9D535A404F2AA03A6C8615C04C421AFEA0535A408562B8AD5C8615C010098488A4535A401D3813E64F8615C0C108D91BA8535A40185392EB458615C0F3C1E4B5AB535A4039165DC43E8615C057916E54AF535A40F8D2DC743A8615C06C0E3BF5B2535A409F11BAFF388615C0DB6B0D96B6535A4059EDDA653A8615C0B1D8A834BA535A40628662A63E8615C09DE1D1CEBD535A40368AB1BE458615C057D14F62C1535A40DCD167AA4F8615C0510FEEECC4535A403A1467635C8615C0EC7B7D6CC8535A408AACD6E16B8615C036C9D5DECB535A408970281C7E8615C090CFD641CF535A4038951E07938615C038DD6993D2535A40CB9DD295AA8615C0030083D1D5535A40D14FBDB9C48615C0804822FAD8535A40DAA8BF62E18615C0A805550BDC535A40F3CF2C7F008715C068F83603DF535A408AFBD4FB218715C0437EF3DFE1535A40BE4611C4458715C056B2C69FE4535A407C6DD0C16B8715C00584FE40E7535A408668A4DD938715C0ACC2FBC1E9535A4085E0D0FEBD8715C0B01D3321EC535A40776E5A0BEA8715C04A182E5DEE535A4057A216E8178815C07DF08B74F0535A401EC3BC78478815C0A2780266F2535A40CC40F79F788815C016E35E30F4535A40B3CA753FAB8815C0667F86D2F5535A4004020038DF8815C0B368774BF7535A4007BA8869148915C0C224499AF8535A40CDBC41B34A8915C05E332DBEF9535A40D105B0F3818915C0BE8D6FB6FA535A405D68C008BA8915C089157782FB535A408492DCCFF28915C054F3C521FC535A405D6200262C8A15C044E4F993FC535A40D47DCFE7658A15C0A876CCD8FC535A406121ABF19F8A15C0793513F0FC535A400D18C81FDA8A15C092C2BFD9FC535A404ACE444E148B15C08FDFDF95FC535A40F6723F594E8B15C05C659D24FC535A40A218EC1C888B15C0712A3E86FB535A40D6C8AA75C18B15C0C2D723BBFA535A40037D1D40FA8B15C001030000000100000081000000D3834B2AEB515A401FE66B98B98915C05840E732EA515A40B77D61B1F18915C06FDCDD0FE9515A40DD3D62F6288A15C0D4D2E2C1E7515A40560958455F8A15C0841AC449E6515A402F7EC47C948A15C0C0A769A8E4515A40919ED57BC88A15C007DDD4DEE2515A40150E7A22FB8A15C055EC1FEEE0515A406DD974512C8B15C02F297DD7DE515A40DDB970EA5B8B15C0A84B369CDC515A4042CB12D0898B15C01CA5AB3DDA515A402EA60CE6B58B15C0E14653BDD7515A40DBD52D11E08B15C0931BB81CD5515A40699C7437088C15C095F3785DD2515A40E8FD1D402E8C15C029854781CF515A405B05B513528C15C00761E789CC515A409D3C219C738C15C0D2DB2C79C9515A402F4DB4C4928C15C043EDFB50C6515A4088C1367AAF8C15C0B0054713C3515A407CDFF3AAC98C15C09CDA0DC2BF515A406B93C446E18C15C0232B5C5FBC515A402367193FF68C15C0EC7C48EDB8515A40EF7C0387088D15C082D2F26DB5515A403B893C13188D15C0C95B83E3B1515A4019C72DDA248D15C06C212950AE515A407EE2F5D32E8D15C013AC18B6AA515A4014D46DFA358D15C02BA88A17A7515A4032AD2C493A8D15C02F87BA76A3515A40BB4F8ABD3B8D15C02F1FE5D59F515A40E111A1563A8D15C07F4947379C515A40D24B4E15368D15C067811C9D98515A403ECF31FC2E8D15C0A8839D0995515A40B948AC0F258D15C0B1EFFE7E91515A40FF8CDC55188D15C062EB6FFF8D515A401FD29BD6088D15C029CA188D8A515A40B1D8789BF68C15C05DB8192A87515A409206B2AFE18C15C09D6B89D883515A4059772E20CA8C15C0FDD8739A80515A406B0776FBAF8C15C0E5F1D8717D515A40C25DA851938C15C05168AB607A515A4090F97234748C15C0367BCF6877515A409A4B06B7528C15C0E3CB198C74515A4026E009EE2E8C15C0EE3C4ECC71515A40D8A18FEF088C15C08EDB1E2B6F515A40073D06D3E08B15C0DDD32AAA6C515A40A1AB2AB1B68B15C0D470FD4A6A515A40E9F3F8A38A8B15C078280D0F68515A40F2209CC65C8B15C0F4B4BAF765515A40B8815D352D8B15C00B3B500664515A404A36930DFC8A15C0807E003C62515A4096188E6DC98A15C0E924E69960515A4025098774958A15C0620703215F515A4013AE8B42608A15C08C933FD25D515A40A8AD6AF8298A15C0393C6AAE5C515A400E739FB7F28915C01FFA36B65B515A4049873DA2BA8915C0E2DC3EEA5A515A40AF8DDBDA818915C0B1ACFF4A5A515A402FEE7D84488915C0C19CDBD859515A40153D81C20E8915C0BF0E199459515A40F36B84B8D48815C06D67E27C59515A4050D1528A9A8815C08EF4459359515A40AB15CE5B608815C017E435D759515A404412D850268815C0B74C88485A515A40D3AF3C8DEC8715C0C347F7E65A515A4044D39B34B38715C0511C21B25B515A40EE64536A7A8715C0897B88A95C515A40CE806951428715C0F5CD94CC5D515A4080DD760C0B8715C09F91921A5F515A40727591BDD48615C0CEC8B39260515A402E8237869F8615C01D79103462515A40EBD33A876B8615C0893AA7FD63515A40A794ACE0388615C038D65DEE65515A40FF80C9B1078615C08FF4010568515A4032A5E618D88515C01DDA49406A515A40B8A75E33AA8515C0FF32D59E6C515A40B4AF7F1D7E8515C028EC2D1F6F515A40A1EF79F2538515C0181AC9BF71515A40BBE14ECC2B8515C06BEC077F74515A409A3DC1C3058515C0ACAD385B77515A40D7B345F0E18415C0D2CE97527A515A40D476F467C08415C0B8FD50637D515A40869A7B3FA18415C0EF45808B80515A40E153128A848415C0333B33C983515A40FA1E6D596A8415C0D02C6A1A87515A4080D4B2BD528415C02461197D8A515A4062B372C53D8415C0A5582AEF8D515A4053669B7D2B8415C07B177D6E91515A40910A73F11B8415C0F374E9F894515A40E83B902A0F8415C00570408C98515A40CC2AD430058415C00E884D269C515A40E2C0650AFE8315C0EA18D8C49F515A4055D5ADBBF98315C0A0B9A465A3515A4034755447F88315C0C29C7606A7515A40C13F3FAEF98315C0A8F110A5AA515A4004D990EFFD8315C0AC45383FAE515A403072A908058415C092E4B3D2B1515A404B6828F50E8415C03A374F5DB5515A40C1F6EEAE1B8415C0CD1FDBDCB8515A4029FE232E2B8415C082522F4FBC515A40BDDA38693D8415C040AA2BB2BF515A407349EF54528415C02078B903C3515A40185760E4698415C035CDCC41C6515A40E6540409848415C09CBD656AC9515A404DCEBBB2A08415C0329C917BCC515A40D17AD9CFBF8415C01D2E6C73CF515A4020242D4DE18415C068D52050D2515A40AD7B0F16058515C006B2EB0FD5515A4012D76E142B8515C079B81AB1D7515A4048CCDC30538515C086BD0E32DA515A4008A59C527D8515C03D763C91DC515A40609FB25FA98515C0C36B2DCDDE515A40A5F4F33CD78515C043E280E4E0515A40A59917CE068615C07CB2ECD5E2515A40CEB0C7F5378615C05F153EA0E4515A40CEA0B3956A8615C044615A42E6515A4031C7A28E9E8615C041B83FBBE7515A40CEB887C0D38615C03DA7050AE9515A409C06940A0A8715C046B5DD2DEA515A407D784C4B418715C0F4E21326EB515A40B7B39D60798715C073190FF2EB515A401D3EF127B28715C0EC885191EC515A4053D3427EEB8715C02DF67803ED515A40C2FC3540258815C03CF73E48ED515A4051E02B4A5F8815C0D41E795FED515A408D385978998815C090161949ED515A407D67DCA6D38815C0D3A72C05ED515A40B097D3B10D8915C046B3DD93EC515A408BDD7275478915C0131772F5EB515A40854A1ACE808915C0D3834B2AEB515A401FE66B98B98915C0010300000001000000810000007EB461D220535A405F9D65673B7D15C0BEA605DB1F535A409EDF7480737D15C0859C04B81E535A40EFB594C5AA7D15C0680B126A1D535A4016F0AE14E17D15C02AE5FBF11B535A40D715454C167E15C0C418AA501A535A40D00F854B4A7E15C059031E8718535A40DE645DF27C7E15C08AD1719616535A40D4019121AE7E15C071D1D77F14535A400F7DCABADD7E15C0BDB5994412535A408BCCAEA00B7F15C05CCA17E60F535A401A60EFB6377F15C0401BC8650D535A406F975BE2617F15C0A98D35C50A535A407086F1088A7F15C0A3ECFE0508535A406F00EE11B07F15C02FE9D52905535A4034DDDBE5D37F15C0CE0E7E3202535A400F71A26EF57F15C003ADCB21FF525A40C82D9397148015C080B6A2F9FB525A400764764D318015C0AB96F5BBF8525A40EA1D977E4B8015C039FEC36AF5525A40520ACE1A638015C096A71908F2525A40EF738B13788015C0DE130D96EE525A406F3CE05B8A8015C03741BE16EB525A4058D685E8998015C04A5B558CE7525A40A439E5AFA68015C0B36601F9E3525A403ACE1CAAB08015C037E8F65EE0525A40DB4705D1B78015C093886EC0DC525A404E723520BC8015C0C7B5A31FD9525A4062E90495BD8015C09842D37ED5525A40F0BC8D2EBC8015C04D053AE0D1525A4094FEACEDB78015C056761346CE525A407F3902D5B08015C0D74F98B2CA525A40ECD3EDE8A68015C0E12EFD27C7525A40AC5C8E2F9A8015C0323771A8C3525A4055C4BCB08A8015C058BA1C36C0525A40CA860776788015C008E31FD3BC525A400CC6AC8A638015C080659181B9525A40DA5A93FB4B8015C0BA357D43B6525A40FEDF42D7318015C04544E31AB3525A402CBCDA2D158015C08442B609B0525A40D12F0811F67F15C01C6FDA11AD525A40A16EFB93D47F15C04D6B2435AA525A4091C95BCBB07F15C0E6195875A7525A4001F23ACD8A7F15C0978827D4A4525A40045D07B1627F15C037E43153A2525A408FCF7D8F387F15C0C17802F49F525A40461D9A820C7F15C081BD0FB89D525A40132187A5DE7E15C0256EBAA09B525A4065FC8D14AF7E15C038B14CAF99525A4073A404ED7D7E15C0834CF9E497525A4024CB3B4D4B7E15C0E2E7DA4296525A40E42B6C54177E15C0F25EF3C994525A40A84AA322E27D15C011222B7B93525A40B3AEAFD8AB7D15C008A7505792525A4044A70C98747D15C0BBE9175F91525A40B2A4CD823C7D15C035FD199390525A40EC3489BB037D15C03CADD4F38F525A40CFAD4365CA7C15C0CD30AA818F525A40F09459A3907C15C08FEDE03C8F525A4096D06999567C15C06A4CA3258F525A4068AF3F6B1C7C15C0729FFF3B8F525A4075D5BC3CE27B15C00E19E87F8F525A40041BC331A87B15C08ED432F18F525A404A6B1E6E6E7B15C0FFEF998F90525A4021B16E15357B15C056B7BB5A91525A403BDE114BFC7A15C0B2E01A5292525A405B1B0E32C47A15C0ADD91E7593525A40402FFCEC8C7A15C0762514C394525A40D427F29D567A15C090CB2C3B96525A4062556E66217A15C0DAD680DC97525A4021A24267ED7915C0A5E40EA699525A40365580C0BA7915C075C3BC969B525A407B4B6491897915C00F2158AD9D525A4075B443F8597915C0684797E89F525A40CB5C79122C7915C0FDE71947A2525A40A39453FCFF7815C022F569C7A4525A4040BA02D1D57815C0A988FC67A7525A403B7688AAAD7815C07DD73227AA525A4014B1A7A1877815C064315B03AD525A40B34ED5CD637815C0810CB2FAAF525A4009B72945427815C0C61B630BB3525A40C635531C237815C0C46F8A33B6525A4095398966067815C01AA13571B9525A40257A8035EC7715C0DA0365C2BC525A407B0D6099D47715C008E30C25C0525A406C71B7A0BF7715C09FC31697C3525A4002917558AD7715C01FAE6216C7525A4018CBE0CB9D7715C00A7EC8A0CA525A4037FE8F04917715C060361934CE525A40859E640A877715C0575A20CED1525A4023DA85E37F7715C07449A56CD5525A405FCD5C947B7715C0369E6C0DD9525A40DDCA911F7A7715C06F8E39AEDC525A40CAB70A867B7715C0844CCF4CE0525A40357EEAC67F7715C0A468F2E6E3525A40549591DF867715C02A316A7AE7525A40F89F9FCB907715C052110205EB525A40051FF6849D7715C064ED8A84EE525A40FB37BC03AD7715C07D7BDCF6F1525A40528B633EBF7715C02198D659F5525A405419AE29D47715C0CD9562ABF8525A403731B5B8EB7715C0AF8674E9FB525A405A65F1DC057815C0C57F0C12FF525A400B814386227815C085D4372302535A40297AFEA2417815C06B4A121B05535A402557F21F637815C09643C7F707535A40620478E8867815C0C7DF92B70A535A408B107EE6AC7815C01013C3580D535A409B489602D57815C07EB1B8D90F535A40102B0424FF7815C0266FE83812535A408128CC302B7915C0F3D3DB7414535A404FAAC30D597915C09322328C16535A40CDD2A19E887915C00732A17D18535A404AEF10C6B97915C04139F6471A535A408A8EC065EC7915C0608C16EA1B535A405633785E207A15C0034B00631D535A40D3942A90557A15C058FFCAB11E535A403C6309DA8B7A15C0832DA8D51F535A409782991AC37A15C0F6D2E3CD20535A4029B1C72FFB7A15C07FD5E49921535A40848AFDF6337B15C0B8612D3922535A40BEDC364D6D7B15C0AC385BAB22535A405D40170FA77B15C071EC27F022535A4006E7FF18E17B15C0A00B690723535A40A39325471B7C15C08E3B10F122535A401CADA675557C15C028412BAD22535A407E5FA1808F7C15C080F8E33B22535A402FBD4944C97C15C0083B809D21535A4042D2FF9C027D15C07EB461D220535A405F9D65673B7D15C001030000000100000081000000B559E9857A545A4041D8BBA2826F15C03A69968E79545A40011BE7BBBA6F15C0BAA39E6B78545A4022FA2801F26F15C01479B51D77545A40A5306B50287015C03FD5A8A575545A40D82D2F885D7015C052A1600474545A4042BEA287917015C08834DE3A72545A401949B42EC47015C08AB53B4A70545A401298265EF57015C0736CAB336E545A40051BA4F7247115C0F20577F86B545A401D9ED1DD527115C0F8C7FE9969545A40216460F47E7115C079B8B81967545A409E9C1F20A97115C0C7B62F7964545A4069280D47D17115C0028802BA61545A40CDA46550F77115C057D7E2DD5E545A40E1B0B3241B7215C0832A94E65B545A40A465DEAD3C7215C05CCBEAD558545A401DF736D75B7215C001A7CAAD55545A40E475858D787215C06523267052545A40DDA914BF927215C0E7EBFC1E4F545A40B7FDBC5BAA7215C0C6B55ABC4B545A401876EE54BF7215C017FD554A48545A4003ADB99DD17215C025BB0ECB44545A40CECBD72AE17215C0E916AD4041545A400080B1F2ED7215C0841060AD3D545A40E4E564EDF77215C06F285C133A545A40B264CA14FF7215C05903DA7436545A40EA7A7864037315C0620B15D432545A408076C6D9047315C0B50F4A332F545A400F19CE73037315C036E3B5942B545A40CF256C33FF7215C033FB93FA27545A4085D93F1BF87215C0F20E1D6724545A40354CA92FEE7215C0E6B885DC20545A40D9BEC676E17215C0771AFD5C1D545A40CCD470F8D17215C02183ABEA19545A4072BD35BEBF7215C0D11BB18716545A40454F53D3AA7215C04697243613545A409A18B044937215C041E811F80F545A40286BD320797215C066FE78CF0C545A400766DC775C7215C0778A4CBE09545A40BD03785B3D7215C0C5CA70C606545A40E133D6DE1B7215C08560BAE903545A4058059E16F87115C0C82EED2901545A4094E9E018D27115C0CB43BB88FE535A400F180DFDA97115C040CDC307FC535A409D1ADFDB7F7115C0411892A8F9535A40568C52CF537115C0889D9C6CF7535A40621292F2257115C07B1A4455F5535A404B9BE661F67015C09FB7D263F3535A4063ECA53AC57015C0033D7B99F1535A40C68A209B927015C00A5558F7EF535A4050088FA25E7015C020DE6B7EEE535A40BCC2FE70297015C0B04B9E2FED535A407B1E3E27F36F15C0D016BE0BEC535A40794BC8E6BB6F15C0F23E7F13EB535A404E9EB0D1836F15C0E4DA7A47EA535A40C88C8D0A4B6F15C071BA2EA8E9535A405A5863B4116F15C0CB18FD35E9535A40ED758EF2D76E15C003602CF1E8535A40DEBEADE89D6E15C0A0FDE6D9E8535A40C1788CBA636E15C07C483BF0E8535A4060420C8C296E15C0F9771B34E9535A409BF20E81EF6D15C082AC5DA5E9535A400B7760BDB56D15C06909BC43EA535A40D8C0A0647C6D15C009E0D40EEB535A40BBCB2D9A436D15C003EC2A06EC535A405BCE0D810B6D15C092A02529ED535A4012A1D93BD46C15C09C861177EE535A402267A7EC9D6C15C06EAB20EFEF535A40CE89F5B4686C15C0C21F6B90F1535A40E40F96B5346C15C0D386EF59F3535A40A4609A0E026C15C016B5934AF5535A40777C3FDFD06B15C0485E2561F7535A40C9B9DA45A16B15C058D25A9CF9535A406B0FC75F736B15C0BDC8D3FAFB535A40DBFA5249476B15C0BA391A7BFE535A40BB0AAF1D1D6B15C00F45A31B01545A40F91ADDF6F46A15C08025D0DA03545A40334AA0EDCE6A15C0A530EFB606545A401BB56D19AB6A15C05AE23CAE09545A40FCFE5D90896A15C031F3E4BE0C545A4041B11F676A6A15C0447903E70F545A40927AEAB04D6A15C09F12A62413545A40B554737F336A15C09918CD7516545A40AF99E1E21B6A15C05DDB6CD819545A40210DC5E9066A15C0E0E46E4A1D545A4078E10CA1F46915C07742B3C920545A4063BEFF13E56915C048D4115424545A4085CC344CD86915C0C7A15BE727545A402BCB8D51CE6915C06B325C812B545A408F34322AC76915C0C3E9DA1F2F545A40C6718BDAC26915C022669CC032545A40CA224265C16915C0F4E0636136545A407C7A3CCBC26915C0F88FF4FF39545A40C3B09D0BC76915C07B06139A3D545A40AF8AC623CE6915C0B395862D41545A40B5F8560FD86915C079AB1AB844545A40F7C830C8E46915C0692EA03748545A40A66D7B46F46915C0B0D6EEA94B545A4025D3A880066A15C09B82E60C4F545A40C2447B6B1B6A15C02C86705E52545A408E5B0CFA326A15C0C9F4809C55545A407FF2D41D4D6A15C05EE417C558545A400B1CB6C6696A15C008A942D65B545A40881303E3886A15C09D081DCE5E545A401E238C5FAA6A15C04D65D2AA61545A40ED78AA27CE6A15C0A0DE9E6A64545A403EE34C25F46A15C01F68D00B67545A40626C05411C6B15C009D5C78C69545A40CDCD1762466B15C05AD8F9EB6B545A4078B0886E726B15C097F8EF276E545A406EB32D4BA06B15C0C676493F70545A40E22BBEDBCF6B15C0F127BC3072545A400C97E402016C15C0D54015FB73545A4093B050A2336C15C00F133A9D75545A40EC24CA9A676C15C07EBB281677545A40ABD143CC9C6C15C04AC1F86478545A401A8AEF15D36C15C055A5DB8879545A40DB5152560A6D15C08F611D817A545A404E03596B426D15C007D8244D7B545A4080526D327B6D15C0613174EC7B545A4066228B88B46D15C0782AA95E7C545A40A11C564AEE6D15C0FE507DA37C545A4040802F54286E15C0FA2EC6BA7C545A40C3194C82626E15C0F76475A47C545A40E055CAB09C6E15C0F6B298607C545A40A062C8BBD66E15C0EEEF59EF7B545A408F507A7F106F15C00FF0FE507B545A400D2640D8496F15C0B559E9857A545A4041D8BBA2826F15C0
\.


--
-- Data for Name: wilayah; Type: TABLE DATA; Schema: transportasi; Owner: postgres
--

COPY transportasi.wilayah (id, kode_wilayah, nama, tipe, populasi, luas_km2, created_at, geom) FROM stdin;
1	3571010	Tanjung Karang Pusat	kecamatan	85000	4.05	2026-03-30 20:03:41.711895	0103000020E610000001000000050000000000000000505A40A4703D0AD7A315C0E17A14AE47515A40A4703D0AD7A315C0E17A14AE47515A40C3F5285C8FC215C00000000000505A40C3F5285C8FC215C00000000000505A40A4703D0AD7A315C0
2	3571020	Tanjung Karang Barat	kecamatan	72000	14.99	2026-03-30 20:03:41.711895	0103000020E610000001000000050000001F85EB51B84E5A4085EB51B81E8515C00000000000505A4085EB51B81E8515C00000000000505A40AE47E17A14AE15C01F85EB51B84E5A40AE47E17A14AE15C01F85EB51B84E5A4085EB51B81E8515C0
3	3571030	Teluk Betung Selatan	kecamatan	45000	3.79	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000713D0AD7A3505A40C3F5285C8FC215C052B81E85EB515A40C3F5285C8FC215C052B81E85EB515A40E17A14AE47E115C0713D0AD7A3505A40E17A14AE47E115C0713D0AD7A3505A40C3F5285C8FC215C0
4	3571040	Rajabasa	kecamatan	95000	13.02	2026-03-30 20:03:41.711895	0103000020E610000001000000050000003D0AD7A3704D5A40713D0AD7A37015C08FC2F5285C4F5A40713D0AD7A37015C08FC2F5285C4F5A408FC2F5285C8F15C03D0AD7A3704D5A408FC2F5285C8F15C03D0AD7A3704D5A40713D0AD7A37015C0
5	3571050	Sukarame	kecamatan	88000	14.75	2026-03-30 20:03:41.711895	0103000020E6100000010000000500000052B81E85EB515A40713D0AD7A37015C014AE47E17A545A40713D0AD7A37015C014AE47E17A545A409A999999999915C052B81E85EB515A409A999999999915C052B81E85EB515A40713D0AD7A37015C0
6	3571060	Kedaton	kecamatan	78000	5.23	2026-03-30 20:03:41.711895	0103000020E610000001000000050000008FC2F5285C4F5A4085EB51B81E8515C0713D0AD7A3505A4085EB51B81E8515C0713D0AD7A3505A40A4703D0AD7A315C08FC2F5285C4F5A40A4703D0AD7A315C08FC2F5285C4F5A4085EB51B81E8515C0
7	3571070	Way Halim	kecamatan	82000	5.35	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000E17A14AE47515A409A999999999915C03333333333535A409A999999999915C03333333333535A40B81E85EB51B815C0E17A14AE47515A40B81E85EB51B815C0E17A14AE47515A409A999999999915C0
8	3571080	Panjang	kecamatan	65000	8.92	2026-03-30 20:03:41.711895	0103000020E61000000100000005000000C3F5285C8F525A40D7A3703D0AD715C014AE47E17A545A40D7A3703D0AD715C014AE47E17A545A40F6285C8FC2F515C0C3F5285C8F525A40F6285C8FC2F515C0C3F5285C8F525A40D7A3703D0AD715C0
\.


--
-- Name: deteksi_objek_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.deteksi_objek_id_seq', 1, false);


--
-- Name: hama_penyakit_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.hama_penyakit_id_seq', 15, true);


--
-- Name: irigasi_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.irigasi_id_seq', 7, true);


--
-- Name: kelompok_tani_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.kelompok_tani_id_seq', 8, true);


--
-- Name: kios_pupuk_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.kios_pupuk_id_seq', 8, true);


--
-- Name: lahan_id_seq; Type: SEQUENCE SET; Schema: pertanian; Owner: postgres
--

SELECT pg_catalog.setval('pertanian.lahan_id_seq', 15, true);


--
-- Name: fasilitas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fasilitas_id_seq', 8, true);


--
-- Name: jalan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.jalan_id_seq', 4, true);


--
-- Name: wilayah_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.wilayah_id_seq', 2, true);


--
-- Name: topology_id_seq; Type: SEQUENCE SET; Schema: topology; Owner: postgres
--

SELECT pg_catalog.setval('topology.topology_id_seq', 1, false);


--
-- Name: halte_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.halte_id_seq', 25, true);


--
-- Name: kecelakaan_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.kecelakaan_id_seq', 20, true);


--
-- Name: parkir_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.parkir_id_seq', 12, true);


--
-- Name: rute_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.rute_id_seq', 8, true);


--
-- Name: wilayah_id_seq; Type: SEQUENCE SET; Schema: transportasi; Owner: postgres
--

SELECT pg_catalog.setval('transportasi.wilayah_id_seq', 8, true);


--
-- Name: deteksi_objek deteksi_objek_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.deteksi_objek
    ADD CONSTRAINT deteksi_objek_pkey PRIMARY KEY (id);


--
-- Name: hama_penyakit hama_penyakit_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.hama_penyakit
    ADD CONSTRAINT hama_penyakit_pkey PRIMARY KEY (id);


--
-- Name: irigasi irigasi_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.irigasi
    ADD CONSTRAINT irigasi_pkey PRIMARY KEY (id);


--
-- Name: kelompok_tani kelompok_tani_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kelompok_tani
    ADD CONSTRAINT kelompok_tani_pkey PRIMARY KEY (id);


--
-- Name: kios_pupuk kios_pupuk_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.kios_pupuk
    ADD CONSTRAINT kios_pupuk_pkey PRIMARY KEY (id);


--
-- Name: lahan lahan_kode_lahan_key; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.lahan
    ADD CONSTRAINT lahan_kode_lahan_key UNIQUE (kode_lahan);


--
-- Name: lahan lahan_pkey; Type: CONSTRAINT; Schema: pertanian; Owner: postgres
--

ALTER TABLE ONLY pertanian.lahan
    ADD CONSTRAINT lahan_pkey PRIMARY KEY (id);


--
-- Name: fasilitas fasilitas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fasilitas
    ADD CONSTRAINT fasilitas_pkey PRIMARY KEY (id);


--
-- Name: jalan jalan_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jalan
    ADD CONSTRAINT jalan_pkey PRIMARY KEY (id);


--
-- Name: wilayah wilayah_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wilayah
    ADD CONSTRAINT wilayah_pkey PRIMARY KEY (id);


--
-- Name: halte halte_kode_key; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.halte
    ADD CONSTRAINT halte_kode_key UNIQUE (kode);


--
-- Name: halte halte_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.halte
    ADD CONSTRAINT halte_pkey PRIMARY KEY (id);


--
-- Name: kecelakaan kecelakaan_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.kecelakaan
    ADD CONSTRAINT kecelakaan_pkey PRIMARY KEY (id);


--
-- Name: parkir parkir_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.parkir
    ADD CONSTRAINT parkir_pkey PRIMARY KEY (id);


--
-- Name: rute rute_kode_rute_key; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.rute
    ADD CONSTRAINT rute_kode_rute_key UNIQUE (kode_rute);


--
-- Name: rute rute_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.rute
    ADD CONSTRAINT rute_pkey PRIMARY KEY (id);


--
-- Name: tugas5_area_rawan_kecelakaan tugas5_area_rawan_kecelakaan_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.tugas5_area_rawan_kecelakaan
    ADD CONSTRAINT tugas5_area_rawan_kecelakaan_pkey PRIMARY KEY (id);


--
-- Name: tugas5_centroid_wilayah tugas5_centroid_wilayah_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.tugas5_centroid_wilayah
    ADD CONSTRAINT tugas5_centroid_wilayah_pkey PRIMARY KEY (id);


--
-- Name: tugas5_tumpang_tindih tugas5_tumpang_tindih_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.tugas5_tumpang_tindih
    ADD CONSTRAINT tugas5_tumpang_tindih_pkey PRIMARY KEY (id);


--
-- Name: tugas5_zona_layanan_halte tugas5_zona_layanan_halte_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.tugas5_zona_layanan_halte
    ADD CONSTRAINT tugas5_zona_layanan_halte_pkey PRIMARY KEY (id);


--
-- Name: wilayah wilayah_kode_wilayah_key; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.wilayah
    ADD CONSTRAINT wilayah_kode_wilayah_key UNIQUE (kode_wilayah);


--
-- Name: wilayah wilayah_pkey; Type: CONSTRAINT; Schema: transportasi; Owner: postgres
--

ALTER TABLE ONLY transportasi.wilayah
    ADD CONSTRAINT wilayah_pkey PRIMARY KEY (id);


--
-- Name: idx_deteksi_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_deteksi_geom ON pertanian.deteksi_objek USING gist (geom);


--
-- Name: idx_hama_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_hama_geom ON pertanian.hama_penyakit USING gist (geom);


--
-- Name: idx_irigasi_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_irigasi_geom ON pertanian.irigasi USING gist (geom);


--
-- Name: idx_kios_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_kios_geom ON pertanian.kios_pupuk USING gist (geom);


--
-- Name: idx_poktan_geom; Type: INDEX; Schema: pertanian; Owner: postgres
--

CREATE INDEX idx_poktan_geom ON pertanian.kelompok_tani USING gist (geom);


--
-- Name: idx_halte_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_halte_geom ON transportasi.halte USING gist (geom);


--
-- Name: idx_parkir_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_parkir_geom ON transportasi.parkir USING gist (geom);


--
-- Name: idx_rute_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_rute_geom ON transportasi.rute USING gist (geom);


--
-- Name: idx_wilayah_geom; Type: INDEX; Schema: transportasi; Owner: postgres
--

CREATE INDEX idx_wilayah_geom ON transportasi.wilayah USING gist (geom);


--
-- PostgreSQL database dump complete
--

\unrestrict fEmzhknm8G8tKger8ipkndeeqgih86f275v27tKrMlAhFPgIi0Ey4OhSegkdwkb

