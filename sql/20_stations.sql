-- IEM ASOS station metadata (location and time zone), one row per station.
-- Station ids are FAA identifiers, which match the BTS Origin/Dest codes for
-- airports in the lower 48; elsewhere IEM uses ICAO codes (PANC, TJSJ), which
-- faa.airport_station resolves. tzname converts BTS local times to UTC.
CREATE TABLE IF NOT EXISTS faa.stations
(
    station   LowCardinality(String),
    network   LowCardinality(String),
    name      String,
    state     LowCardinality(String),
    country   LowCardinality(String),
    lat       Float64,
    lon       Float64,
    elevation Nullable(Float32),
    tzname    LowCardinality(String),
    archive_begin Nullable(Date32)
)
ENGINE = ReplacingMergeTree
ORDER BY station;
