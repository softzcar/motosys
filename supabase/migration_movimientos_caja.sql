-- ============================================
-- FASE 2: Movimientos de Caja (ingresos/egresos manuales)
-- ============================================
-- Notas de crédito (ingresos) y notas de débito (egresos)
-- manuales sobre caja o cuentas bancarias.
-- El cierre_id se asigna cuando se cierra la caja del día.

CREATE TABLE IF NOT EXISTS movimientos_caja (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo TEXT NOT NULL CHECK (tipo IN ('ingreso', 'egreso')),
  metodo_pago_id UUID NOT NULL REFERENCES metodos_pago(id) ON DELETE RESTRICT,
  monto DECIMAL(14,2) NOT NULL CHECK (monto > 0),
  tasa_aplicada DECIMAL(14,4) NOT NULL DEFAULT 1 CHECK (tasa_aplicada > 0),
  monto_usd DECIMAL(14,2) NOT NULL CHECK (monto_usd > 0),
  motivo TEXT NOT NULL,
  referencia TEXT,
  responsable_id UUID NOT NULL REFERENCES auth.users(id),
  cierre_id UUID, -- se llena al cerrar caja (FK se añade en fase 3)
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_movcaja_fecha ON movimientos_caja(fecha);
CREATE INDEX IF NOT EXISTS idx_movcaja_metodo ON movimientos_caja(metodo_pago_id);
CREATE INDEX IF NOT EXISTS idx_movcaja_cierre ON movimientos_caja(cierre_id);
CREATE INDEX IF NOT EXISTS idx_movcaja_tipo_fecha ON movimientos_caja(tipo, fecha);

ALTER TABLE movimientos_caja ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios ven movimientos"
  ON movimientos_caja FOR SELECT
  USING (true);

CREATE POLICY "Admin crea movimientos"
  ON movimientos_caja FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "Admin actualiza movimientos"
  ON movimientos_caja FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admin elimina movimientos"
  ON movimientos_caja FOR DELETE
  USING (is_admin() AND cierre_id IS NULL);

-- RPC para registrar un movimiento validando el método y fijando el responsable
CREATE OR REPLACE FUNCTION registrar_movimiento_caja(
  p_tipo TEXT,
  p_metodo_pago_id UUID,
  p_monto DECIMAL,
  p_tasa_aplicada DECIMAL,
  p_motivo TEXT,
  p_referencia TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID;
  v_metodo RECORD;
  v_monto_usd DECIMAL(14,2);
  v_motivo TEXT;
  v_referencia TEXT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede registrar movimientos de caja';
  END IF;

  IF p_tipo NOT IN ('ingreso', 'egreso') THEN
    RAISE EXCEPTION 'Tipo inválido: %', p_tipo;
  END IF;

  IF p_monto IS NULL OR p_monto <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser mayor a cero';
  END IF;

  IF p_tasa_aplicada IS NULL OR p_tasa_aplicada <= 0 THEN
    RAISE EXCEPTION 'La tasa aplicada debe ser mayor a cero';
  END IF;

  v_motivo := NULLIF(TRIM(COALESCE(p_motivo, '')), '');
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'El motivo es obligatorio';
  END IF;

  SELECT id, nombre, requiere_detalle, activo
    INTO v_metodo
    FROM metodos_pago
    WHERE id = p_metodo_pago_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Método de pago % no encontrado', p_metodo_pago_id;
  END IF;

  IF NOT v_metodo.activo THEN
    RAISE EXCEPTION 'Método de pago % está inactivo', v_metodo.nombre;
  END IF;

  v_referencia := NULLIF(TRIM(COALESCE(p_referencia, '')), '');

  IF v_metodo.requiere_detalle AND v_referencia IS NULL THEN
    RAISE EXCEPTION 'El método de pago % requiere una referencia', v_metodo.nombre;
  END IF;

  v_monto_usd := ROUND(p_monto / p_tasa_aplicada, 2);

  INSERT INTO movimientos_caja (
    tipo, metodo_pago_id, monto, tasa_aplicada, monto_usd,
    motivo, referencia, responsable_id, fecha
  )
  VALUES (
    p_tipo, p_metodo_pago_id, p_monto, p_tasa_aplicada, v_monto_usd,
    v_motivo, v_referencia, auth.uid(), now()
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
