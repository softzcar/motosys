-- ============================================
-- CREACIÓN DE TABLA CATEGORÍAS DE PRODUCTOS Y POLÍTICAS RLS
-- ============================================

-- 1. Crear la tabla de categorias_productos si no existe
CREATE TABLE IF NOT EXISTS public.categorias_productos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Asegurar que la columna categoria_id existe en productos y tiene su llave foránea
ALTER TABLE public.productos 
  ADD COLUMN IF NOT EXISTS categoria_id UUID REFERENCES public.categorias_productos(id) ON DELETE SET NULL;

-- 3. Habilitar RLS en la tabla
ALTER TABLE public.categorias_productos ENABLE ROW LEVEL SECURITY;

-- 4. Trigger para updated_at automático
DROP TRIGGER IF EXISTS trg_categorias_productos_updated_at ON public.categorias_productos;
CREATE TRIGGER trg_categorias_productos_updated_at 
  BEFORE UPDATE ON public.categorias_productos 
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5. Definir políticas de RLS
-- Lectura: Permitida para todos los usuarios (públicos y autenticados)
DROP POLICY IF EXISTS "Lectura categorias" ON public.categorias_productos;
CREATE POLICY "Lectura categorias" 
  ON public.categorias_productos FOR SELECT 
  USING (true);

-- Inserción: Permitida para cualquier usuario autenticado (para permitir el botón "+" rápido desde el formulario)
DROP POLICY IF EXISTS "Insercion categorias autenticados" ON public.categorias_productos;
CREATE POLICY "Insercion categorias autenticados" 
  ON public.categorias_productos FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

-- Edición/Eliminación: Restringida únicamente al administrador
DROP POLICY IF EXISTS "Modificacion categorias admin" ON public.categorias_productos;
CREATE POLICY "Modificacion categorias admin" 
  ON public.categorias_productos FOR UPDATE 
  USING (is_admin()) 
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Eliminacion categorias admin" ON public.categorias_productos;
CREATE POLICY "Eliminacion categorias admin" 
  ON public.categorias_productos FOR DELETE 
  USING (is_admin());
