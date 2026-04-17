-- 1. ACTUALIZACIÓN DE LA TABLA VENTAS
ALTER TABLE public.ventas 
ADD COLUMN IF NOT EXISTS numero BIGINT GENERATED ALWAYS AS IDENTITY;

-- Asegurar que el número sea único e indexado
CREATE UNIQUE INDEX IF NOT EXISTS idx_ventas_numero ON public.ventas(numero);

-- 2. ACTUALIZACIÓN DE LA TABLA COMPRAS
ALTER TABLE public.compras 
ADD COLUMN IF NOT EXISTS numero BIGINT GENERATED ALWAYS AS IDENTITY;

-- Asegurar que el número sea único e indexado
CREATE UNIQUE INDEX IF NOT EXISTS idx_compras_numero ON public.compras(numero);

-- 3. ACTUALIZAR FUNCIÓN PROCESAR_VENTA PARA SOPORTAR CLIENTES Y OTROS CAMPOS
-- (Esta versión incluye todas las mejoras acumuladas hoy)
CREATE OR REPLACE FUNCTION public.procesar_venta(
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
BEGIN
  -- Calcular total de la venta
  SELECT COALESCE(SUM((item->>'cantidad')::INT * (item->>'precio_unitario')::DECIMAL), 0)
  INTO v_total
  FROM jsonb_array_elements(p_items) AS item;

  -- 1. Crear la cabecera de la venta
  INSERT INTO public.ventas (vendedor_id, cliente_id, total, corrige_venta_id, fecha)
  VALUES (auth.uid(), p_cliente_id, v_total, p_corrige_venta_id, now())
  RETURNING id INTO v_venta_id;

  -- 2. Procesar cada ítem (Stock y Detalles)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Bloqueo de stock para evitar concurrencia
    SELECT stock INTO v_stock_actual FROM productos WHERE id = (v_item->>'producto_id')::UUID FOR UPDATE;

    IF v_stock_actual < (v_item->>'cantidad')::INT THEN
      RAISE EXCEPTION 'Stock insuficiente para producto ID %', v_item->>'producto_id';
    END IF;

    -- Descontar stock
    UPDATE public.productos
    SET stock = stock - (v_item->>'cantidad')::INT
    WHERE id = (v_item->>'producto_id')::UUID;

    -- Insertar detalle
    INSERT INTO public.detalle_ventas (venta_id, producto_id, cantidad, precio_unitario)
    VALUES (
      v_venta_id,
      (v_item->>'producto_id')::UUID,
      (v_item->>'cantidad')::INT,
      (v_item->>'precio_unitario')::DECIMAL
    );
  END LOOP;

  -- 3. Registrar pagos
  FOR v_pago IN SELECT * FROM jsonb_array_elements(p_pagos)
  LOOP
    INSERT INTO public.ventas_pagos (
      venta_id, metodo_pago_id, monto_recibido, tasa_aplicada, monto_usd, referencia
    ) VALUES (
      v_venta_id,
      (v_pago->>'metodo_pago_id')::UUID,
      (v_pago->>'monto_recibido')::DECIMAL,
      (v_pago->>'tasa_aplicada')::DECIMAL,
      (v_pago->>'monto_usd')::DECIMAL,
      v_pago->>'referencia'
    );
  END LOOP;

  RETURN v_venta_id;
END;
$$;

-- 4. ACTUALIZAR FUNCIÓN ANULAR_VENTA (Para consistencia)
CREATE OR REPLACE FUNCTION public.anular_venta(p_venta_id UUID, p_motivo TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item RECORD;
BEGIN
  -- Revertir stock
  FOR v_item IN SELECT producto_id, cantidad FROM detalle_ventas WHERE venta_id = p_venta_id
  LOOP
    UPDATE productos 
    SET stock = stock + v_item.cantidad,
        updated_at = now()
    WHERE id = v_item.producto_id;
  END LOOP;

  -- Marcar como anulada
  UPDATE ventas
  SET anulada = true,
      motivo_anulacion = p_motivo,
      anulada_por = auth.uid(),
      anulada_at = now()
  WHERE id = p_venta_id;

  RETURN p_venta_id;
END;
$$;
