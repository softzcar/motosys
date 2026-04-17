-- 1. Limpieza total de tablas operativas (CASCADE asegura que borra los detalles vinculados)
TRUNCATE TABLE public.ventas CASCADE;
TRUNCATE TABLE public.compras CASCADE;
TRUNCATE TABLE public.inventario_auditoria CASCADE;
TRUNCATE TABLE public.movimientos_caja CASCADE;
TRUNCATE TABLE public.cierres_caja CASCADE;
TRUNCATE TABLE public.productos CASCADE;
TRUNCATE TABLE public.clientes CASCADE;
TRUNCATE TABLE public.proveedores CASCADE;

-- 2. Aplicar el blindaje real a la función de anulación en la base de datos viva
CREATE OR REPLACE FUNCTION public.anular_compra(p_compra_id UUID, p_motivo TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_compra RECORD;
  v_detalle RECORD;
  v_stock_calculado INT;
  v_stock_final INT;
  v_motivo_audit TEXT;
  v_before public.productos;
  v_after public.productos;
BEGIN
  -- Verificar si existe y no está anulada
  SELECT * INTO v_compra FROM compras WHERE id = p_compra_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'La compra no existe';
  END IF;

  IF v_compra.anulada THEN
    RAISE EXCEPTION 'La compra ya está anulada';
  END IF;

  -- Revertir stock por cada renglón
  FOR v_detalle IN
    SELECT id_producto, cantidad, productos.stock, productos.nombre, productos.codigo_parte
      FROM detalle_compras
      JOIN productos ON productos.id = detalle_compras.id_producto
      WHERE id_compra = p_compra_id
  LOOP
    -- CALCULO DE BLINDAJE
    v_stock_calculado := v_detalle.stock - v_detalle.cantidad;
    
    IF v_stock_calculado < 0 THEN
      -- Truncar a cero para evitar el negativo
      v_stock_final := 0;
      -- Formato de máquina exacto para que el frontend lo detecte siempre
      v_motivo_audit := 'AJUSTE_SEGURIDAD_COMPRA:' || p_compra_id::text || '|CALCULO:' || v_stock_calculado::text;
    ELSE
      v_stock_final := v_stock_calculado;
      v_motivo_audit := 'REVERSION_STOCK_COMPRA:' || p_compra_id::text;
    END IF;

    -- Capturar estado anterior para auditoría
    SELECT * INTO v_before FROM productos WHERE id = v_detalle.id_producto;

    -- Actualizar producto
    UPDATE productos
      SET stock = v_stock_final,
          updated_at = now()
      WHERE id = v_detalle.id_producto
      RETURNING * INTO v_after;

    -- Insertar registro en auditoría (incidencias)
    INSERT INTO public.inventario_auditoria (
      producto_id, codigo_parte, nombre, accion, motivo,
      valor_anterior, valor_nuevo, usuario_id
    ) VALUES (
      v_after.id, v_after.codigo_parte, v_after.nombre, 'UPDATE', v_motivo_audit,
      to_jsonb(v_before), to_jsonb(v_after), auth.uid()
    );
  END LOOP;

  -- Marcar compra como anulada
  UPDATE compras
    SET anulada = true,
        motivo_anulacion = p_motivo,
        anulada_por = auth.uid(),
        anulada_at = now()
    WHERE id = p_compra_id;

  RETURN p_compra_id;
END;
$$;
