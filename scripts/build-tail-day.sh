#!/usr/bin/env bash
# Rebuilds faa.tail_day (flights per aircraft per day) from faa.ontime, one
# month at a time, replacing each month's partition. Run after loading flights.
#
#   scripts/build-tail-day.sh            every month in faa.ontime
#   scripts/build-tail-day.sh 202501     just these months
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ch_check_connection

months=("$@")
[[ ${#months[@]} -gt 0 ]] || months=($(ch_query "SELECT DISTINCT toYYYYMM(FlightDate) FROM faa.ontime ORDER BY 1"))

for m in "${months[@]}"; do
  ch_query "ALTER TABLE faa.tail_day DROP PARTITION $m"
  ch_query "
    INSERT INTO faa.tail_day
    SELECT FlightDate, Reporting_Airline, tail,
           count(), countIf(Cancelled = 0),
           countIf(Cancelled = 1 AND CancellationCode = 'A'),
           countIf(Cancelled = 1 AND CancellationCode != 'A'),
           countIf(Diverted = 1),
           sum(ifNull(CarrierDelay, 0)), countIf(CarrierDelay >= 15)
    FROM faa.ontime
    WHERE toYYYYMM(FlightDate) = $m
    GROUP BY FlightDate, Reporting_Airline, tail"
done

ch_query "
  SELECT (SELECT count() FROM faa.ontime) AS ontime_flights,
         sum(flights) AS tail_day_flights, count() AS tail_day_rows
  FROM faa.tail_day FORMAT PrettyCompact"
