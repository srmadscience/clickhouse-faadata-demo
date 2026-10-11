-- Normalised aircraft registration. Allegiant (G4) reports tail numbers without
-- the US "N" prefix (816NV rather than N816NV); no other carrier does, and the
-- prefixed forms never collide with another tail. A few are in lower case
-- (n346FR). ALIAS: computed at query time, nothing stored. Empty for some
-- cancelled flights (no aircraft assigned); a handful are placeholders such as
-- '#N/A' or 'SS1', which match no registration.
ALTER TABLE faa.ontime
    ADD COLUMN IF NOT EXISTS tail String ALIAS '';
ALTER TABLE faa.ontime
    MODIFY COLUMN tail String ALIAS
        upper(if(match(Tail_Number, '^[0-9]'), concat('N', Tail_Number), Tail_Number));
