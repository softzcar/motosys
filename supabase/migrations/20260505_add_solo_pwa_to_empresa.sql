-- Añadir columna solo_pwa a la tabla empresa
ALTER TABLE empresa ADD COLUMN IF NOT EXISTS solo_pwa BOOLEAN DEFAULT false;
