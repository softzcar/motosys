-- ============================================
-- FASE 3: Cierres de Caja Diarios
-- ============================================
-- Un cierre agrupa ventas + movimientos desde el último cierre
-- cerrado hasta su propia fecha de cierre.
-- El admin logueado confirma el efectivo contado por método,
-- el sistema calcula la diferencia y congela los movimientos/ventas.

CREATE TABLE IF NOT EXISTS cierres_caja (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha DATE NOT NULL,
  fecha_hora_cierre TIMESTAMPTZ NOT NULL DEFAULT now(),
  responsable_id UUID NOT NULL REFERENCES auth.users(id),
  total_sistema_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_contado_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  diferencia_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  observaciones TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_cierres_fecha ON cierres_caja(fecha);
CREATE INDEX IF NOT EXISTS idx_cierres_responsable ON cierres_caja(responsable_id);

CREATE TABLE IF NOT EXISTS cierres_caja_detalle (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cierre_id UUID NOT NULL REFERENCES cierres_caja(id) ON DELETE CASCADE,
  metodo_pago_id UUID NOT NULL REFERENCES metodos_pago(id) ON DELETE RESTRICT,
  monto_sistema DECIMAL(14,2) NOT NULL DEFAULT 0,
  monto_contado DECIMAL(14,2) NOT NULL DEFAULT 0,
  diferencia DECIMAL(14,2) NOT NULL DEFAULT 0,
  monto_sistema_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  monto_contado_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  tasa_referencia DECIMAL(14,4) NOT NULL DEFAULT 1,
  UNIQUE (cierre_id, metodo_pago_id)
);

CREATE INDEX IF NOT EXISTS idx_cierres_det_cierre ON cierres_caja_detalle(cierre_id);

-- Ahora sí podemos añadir la FK de movimientos_caja.cierre_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'movimientos_caja_cierre_id_fkey'
  ) THEN
    ALTER TABLE movimientos_caja
      ADD CONSTRAINT movimientos_caja_cierre_id_fkey
      FOREIGN KEY (cierre_id) REFERENCES cierres_caja(id) ON DELETE SET NULL;
  END IF;
END$$;

-- Tambien vinculamos ventas a un cierre (opcional pero útil)
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS cierre_id UUID;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ventas_cierre_id_fkey'
  ) THEN
    ALTER TABLE ventas
      ADD CONSTRAINT ventas_cierre_id_fkey
      FOREIGN KEY (cierre_id) REFERENCES cierres_caja(id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_ventas_cierre ON ventas(cierre_id);

ALTER TABLE cierres_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierres_caja_detalle ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios ven cierres" ON cierres_caja FOR SELECT USING (true);
CREATE POLICY "Admin crea cierres" ON cierres_caja FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "Admin actualiza cierres" ON cierres_caja FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

CREATE POLICY "Usuarios ven detalle cierres" ON cierres_caja_detalle FOR SELECT USING (true);
CREATE POLICY "Admin crea detalle cierres" ON cierres_caja_detalle FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "Admin actualiza detalle cierres" ON cierres_caja_detalle FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- ============================================
-- RPC: preview del cierre del día
-- Devuelve, por método de pago, el total que el sistema
-- registra como entrado/salido desde el último cierre hasta ahora.
-- ============================================
CREATE OR REPLACE FUNCTION preview_cierre_caja()
RETURNS TABLE (
  metodo_pago_id UUID,
  nombre TEXT,
  moneda TEXT,
  monto_sistema DECIMAL,
  monto_sistema_usd DECIMAL,
  total_ventas DECIMAL,
  total_ingresos DECIMAL,
  total_egresos DECIMAL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_desde TIMESTAMPTZ;
BEGIN
  SELECT COALESCE(MAX(fecha_hora_cierre), '1970-01-01'::timestamptz)
    INTO v_desde
    FROM cierres_caja;

  RETURN QUERY
  WITH ventas_por_metodo AS (
    SELECT vp.metodo_pago_id,
           SUM(vp.monto_recibido) AS total_moneda,
           SUM(vp.monto_usd) AS total_usd
    FROM ventas_pagos vp
    JOIN ventas v ON v.id = vp.venta_id
    WHERE v.fecha > v_desde
      AND v.cierre_id IS NULL
    GROUP BY vp.metodo_pago_id
  ),
  ingresos_por_metodo AS (
    SELECT mc.metodo_pago_id,
           SUM(mc.monto) AS total_moneda,
           SUM(mc.monto_usd) AS total_usd
    FROM movimientos_caja mc
    WHERE mc.tipo = 'ingreso'
      AND mc.fecha > v_desde
      AND mc.cierre_id IS NULL
    GROUP BY mc.metodo_pago_id
  ),
  egresos_por_metodo AS (
    SELECT mc.metodo_pago_id,
           SUM(mc.monto) AS total_moneda,
           SUM(mc.monto_usd) AS total_usd
    FROM movimientos_caja mc
    WHERE mc.tipo = 'egreso'
      AND mc.fecha > v_desde
      AND mc.cierre_id IS NULL
    GROUP BY mc.metodo_pago_id
  )
  SELECT
    mp.id AS metodo_pago_id,
    mp.nombre,
    mp.moneda,
    COALESCE(v.total_moneda, 0) + COALESCE(i.total_moneda, 0) - COALESCE(e.total_moneda, 0) AS monto_sistema,
    COALESCE(v.total_usd, 0) + COALESCE(i.total_usd, 0) - COALESCE(e.total_usd, 0) AS monto_sistema_usd,
    COALESCE(v.total_moneda, 0) AS total_ventas,
    COALESCE(i.total_moneda, 0) AS total_ingresos,
    COALESCE(e.total_moneda, 0) AS total_egresos
  FROM metodos_pago mp
  LEFT JOIN ventas_por_metodo v ON v.metodo_pago_id = mp.id
  LEFT JOIN ingresos_por_metodo i ON i.metodo_pago_id = mp.id
  LEFT JOIN egresos_por_metodo e ON e.metodo_pago_id = mp.id
  WHERE mp.activo = true
     OR v.metodo_pago_id IS NOT NULL
     OR i.metodo_pago_id IS NOT NULL
     OR e.metodo_pago_id IS NOT NULL
  ORDER BY mp.nombre;
END;
$$;

-- ============================================
-- RPC: ejecutar cierre de caja
-- p_detalles: [{ "metodo_pago_id": "uuid", "monto_contado": 123.45, "tasa_referencia": 40.5 }, ...]
-- ============================================
CREATE OR REPLACE FUNCTION ejecutar_cierre_caja(
  p_fecha DATE,
  p_detalles JSONB,
  p_observaciones TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cierre_id UUID;
  v_desde TIMESTAMPTZ;
  v_hasta TIMESTAMPTZ := now();
  v_detalle JSONB;
  v_metodo RECORD;
  v_monto_sistema DECIMAL(14,2);
  v_monto_sistema_usd DECIMAL(14,2);
  v_monto_contado DECIMAL(14,2);
  v_tasa DECIMAL(14,4);
  v_monto_contado_usd DECIMAL(14,2);
  v_total_sistema_usd DECIMAL(14,2) := 0;
  v_total_contado_usd DECIMAL(14,2) := 0;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede ejecutar cierres de caja';
  END IF;

  IF EXISTS (SELECT 1 FROM cierres_caja WHERE fecha = p_fecha) THEN
    RAISE EXCEPTION 'Ya existe un cierre para la fecha %', p_fecha;
  END IF;

  SELECT COALESCE(MAX(fecha_hora_cierre), '1970-01-01'::timestamptz)
    INTO v_desde
    FROM cierres_caja;

  INSERT INTO cierres_caja (fecha, fecha_hora_cierre, responsable_id, observaciones)
  VALUES (p_fecha, v_hasta, auth.uid(), NULLIF(TRIM(COALESCE(p_observaciones, '')), ''))
  RETURNING id INTO v_cierre_id;

  FOR v_detalle IN SELECT * FROM jsonb_array_elements(p_detalles)
  LOOP
    SELECT id, nombre, moneda, activo
      INTO v_metodo
      FROM metodos_pago
      WHERE id = (v_detalle->>'metodo_pago_id')::UUID;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Método de pago % no encontrado', v_detalle->>'metodo_pago_id';
    END IF;

    -- Totales sistema por método desde v_desde hasta v_hasta
    SELECT
      COALESCE(SUM(x.monto), 0),
      COALESCE(SUM(x.monto_usd), 0)
    INTO v_monto_sistema, v_monto_sistema_usd
    FROM (
      SELECT vp.monto_recibido AS monto, vp.monto_usd AS monto_usd
      FROM ventas_pagos vp
      JOIN ventas v ON v.id = vp.venta_id
      WHERE vp.metodo_pago_id = v_metodo.id
        AND v.fecha > v_desde AND v.fecha <= v_hasta
        AND v.cierre_id IS NULL
      UNION ALL
      SELECT mc.monto AS monto, mc.monto_usd AS monto_usd
      FROM movimientos_caja mc
      WHERE mc.metodo_pago_id = v_metodo.id
        AND mc.tipo = 'ingreso'
        AND mc.fecha > v_desde AND mc.fecha <= v_hasta
        AND mc.cierre_id IS NULL
      UNION ALL
      SELECT -mc.monto AS monto, -mc.monto_usd AS monto_usd
      FROM movimientos_caja mc
      WHERE mc.metodo_pago_id = v_metodo.id
        AND mc.tipo = 'egreso'
        AND mc.fecha > v_desde AND mc.fecha <= v_hasta
        AND mc.cierre_id IS NULL
    ) x;

    v_monto_contado := COALESCE((v_detalle->>'monto_contado')::DECIMAL, 0);
    v_tasa := COALESCE(NULLIF((v_detalle->>'tasa_referencia')::DECIMAL, 0), 1);

    IF v_metodo.moneda = 'USD' THEN
      v_monto_contado_usd := v_monto_contado;
    ELSE
      v_monto_contado_usd := ROUND(v_monto_contado / v_tasa, 2);
    END IF;

    INSERT INTO cierres_caja_detalle (
      cierre_id, metodo_pago_id, monto_sistema, monto_contado, diferencia,
      monto_sistema_usd, monto_contado_usd, tasa_referencia
    )
    VALUES (
      v_cierre_id, v_metodo.id, v_monto_sistema, v_monto_contado, v_monto_contado - v_monto_sistema,
      v_monto_sistema_usd, v_monto_contado_usd, v_tasa
    );

    v_total_sistema_usd := v_total_sistema_usd + v_monto_sistema_usd;
    v_total_contado_usd := v_total_contado_usd + v_monto_contado_usd;
  END LOOP;

  UPDATE cierres_caja
  SET total_sistema_usd = v_total_sistema_usd,
      total_contado_usd = v_total_contado_usd,
      diferencia_usd = v_total_contado_usd - v_total_sistema_usd
  WHERE id = v_cierre_id;

  -- Marcar ventas y movimientos como parte de este cierre
  UPDATE ventas
  SET cierre_id = v_cierre_id
  WHERE fecha > v_desde AND fecha <= v_hasta AND cierre_id IS NULL;

  UPDATE movimientos_caja
  SET cierre_id = v_cierre_id
  WHERE fecha > v_desde AND fecha <= v_hasta AND cierre_id IS NULL;

  RETURN v_cierre_id;
END;
$$;
