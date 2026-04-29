-- 1. Crear tabla de marcas
CREATE TABLE IF NOT EXISTS public.marcas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Habilitar RLS
ALTER TABLE public.marcas ENABLE ROW LEVEL SECURITY;

-- 3. Políticas de RLS
DROP POLICY IF EXISTS "Usuarios ven marcas" ON public.marcas;
CREATE POLICY "Usuarios ven marcas" ON public.marcas
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin gestiona marcas" ON public.marcas;
CREATE POLICY "Admin gestiona marcas" ON public.marcas
    FOR ALL USING (
      EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'admin')
    )
    WITH CHECK (
      EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'admin')
    );

-- 4. Trigger para updated_at
CREATE TRIGGER trg_marcas_updated_at
    BEFORE UPDATE ON public.marcas
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5. Agregar marca_id a productos
ALTER TABLE public.productos
ADD COLUMN IF NOT EXISTS marca_id UUID REFERENCES public.marcas(id) ON DELETE SET NULL;

-- 6. Índice para marca_id
CREATE INDEX IF NOT EXISTS idx_productos_marca ON public.productos(marca_id);

-- 7. Actualizar RPC editar_producto_con_motivo para incluir marca_id
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
    marca_id = CASE WHEN p_data ? 'marca_id' THEN NULLIF(p_data->>'marca_id','')::uuid ELSE marca_id END,
    ubicacion = CASE WHEN p_data ? 'ubicacion' THEN NULLIF(p_data->>'ubicacion','') ELSE ubicacion END,
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
