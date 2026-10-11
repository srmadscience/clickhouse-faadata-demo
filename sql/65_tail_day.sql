-- One row per aircraft per airline per day, summarising faa.ontime for the
-- Aircraft Reliability dashboard: about a quarter of the rows, and ordered by
-- tail so one aircraft's history reads only its own rows. Built by
-- scripts/build-tail-day.sh (rebuild after loading flights). Rows with an
-- empty tail hold the flights that had no aircraft assigned. An aircraft almost
-- never flies for two airlines in a day, so count() = aircraft-days.
CREATE TABLE IF NOT EXISTS faa.tail_day
(
    FlightDate        Date,
    Reporting_Airline LowCardinality(String),
    tail              String,
    flights           UInt32,   -- scheduled, including cancelled
    completed         UInt32,   -- not cancelled (diverted included)
    cxl_carrier       UInt32,   -- cancelled by the carrier (code A)
    cxl_other         UInt32,   -- cancelled for weather, NAS or security (B, C, D)
    diverted          UInt32,
    carrier_delay     Float64,  -- sum of CarrierDelay minutes
    delayed15         UInt32    -- CarrierDelay >= 15
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(FlightDate)
ORDER BY (tail, FlightDate, Reporting_Airline);
