-- Exclude inactive products and products with no movement in the period from audit results
DROP FUNCTION IF EXISTS public.obtener_auditoria_inventario(TIMESTAMPTZ, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION public.obtener_auditoria_inventario(
  p_desde TIMESTAMPTZ,
  p_hasta TIMESTAMPTZ
)
RETURNS TABLE (
  id UUID,
  codigo_parte TEXT,
  nombre TEXT,
  stock_actual INT,
  stock_inicial INT,
  compras_periodo INT,
  ventas_periodo INT,
  ajustes_periodo INT,
  stock_real_periodo INT,
  categoria_nombre TEXT,
  marca_nombre TEXT,
  categoria_id UUID,
  marca_id UUID,
  proveedores_ids UUID[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH base AS (
    SELECT
      p.id,
      p.codigo_parte,
      p.nombre,
      p.stock AS stock_actual,

      -- 1. Stock Inicial (todo lo anterior a p_desde)
      (
        COALESCE((
          SELECT SUM(dc.cantidad)::INT
          FROM public.detalle_compras dc
          JOIN public.compras c ON c.id = dc.id_compra
          WHERE dc.id_producto = p.id
            AND c.anulada IS NOT TRUE
            AND c.fecha < p_desde::date
        ), 0)
        -
        COALESCE((
          SELECT SUM(dv.cantidad)::INT
          FROM public.detalle_ventas dv
          JOIN public.ventas v ON v.id = dv.venta_id
          WHERE dv.producto_id = p.id
            AND v.anulada IS NOT TRUE
            AND v.fecha < p_desde
        ), 0)
        +
        COALESCE((
          SELECT SUM(
            COALESCE((ia.valor_nuevo->>'stock')::int, 0) - COALESCE((ia.valor_anterior->>'stock')::int, 0)
          )::INT
          FROM public.inventario_auditoria ia
          WHERE ia.producto_id = p.id
            AND ia.accion = 'UPDATE'
            AND ia.created_at < p_desde
            AND NOT (
              ia.motivo LIKE 'REVERSION_STOCK_COMPRA%' OR
              ia.motivo LIKE 'AJUSTE_SEGURIDAD_COMPRA%' OR
              ia.motivo LIKE 'EDICION_COMPRA%' OR
              ia.motivo LIKE 'ANULACIÓN VENTA%'
            )
        ), 0)
      ) AS stock_inicial,

      -- 2. Compras del periodo
      COALESCE((
        SELECT SUM(dc.cantidad)::INT
        FROM public.detalle_compras dc
        JOIN public.compras c ON c.id = dc.id_compra
        WHERE dc.id_producto = p.id
          AND c.anulada IS NOT TRUE
          AND c.fecha >= p_desde::date
          AND c.fecha <= p_hasta::date
      ), 0) AS compras_periodo,

      -- 3. Ventas del periodo
      COALESCE((
        SELECT SUM(dv.cantidad)::INT
        FROM public.detalle_ventas dv
        JOIN public.ventas v ON v.id = dv.venta_id
        WHERE dv.producto_id = p.id
          AND v.anulada IS NOT TRUE
          AND v.fecha >= p_desde
          AND v.fecha <= p_hasta
      ), 0) AS ventas_periodo,

      -- 4. Ajustes del periodo
      COALESCE((
        SELECT SUM(
          COALESCE((ia.valor_nuevo->>'stock')::int, 0) - COALESCE((ia.valor_anterior->>'stock')::int, 0)
        )::INT
        FROM public.inventario_auditoria ia
        WHERE ia.producto_id = p.id
          AND ia.accion = 'UPDATE'
          AND ia.created_at >= p_desde
          AND ia.created_at <= p_hasta
          AND NOT (
            ia.motivo LIKE 'REVERSION_STOCK_COMPRA%' OR
            ia.motivo LIKE 'AJUSTE_SEGURIDAD_COMPRA%' OR
            ia.motivo LIKE 'EDICION_COMPRA%' OR
            ia.motivo LIKE 'ANULACIÓN VENTA%'
          )
      ), 0) AS ajustes_periodo,

      -- 5. Stock Real al final del periodo
      (
        p.stock
        -
        COALESCE((
          SELECT SUM(dc.cantidad)::INT
          FROM public.detalle_compras dc
          JOIN public.compras c ON c.id = dc.id_compra
          WHERE dc.id_producto = p.id
            AND c.anulada IS NOT TRUE
            AND c.fecha > p_hasta::date
        ), 0)
        +
        COALESCE((
          SELECT SUM(dv.cantidad)::INT
          FROM public.detalle_ventas dv
          JOIN public.ventas v ON v.id = dv.venta_id
          WHERE dv.producto_id = p.id
            AND v.anulada IS NOT TRUE
            AND v.fecha > p_hasta
        ), 0)
        -
        COALESCE((
          SELECT SUM(
            COALESCE((ia.valor_nuevo->>'stock')::int, 0) - COALESCE((ia.valor_anterior->>'stock')::int, 0)
          )::INT
          FROM public.inventario_auditoria ia
          WHERE ia.producto_id = p.id
            AND ia.accion = 'UPDATE'
            AND ia.created_at > p_hasta
            AND NOT (
              ia.motivo LIKE 'REVERSION_STOCK_COMPRA%' OR
              ia.motivo LIKE 'AJUSTE_SEGURIDAD_COMPRA%' OR
              ia.motivo LIKE 'EDICION_COMPRA%' OR
              ia.motivo LIKE 'ANULACIÓN VENTA%'
            )
        ), 0)
      ) AS stock_real_periodo,

      cat.nombre AS categoria_nombre,
      mar.nombre AS marca_nombre,
      p.categoria_id,
      p.marca_id,

      COALESCE(ARRAY(
        SELECT DISTINCT c.id_proveedor
        FROM public.detalle_compras dc
        JOIN public.compras c ON c.id = dc.id_compra
        WHERE dc.id_producto = p.id AND c.anulada IS NOT TRUE
      ), '{}'::uuid[]) AS proveedores_ids

    FROM public.productos p
    LEFT JOIN public.categorias_productos cat ON cat.id = p.categoria_id
    LEFT JOIN public.marcas mar ON mar.id = p.marca_id
    WHERE p.activo = true
  )
  -- Solo devolver productos con movimiento en el periodo
  SELECT * FROM base
  WHERE base.compras_periodo > 0 OR base.ventas_periodo > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_auditoria_inventario(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
