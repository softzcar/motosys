-- ============================================
-- FASE 1: Detalle/Referencia en Métodos de Pago
-- ============================================

-- 1. Añadir flag a metodos_pago
ALTER TABLE metodos_pago
  ADD COLUMN IF NOT EXISTS requiere_detalle BOOLEAN NOT NULL DEFAULT false;

-- 2. Añadir referencia a ventas_pagos
ALTER TABLE ventas_pagos
  ADD COLUMN IF NOT EXISTS referencia TEXT;

-- 3. Reemplazar procesar_venta para aceptar referencia por pago
--    y validar contra requiere_detalle
DROP FUNCTION IF EXISTS procesar_venta(JSONB, JSONB, UUID);
DROP FUNCTION IF EXISTS procesar_venta(JSONB, UUID);
DROP FUNCTION IF EXISTS procesar_venta(JSONB);

CREATE OR REPLACE FUNCTION procesar_venta(
  p_items JSONB,
  p_pagos JSONB,
  p_cliente_id UUID DEFAULT NULL
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

  -- Total en USD
  SELECT COALESCE(SUM((item->>'cantidad')::INT * (item->>'precio_unitario')::DECIMAL), 0)
  INTO v_total
  FROM jsonb_array_elements(p_items) AS item;

  -- Validar todos los pagos ANTES de tocar stock
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

  -- Crear venta
  INSERT INTO ventas (vendedor_id, cliente_id, total, fecha)
  VALUES (auth.uid(), p_cliente_id, v_total, now())
  RETURNING id INTO v_venta_id;

  -- Procesar items (stock)
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

  -- Insertar pagos (ya validados)
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
