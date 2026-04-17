-- ============================================
-- ANULACIÓN DE COMPRAS
-- ============================================
-- Permite anular una compra registrada por error.
-- La anulación revierte el stock y queda auditada.
-- Solo admin. No se borra el registro: se marca anulada.
-- Para corregir, se crea una compra nueva enlazada por corrige_compra_id.

-- 1. Columnas de anulación + traza de corrección
ALTER TABLE compras
  ADD COLUMN IF NOT EXISTS anulada BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
  ADD COLUMN IF NOT EXISTS anulada_por UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS anulada_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS corrige_compra_id UUID REFERENCES compras(id);

-- FK redundante a perfiles(id) para que PostgREST pueda embebir nombre del responsable
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_compras_anulada_por_perfil'
  ) THEN
    ALTER TABLE compras
      ADD CONSTRAINT fk_compras_anulada_por_perfil
      FOREIGN KEY (anulada_por) REFERENCES perfiles(id);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_compras_anulada ON compras(anulada);
CREATE INDEX IF NOT EXISTS idx_compras_corrige ON compras(corrige_compra_id);

-- 2. Stock puede ir negativo temporalmente al anular una compra
-- cuyos productos ya se vendieron. La venta sigue validando stock
-- en su propio RPC (procesar_venta), por lo que el CHECK era redundante.
ALTER TABLE productos DROP CONSTRAINT IF EXISTS productos_stock_check;

-- 3. RLS: admin puede actualizar compras (necesario para anular)
DROP POLICY IF EXISTS "Admin actualiza compras" ON compras;
CREATE POLICY "Admin actualiza compras"
  ON compras FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- 4. RPC: anular_compra
CREATE OR REPLACE FUNCTION anular_compra(
  p_compra_id UUID,
  p_motivo TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_motivo TEXT;
  v_compra RECORD;
  v_detalle RECORD;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede anular compras';
  END IF;

  v_motivo := NULLIF(TRIM(COALESCE(p_motivo, '')), '');
  IF v_motivo IS NULL OR length(v_motivo) < 10 THEN
    RAISE EXCEPTION 'El motivo de anulación es obligatorio (mínimo 10 caracteres)';
  END IF;

  -- Lock fila para evitar concurrencia
  SELECT id, anulada
    INTO v_compra
    FROM compras
    WHERE id = p_compra_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Compra % no encontrada', p_compra_id;
  END IF;

  IF v_compra.anulada THEN
    RAISE EXCEPTION 'La compra ya está anulada';
  END IF;

  -- Revertir stock por cada renglón
  FOR v_detalle IN
    SELECT id_producto, cantidad
      FROM detalle_compras
      WHERE id_compra = p_compra_id
  LOOP
    UPDATE productos
      SET stock = stock - v_detalle.cantidad
      WHERE id = v_detalle.id_producto;
  END LOOP;

  UPDATE compras
    SET anulada = true,
        motivo_anulacion = v_motivo,
        anulada_por = auth.uid(),
        anulada_at = now()
    WHERE id = p_compra_id;

  RETURN p_compra_id;
END;
$$;
