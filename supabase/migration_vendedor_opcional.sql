-- Actualización del RPC procesar_venta para soportar vendedor explícito (útil para sync offline)
CREATE OR REPLACE FUNCTION procesar_venta(
  p_items JSONB,
  p_pagos JSONB,
  p_cliente_id UUID,
  p_corrige_venta_id UUID DEFAULT NULL,
  p_vendedor_id UUID DEFAULT NULL -- Nuevo parámetro opcional
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
  v_vendedor_real UUID;
BEGIN
  -- 1. Determinar el vendedor (Prioridad: Parámetro > Auth.uid)
  v_vendedor_real := COALESCE(p_vendedor_id, auth.uid());
  
  IF v_vendedor_real IS NULL THEN
    RAISE EXCEPTION 'No se pudo determinar el vendedor responsable';
  END IF;

  -- 2. Validar que hay items
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'La venta debe tener al menos un item';
  END IF;

  -- 3. Calcular total
  SELECT COALESCE(SUM((item->>'cantidad')::INT * (item->>'precio_unitario')::DECIMAL), 0)
  INTO v_total
  FROM jsonb_array_elements(p_items) AS item;

  -- 4. Crear la venta
  INSERT INTO ventas (vendedor_id, total, fecha, cliente_id, corrige_venta_id)
  VALUES (v_vendedor_real, v_total, now(), p_cliente_id, p_corrige_venta_id)
  RETURNING id INTO v_venta_id;

  -- 5. Procesar cada item (Stock y Detalles)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT stock INTO v_stock_actual FROM productos WHERE id = (v_item->>'producto_id')::UUID FOR UPDATE;
    
    -- Blindaje contra stock insuficiente (Actualizado a lógica 0 truncada)
    UPDATE productos
    SET stock = GREATEST(0, stock - (v_item->>'cantidad')::INT)
    WHERE id = (v_item->>'producto_id')::UUID;

    INSERT INTO detalle_ventas (venta_id, producto_id, cantidad, precio_unitario)
    VALUES (v_venta_id, (v_item->>'producto_id')::UUID, (v_item->>'cantidad')::INT, (v_item->>'precio_unitario')::DECIMAL);
  END LOOP;

  -- 6. Procesar Pagos
  IF p_pagos IS NOT NULL THEN
    FOR v_pago IN SELECT * FROM jsonb_array_elements(p_pagos)
    LOOP
      INSERT INTO ventas_pagos (venta_id, metodo_pago_id, monto_recibido, tasa_aplicada, monto_usd, referencia)
      VALUES (
        v_venta_id, 
        (v_pago->>'metodo_pago_id')::UUID, 
        (v_pago->>'monto_recibido')::DECIMAL, 
        (v_pago->>'tasa_aplicada')::DECIMAL, 
        (v_pago->>'monto_usd')::DECIMAL,
        v_pago->>'referencia'
      );
    END LOOP;
  END IF;

  RETURN v_venta_id;
END;
$$;
