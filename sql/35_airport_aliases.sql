-- Airport codes BTS still uses after an airport was re-coded, mapped to the
-- current IATA code that OurAirports and IEM use. Add rows here when
-- load-stations.sh reports an airport without a station.
CREATE OR REPLACE VIEW faa.airport_aliases AS
SELECT * FROM values('bts_code String, iata_code String',
    ('PBI', 'DJT'),  -- Palm Beach Intl, renamed 2025
    ('TKI', 'DTX')   -- McKinney National, re-coded
);

-- Closed airports that OurAirports no longer gives any code, so they have to be
-- matched by OurAirports ident and given their IEM station explicitly.
CREATE OR REPLACE VIEW faa.airport_closed AS
SELECT * FROM values('bts_code String, ident String, station String',
    ('ISN', 'US-11527', 'ISN')  -- Williston Sloulin Field, replaced by XWA in 2019
);
