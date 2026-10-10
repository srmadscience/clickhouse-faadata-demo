-- OurAirports airport list (public domain), worldwide, one row per airport.
-- https://ourairports.com/data/
-- Used to translate BTS airport codes (IATA) into IEM station ids, and for
-- names and coordinates on Grafana maps.
CREATE TABLE IF NOT EXISTS faa.airports
(
    id                UInt32,
    ident             String,
    type              LowCardinality(String),
    name              String,
    latitude_deg      Float64,
    longitude_deg     Float64,
    elevation_ft      Nullable(Int32),
    continent         LowCardinality(String),
    iso_country       LowCardinality(String),
    iso_region        LowCardinality(String),
    municipality      String,
    scheduled_service LowCardinality(String),
    icao_code         String,
    iata_code         String,
    gps_code          String,
    local_code        String
)
ENGINE = ReplacingMergeTree
ORDER BY id;
