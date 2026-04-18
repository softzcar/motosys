-- ACTUALIZAR RPC PARA INCLUIR UBICACIÓN
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
    ubicacion = CASE WHEN p_data ? 'ubicacion' THEN NULLIF(p_data->>'ubicacion','') ELSE ubicacion END,
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

NOTIFY pgrst, 'reload schema';
