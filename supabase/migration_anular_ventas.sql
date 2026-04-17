-- ============================================
-- ANULACIÓN DE VENTAS
-- ============================================
-- Permite anular una venta registrada por error.
-- Bloqueada si la venta ya está dentro de un cierre de caja.
-- Revierte stock (suma lo que la venta había restado) y queda auditada.
-- Para corregir: nueva venta vía POS prellenado, enlazada por corrige_venta_id.

-- 1. Columnas de anulación + traza de corrección
ALTER TABLE ventas
  ADD COLUMN IF NOT EXISTS anulada BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
  ADD COLUMN IF NOT EXISTS anulada_por UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS anulada_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS corrige_venta_id UUID REFERENCES ventas(id);

-- FK redundante a perfiles(id) para que PostgREST embeba el responsable
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_ventas_anulada_por_perfil'
  ) THEN
    ALTER TABLE ventas
      ADD CONSTRAINT fk_ventas_anulada_por_perfil
      FOREIGN KEY (anulada_por) REFERENCES perfiles(id);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_ventas_anulada ON ventas(anulada);
CREATE INDEX IF NOT EXISTS idx_ventas_corrige ON ventas(corrige_venta_id);

-- 2. RLS: admin puede actualizar ventas (necesario para anular)
DROP POLICY IF EXISTS "Admin actualiza ventas" ON ventas;
CREATE POLICY "Admin actualiza ventas"
  ON ventas FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- 3. RPC: anular_venta
CREATE OR REPLACE FUNCTION anular_venta(
  p_venta_id UUID,
  p_motivo TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_motivo TEXT;
  v_venta RECORD;
  v_detalle RECORD;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede anular ventas';
  END IF;

  v_motivo := NULLIF(TRIM(COALESCE(p_motivo, '')), '');
  IF v_motivo IS NULL OR length(v_motivo) < 10 THEN
    RAISE EXCEPTION 'El motivo de anulación es obligatorio (mínimo 10 caracteres)';
  END IF;

  SELECT id, anulada, cierre_id
    INTO v_venta
    FROM ventas
    WHERE id = p_venta_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venta % no encontrada', p_venta_id;
  END IF;

  IF v_venta.anulada THEN
    RAISE EXCEPTION 'La venta ya está anulada';
  END IF;

  IF v_venta.cierre_id IS NOT NULL THEN
    RAISE EXCEPTION 'No se puede anular: la venta ya está incluida en un cierre de caja';
  END IF;

  -- Reponer stock (procesar_venta lo restó al crear la venta)
  FOR v_detalle IN
    SELECT producto_id, cantidad
      FROM detalle_ventas
      WHERE venta_id = p_venta_id
  LOOP
    UPDATE productos
      SET stock = stock + v_detalle.cantidad
      WHERE id = v_detalle.producto_id;
  END LOOP;

  UPDATE ventas
    SET anulada = true,
        motivo_anulacion = v_motivo,
        anulada_por = auth.uid(),
        anulada_at = now()
    WHERE id = p_venta_id;

  RETURN p_venta_id;
END;
$$;

-- 4. procesar_venta: aceptar corrige_venta_id opcional
DROP FUNCTION IF EXISTS public.procesar_venta(jsonb, jsonb, uuid);
CREATE OR REPLACE FUNCTION procesar_venta(
  p_items JSONB,
  p_pagos JSONB,
  p_cliente_id UUID DEFAULT NULL,
  p_corrige_venta_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_venta_id UUID;
  v_total DECIMAL(12,2) := 0;
  v_item JSONB;
  v_pago JSONB;
  v_stock_actual INT;
  v_metodo RECORD;
  v_referencia TEXT;
BEGIN
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'La venta debe tener al menos un item';
  END IF;

  IF p_pagos IS NULL OR jsonb_array_length(p_pagos) = 0 THEN
    RAISE EXCEPTION 'La venta debe tener al menos un pago';
  END IF;

  -- Si es corrección, validar que el origen exista y esté anulado
  IF p_corrige_venta_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM ventas WHERE id = p_corrige_venta_id AND anulada = true
    ) THEN
      RAISE EXCEPTION 'La venta a corregir no existe o no está anulada';
    END IF;
  END IF;

  SELECT COALESCE(SUM((item->>'cantidad')::INT * (item->>'precio_unitario')::DECIMAL), 0)
  INTO v_total
  FROM jsonb_array_elements(p_items) AS item;

  -- Validar pagos antes de tocar stock
  FOR v_pago IN SELECT * FROM jsonb_array_elements(p_pagos)
  LOOP
    SELECT id, nombre, requiere_detalle, activo
      INTO v_metodo
      FROM metodos_pago
      WHERE id = (v_pago->>'metodo_pago_id')::UUID;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Método de pago % no encontrado', v_pago->>'metodo_pago_id';
    END IF;

    IF NOT v_metodo.activo THEN
      RAISE EXCEPTION 'Método de pago % está inactivo', v_metodo.nombre;
    END IF;

    v_referencia := NULLIF(TRIM(COALESCE(v_pago->>'referencia', '')), '');

    IF v_metodo.requiere_detalle AND v_referencia IS NULL THEN
      RAISE EXCEPTION 'El método de pago % requiere una referencia', v_metodo.nombre;
    END IF;
  END LOOP;

  INSERT INTO ventas (vendedor_id, cliente_id, total, fecha, corrige_venta_id)
  VALUES (auth.uid(), p_cliente_id, v_total, now(), p_corrige_venta_id)
  RETURNING id INTO v_venta_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT stock INTO v_stock_actual
    FROM productos
    WHERE id = (v_item->>'producto_id')::UUID
      AND activo = true
    FOR UPDATE;

    IF v_stock_actual IS NULL THEN
      RAISE EXCEPTION 'Producto % no encontrado o inactivo', v_item->>'producto_id';
    END IF;

    IF v_stock_actual < (v_item->>'cantidad')::INT THEN
      RAISE EXCEPTION 'Stock insuficiente para producto %. Disponible: %, Solicitado: %',
        v_item->>'producto_id', v_stock_actual, v_item->>'cantidad';
    END IF;

    UPDATE productos
    SET stock = stock - (v_item->>'cantidad')::INT
    WHERE id = (v_item->>'producto_id')::UUID;

    INSERT INTO detalle_ventas (venta_id, producto_id, cantidad, precio_unitario)
    VALUES (
      v_venta_id,
      (v_item->>'producto_id')::UUID,
      (v_item->>'cantidad')::INT,
      (v_item->>'precio_unitario')::DECIMAL
    );
  END LOOP;

  FOR v_pago IN SELECT * FROM jsonb_array_elements(p_pagos)
  LOOP
    v_referencia := NULLIF(TRIM(COALESCE(v_pago->>'referencia', '')), '');

    INSERT INTO ventas_pagos (
      venta_id,
      metodo_pago_id,
      monto_recibido,
      tasa_aplicada,
      monto_usd,
      referencia
    )
    VALUES (
      v_venta_id,
      (v_pago->>'metodo_pago_id')::UUID,
      (v_pago->>'monto_recibido')::DECIMAL,
      (v_pago->>'tasa_aplicada')::DECIMAL,
      (v_pago->>'monto_usd')::DECIMAL,
      v_referencia
    );
  END LOOP;

  RETURN v_venta_id;
END;
$$;

-- 5. preview_cierre_caja: excluir ventas anuladas
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
           SUM(vp.monto_usd)      AS total_usd
    FROM ventas_pagos vp
    JOIN ventas v ON v.id = vp.venta_id
    WHERE v.fecha > v_desde
      AND v.cierre_id IS NULL
      AND v.anulada = false
    GROUP BY vp.metodo_pago_id
  ),
  ingresos_por_metodo AS (
    SELECT mc.metodo_pago_id,
           SUM(mc.monto)     AS total_moneda,
           SUM(mc.monto_usd) AS total_usd
    FROM movimientos_caja mc
    WHERE mc.tipo = 'ingreso'
      AND mc.fecha > v_desde
      AND mc.cierre_id IS NULL
    GROUP BY mc.metodo_pago_id
  ),
  egresos_por_metodo AS (
    SELECT mc.metodo_pago_id,
           SUM(mc.monto)     AS total_moneda,
           SUM(mc.monto_usd) AS total_usd
    FROM movimientos_caja mc
    WHERE mc.tipo = 'egreso'
      AND mc.fecha > v_desde
      AND mc.cierre_id IS NULL
    GROUP BY mc.metodo_pago_id
  )
  SELECT
    mp.id,
    mp.nombre::TEXT,
    mp.moneda::TEXT,
    COALESCE(v.total_moneda, 0) + COALESCE(i.total_moneda, 0) - COALESCE(e.total_moneda, 0),
    COALESCE(v.total_usd,    0) + COALESCE(i.total_usd,    0) - COALESCE(e.total_usd,    0),
    COALESCE(v.total_moneda, 0),
    COALESCE(i.total_moneda, 0),
    COALESCE(e.total_moneda, 0)
  FROM metodos_pago mp
  LEFT JOIN ventas_por_metodo   v ON v.metodo_pago_id = mp.id
  LEFT JOIN ingresos_por_metodo i ON i.metodo_pago_id = mp.id
  LEFT JOIN egresos_por_metodo  e ON e.metodo_pago_id = mp.id
  WHERE mp.activo = true
     OR v.metodo_pago_id IS NOT NULL
     OR i.metodo_pago_id IS NOT NULL
     OR e.metodo_pago_id IS NOT NULL
  ORDER BY mp.nombre;
END;
$$;

-- 6. ejecutar_cierre_caja: excluir ventas anuladas en sumas y al asignar cierre_id
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
        AND v.anulada = false
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

  -- Marcar ventas (no anuladas) y movimientos como parte de este cierre
  UPDATE ventas
  SET cierre_id = v_cierre_id
  WHERE fecha > v_desde AND fecha <= v_hasta
    AND cierre_id IS NULL
    AND anulada = false;

  UPDATE movimientos_caja
  SET cierre_id = v_cierre_id
  WHERE fecha > v_desde AND fecha <= v_hasta AND cierre_id IS NULL;

  RETURN v_cierre_id;
END;
$$;

-- 7. Forzar reload del schema cache de PostgREST
NOTIFY pgrst, 'reload schema';
