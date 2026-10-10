-- Maps each BTS airport code (IATA) to its IEM weather station and time zone.
-- IEM uses FAA ids in the lower 48 (JFK) but ICAO ids elsewhere (PAFA for FAI,
-- TJSJ for SJU), so try every code OurAirports knows for the airport.
-- Re-coded and closed airports are covered by faa.airport_aliases and faa.airport_closed.
-- Join flights to weather with:  ontime.Origin = airport_station.airport,
--                                weather.station = airport_station.station
CREATE OR REPLACE VIEW faa.airport_station AS
SELECT
    a.iata_code AS airport,
    s.station   AS station,
    -- IEM lists the Virgin Islands as Atlantic/Bermuda, which observes DST;
    -- the USVI does not, so that would be an hour off for half the year.
    if(s.network = 'VI_ASOS', 'America/St_Thomas', s.tzname) AS tzname,
    a.name      AS airport_name,
    a.latitude_deg  AS lat,
    a.longitude_deg AS lon
FROM
(
    SELECT
        iata_code, name, latitude_deg, longitude_deg,
        arrayJoin(arrayFilter(c -> c != '', [local_code, icao_code, gps_code, ident])) AS code,
        -- prefer open airports with scheduled service when an IATA code is reused
        (type = 'closed', scheduled_service != 'yes') AS rank
    FROM
    (
        SELECT * FROM faa.airports WHERE iata_code != ''
        UNION ALL
        -- old codes still used by BTS (see 35_airport_aliases.sql)
        SELECT ap.* REPLACE (al.bts_code AS iata_code)
        FROM faa.airports AS ap
        INNER JOIN faa.airport_aliases AS al ON ap.iata_code = al.iata_code
        UNION ALL
        -- closed airports with no codes left (see 35_airport_aliases.sql)
        SELECT ap.* REPLACE (cl.bts_code AS iata_code, cl.station AS local_code)
        FROM faa.airports AS ap
        INNER JOIN faa.airport_closed AS cl ON ap.ident = cl.ident
    )
) AS a
INNER JOIN faa.stations AS s ON s.station = a.code
ORDER BY a.rank
LIMIT 1 BY a.iata_code;
