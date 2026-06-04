-- ============================================
-- EDICIÓN DE COMPRAS Y AJUSTE DE STOCK ATÓMICO
-- ============================================
-- Permite modificar una factura de compra existente.
-- La edición revierte el stock original y aplica el stock nuevo de forma atómica.
-- Solo disponible para administradores.

CREATE OR REPLACE FUNCTION editar_compra(
  p_compra_id UUID,
  p_numero_factura TEXT,
  p_fecha DATE,
  p_id_proveedor UUID,
  p_descuento DECIMAL,
  p_subtotal DECIMAL,
  p_iva DECIMAL,
  p_total DECIMAL,
  p_detalles JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_compra RECORD;
  v_detalle RECORD;
  v_item JSONB;
  v_before public.productos;
  v_after public.productos;
  v_stock_calculado INT;
  v_stock_final INT;
  v_motivo_audit TEXT;
BEGIN
  -- 1. Validar que sea admin (según estándar is_admin())
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Solo el administrador puede editar compras';
  END IF;

  -- 2. Lock de la compra original para evitar concurrencia
  SELECT id, anulada
    INTO v_compra
    FROM compras
    WHERE id = p_compra_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Compra no encontrada';
  END IF;

  IF v_compra.anulada THEN
    RAISE EXCEPTION 'No se puede editar una compra anulada';
  END IF;

  -- 3. Revertir stock de los detalles originales de la compra
  FOR v_detalle IN
    SELECT id_producto, cantidad, productos.stock, productos.nombre, productos.codigo_parte
      FROM detalle_compras
      JOIN productos ON productos.id = detalle_compras.id_producto
      WHERE id_compra = p_compra_id
  LOOP
    v_stock_calculado := v_detalle.stock - v_detalle.cantidad;
    
    -- Si el stock queda negativo, lo permitimos pero lo auditamos como ajuste
    IF v_stock_calculado < 0 THEN
      v_stock_final := 0;
      v_motivo_audit := 'EDICION_COMPRA_REVERTIR_SEGURIDAD:' || p_compra_id::text || '|CALCULO:' || v_stock_calculado::text;
    ELSE
      v_stock_final := v_stock_calculado;
      v_motivo_audit := 'EDICION_COMPRA_REVERTIR:' || p_compra_id::text;
    END IF;

    SELECT * INTO v_before FROM productos WHERE id = v_detalle.id_producto;

    UPDATE productos
      SET stock = v_stock_final,
          updated_at = now()
      WHERE id = v_detalle.id_producto
      RETURNING * INTO v_after;

    INSERT INTO public.inventario_auditoria (
      producto_id, codigo_parte, nombre, accion, motivo,
      valor_anterior, valor_nuevo, usuario_id
    ) VALUES (
      v_after.id, v_after.codigo_parte, v_after.nombre, 'UPDATE', v_motivo_audit,
      to_jsonb(v_before), to_jsonb(v_after), auth.uid()
    );
  END LOOP;

  -- 4. Eliminar detalles de compra antiguos
  DELETE FROM detalle_compras WHERE id_compra = p_compra_id;

  -- 5. Actualizar la cabecera de la compra
  UPDATE compras
    SET numero_factura = p_numero_factura,
        fecha = p_fecha,
        id_proveedor = p_id_proveedor,
        descuento = p_descuento,
        subtotal = p_subtotal,
        iva = p_iva,
        total = p_total,
        updated_at = now()
    WHERE id = p_compra_id;

  -- 6. Insertar nuevos detalles y aplicar nuevo stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles)
  LOOP
    -- Insertar en detalle_compras
    INSERT INTO detalle_compras (id_compra, id_producto, cantidad, costo_unitario, subtotal)
    VALUES (
      p_compra_id,
      (v_item->>'id_producto')::UUID,
      (v_item->>'cantidad')::INT,
      (v_item->>'costo_unitario')::DECIMAL,
      (v_item->>'subtotal')::DECIMAL
    );

    -- Actualizar stock del producto (sumar)
    SELECT * INTO v_before FROM productos WHERE id = (v_item->>'id_producto')::UUID;
    
    v_stock_final := v_before.stock + (v_item->>'cantidad')::INT;
    v_motivo_audit := 'EDICION_COMPRA_APLICAR:' || p_compra_id::text;

    UPDATE productos
      SET stock = v_stock_final,
          updated_at = now()
      WHERE id = (v_item->>'id_producto')::UUID
      RETURNING * INTO v_after;

    INSERT INTO public.inventario_auditoria (
      producto_id, codigo_parte, nombre, accion, motivo,
      valor_anterior, valor_nuevo, usuario_id
    ) VALUES (
      v_after.id, v_after.codigo_parte, v_after.nombre, 'UPDATE', v_motivo_audit,
      to_jsonb(v_before), to_jsonb(v_after), auth.uid()
    );
  END LOOP;

  RETURN p_compra_id;
END;
$$;
