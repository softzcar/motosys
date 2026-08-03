-- ============================================
-- ELIMINACIÓN LIMPIA DEL ÚLTIMO CIERRE DE CAJA
-- ============================================
-- Desvincula las ventas y movimientos de caja del cierre más reciente
-- y elimina su cabecera y detalle.

CREATE OR REPLACE FUNCTION eliminar_ultimo_cierre_caja(p_cierre_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ultimo_id UUID;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede eliminar un cierre de caja';
  END IF;

  -- Verificar cuál es el último cierre registrado
  SELECT id INTO v_ultimo_id
  FROM cierres_caja
  ORDER BY fecha_hora_cierre DESC
  LIMIT 1;

  IF v_ultimo_id IS NULL OR v_ultimo_id != p_cierre_id THEN
    RAISE EXCEPTION 'Solo se puede eliminar el último cierre registrado de la caja';
  END IF;

  -- 1. Desvincular ventas
  UPDATE ventas
  SET cierre_id = NULL
  WHERE cierre_id = p_cierre_id;

  -- 2. Desvincular movimientos de caja
  UPDATE movimientos_caja
  SET cierre_id = NULL
  WHERE cierre_id = p_cierre_id;

  -- 3. Eliminar detalles y cabecera del cierre
  DELETE FROM cierres_caja_detalle WHERE cierre_id = p_cierre_id;
  DELETE FROM cierres_caja WHERE id = p_cierre_id;

  RETURN true;
END;
$$;

NOTIFY pgrst, 'reload schema';
