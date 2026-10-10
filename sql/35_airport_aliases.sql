-- Airport codes BTS still uses after an airport was re-coded, mapped to the
-- current IATA code that OurAirports and IEM use. Add rows here when
-- load-stations.sh reports an airport without a station.
CREATE OR REPLACE VIEW faa.airport_aliases AS
SELECT * FROM values('bts_code String, iata_code String',
    ('PBI', 'DJT')  -- Palm Beach Intl, renamed 2025
);
