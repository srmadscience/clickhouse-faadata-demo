-- IEM ASOS observations (METAR routine + special reports), times in UTC.
-- https://mesonet.agron.iastate.edu/request/download.phtml
-- Units: tmpf/dwpf/feel F, relh %, drct degrees, sknt/gust knots, p01i inches
-- (0.0001 = trace; test with p01i < 0.001, as Float32 != 0.0001), alti inHg, mslp mb, vsby miles, skyl feet.
-- ReplacingMergeTree drops duplicate (station, valid) rows, so reloads are safe;
-- add FINAL to a query if it must not see not-yet-merged duplicates.
CREATE TABLE IF NOT EXISTS faa.weather
(
    station           LowCardinality(String),
    valid             DateTime('UTC'),
    lon               Float32,
    lat               Float32,
    elevation         Nullable(Float32),
    tmpf              Nullable(Float32),
    dwpf              Nullable(Float32),
    relh              Nullable(Float32),
    drct              Nullable(Float32),
    sknt              Nullable(Float32),
    p01i              Nullable(Float32),
    alti              Nullable(Float32),
    mslp              Nullable(Float32),
    vsby              Nullable(Float32),
    gust              Nullable(Float32),
    skyc1             LowCardinality(String),
    skyc2             LowCardinality(String),
    skyc3             LowCardinality(String),
    skyc4             LowCardinality(String),
    skyl1             Nullable(Float32),
    skyl2             Nullable(Float32),
    skyl3             Nullable(Float32),
    skyl4             Nullable(Float32),
    wxcodes           LowCardinality(String),
    ice_accretion_1hr Nullable(Float32),
    ice_accretion_3hr Nullable(Float32),
    ice_accretion_6hr Nullable(Float32),
    peak_wind_gust    Nullable(Float32),
    peak_wind_drct    Nullable(Float32),
    peak_wind_time    Nullable(DateTime('UTC')),
    feel              Nullable(Float32),
    metar             String,
    snowdepth         Nullable(Float32)
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(valid)
ORDER BY (station, valid);
