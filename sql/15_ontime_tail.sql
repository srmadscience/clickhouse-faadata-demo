-- Normalised aircraft registration. Allegiant (G4) reports tail numbers without
-- the US "N" prefix (816NV rather than N816NV); no other carrier does, and the
-- prefixed forms never collide with another tail. ALIAS: computed at query
-- time, nothing stored. Empty for some cancelled flights (no aircraft assigned).
ALTER TABLE faa.ontime
    ADD COLUMN IF NOT EXISTS tail String ALIAS
        if(match(Tail_Number, '^[0-9]'), concat('N', Tail_Number), Tail_Number);
