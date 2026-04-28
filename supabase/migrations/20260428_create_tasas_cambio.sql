-- ============================================
-- Crear tabla de tasas de cambio
-- ============================================

CREATE TABLE IF NOT EXISTS tasas_cambio (
  codigo TEXT PRIMARY KEY, -- 'BCV', 'PARALELO', 'COP'
  nombre TEXT NOT NULL,
  tasa DECIMAL(14,4) NOT NULL DEFAULT 1 CHECK (tasa > 0),
  is_auto BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE tasas_cambio ENABLE ROW LEVEL SECURITY;

-- Politicas
CREATE POLICY "Lectura publica de tasas"
  ON tasas_cambio FOR SELECT
  USING (true);

CREATE POLICY "Admin gestiona tasas"
  ON tasas_cambio FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Datos iniciales
INSERT INTO tasas_cambio (codigo, nombre, tasa, is_auto)
VALUES 
  ('BCV', 'Dólar BCV', 36.50, true),
  ('PARALELO', 'Dólar Paralelo', 40.00, false),
  ('COP', 'Peso Colombiano', 3900.00, false)
ON CONFLICT (codigo) DO NOTHING;
