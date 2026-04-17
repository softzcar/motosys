-- Tabla de auditoría para cambios y eliminaciones de productos
CREATE TABLE IF NOT EXISTS public.inventario_auditoria (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id UUID,
  codigo_parte TEXT NOT NULL,
  nombre TEXT NOT NULL,
  accion TEXT NOT NULL CHECK (accion IN ('UPDATE','DELETE')),
  motivo TEXT NOT NULL,
  valor_anterior JSONB NOT NULL,
  valor_nuevo JSONB,
  usuario_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventario_auditoria_producto ON public.inventario_auditoria(producto_id);
CREATE INDEX IF NOT EXISTS idx_inventario_auditoria_created ON public.inventario_auditoria(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inventario_auditoria_accion ON public.inventario_auditoria(accion);

ALTER TABLE public.inventario_auditoria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_select_auditoria" ON public.inventario_auditoria;
CREATE POLICY "admin_select_auditoria" ON public.inventario_auditoria
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'admin')
  );

-- RPC: editar producto con motivo
CREATE OR REPLACE FUNCTION public.editar_producto_con_motivo(
  p_id UUID,
  p_data JSONB,
  p_motivo TEXT
) RETURNS public.productos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_before public.productos;
  v_after public.productos;
  v_rol TEXT;
BEGIN
  SELECT rol INTO v_rol FROM public.perfiles WHERE id = auth.uid();
  IF v_rol IS NULL OR v_rol <> 'admin' THEN
    RAISE EXCEPTION 'Solo los administradores pueden editar productos';
  END IF;

  IF p_motivo IS NULL OR length(btrim(p_motivo)) < 10 THEN
    RAISE EXCEPTION 'El motivo del cambio debe tener al menos 10 caracteres';
  END IF;

  SELECT * INTO v_before FROM public.productos WHERE id = p_id FOR UPDATE;
  IF v_before.id IS NULL THEN
    RAISE EXCEPTION 'Producto no encontrado';
  END IF;

  UPDATE public.productos SET
    nombre = COALESCE(p_data->>'nombre', nombre),
    codigo_parte = COALESCE(p_data->>'codigo_parte', codigo_parte),
    stock = COALESCE((p_data->>'stock')::int, stock),
    precio_venta = COALESCE((p_data->>'precio_venta')::numeric, precio_venta),
    imagen_url = CASE WHEN p_data ? 'imagen_url' THEN NULLIF(p_data->>'imagen_url','') ELSE imagen_url END,
    categoria_id = CASE WHEN p_data ? 'categoria_id' THEN NULLIF(p_data->>'categoria_id','')::uuid ELSE categoria_id END,
    activo = COALESCE((p_data->>'activo')::boolean, activo),
    updated_at = NOW()
  WHERE id = p_id
  RETURNING * INTO v_after;

  INSERT INTO public.inventario_auditoria (
    producto_id, codigo_parte, nombre, accion, motivo,
    valor_anterior, valor_nuevo, usuario_id
  ) VALUES (
    v_after.id, v_after.codigo_parte, v_after.nombre, 'UPDATE', btrim(p_motivo),
    to_jsonb(v_before), to_jsonb(v_after), auth.uid()
  );

  RETURN v_after;
END;
$$;

-- RPC: eliminar producto con motivo (bloqueado si tiene ventas o compras)
CREATE OR REPLACE FUNCTION public.eliminar_producto_con_motivo(
  p_id UUID,
  p_motivo TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_before public.productos;
  v_rol TEXT;
  v_ventas_count INT;
  v_compras_count INT;
BEGIN
  SELECT rol INTO v_rol FROM public.perfiles WHERE id = auth.uid();
  IF v_rol IS NULL OR v_rol <> 'admin' THEN
    RAISE EXCEPTION 'Solo los administradores pueden eliminar productos';
  END IF;

  IF p_motivo IS NULL OR length(btrim(p_motivo)) < 10 THEN
    RAISE EXCEPTION 'El motivo de la eliminación debe tener al menos 10 caracteres';
  END IF;

  SELECT * INTO v_before FROM public.productos WHERE id = p_id FOR UPDATE;
  IF v_before.id IS NULL THEN
    RAISE EXCEPTION 'Producto no encontrado';
  END IF;

  SELECT COUNT(*) INTO v_ventas_count FROM public.detalle_ventas WHERE producto_id = p_id;
  IF v_ventas_count > 0 THEN
    RAISE EXCEPTION 'No se puede eliminar: el producto tiene % venta(s) registrada(s). Para preservar el historial, considere marcarlo como inactivo.', v_ventas_count;
  END IF;

  SELECT COUNT(*) INTO v_compras_count FROM public.detalle_compras WHERE id_producto = p_id;
  IF v_compras_count > 0 THEN
    RAISE EXCEPTION 'No se puede eliminar: el producto tiene % compra(s) registrada(s). Para preservar el historial, considere marcarlo como inactivo.', v_compras_count;
  END IF;

  INSERT INTO public.inventario_auditoria (
    producto_id, codigo_parte, nombre, accion, motivo,
    valor_anterior, valor_nuevo, usuario_id
  ) VALUES (
    v_before.id, v_before.codigo_parte, v_before.nombre, 'DELETE', btrim(p_motivo),
    to_jsonb(v_before), NULL, auth.uid()
  );

  DELETE FROM public.productos WHERE id = p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.editar_producto_con_motivo(UUID, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.eliminar_producto_con_motivo(UUID, TEXT) TO authenticated;

-- FK directa a perfiles para permitir embed en PostgREST
ALTER TABLE public.inventario_auditoria
  ADD CONSTRAINT fk_inventario_auditoria_usuario_perfil
  FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE SET NULL;

NOTIFY pgrst, 'reload schema';
