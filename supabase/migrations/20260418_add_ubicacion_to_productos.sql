-- Añadir columna ubicacion a la tabla productos
ALTER TABLE public.productos 
ADD COLUMN ubicacion TEXT;

-- Actualizar comentarios
COMMENT ON COLUMN public.productos.ubicacion IS 'Ubicación física del producto en el anaquel o estante';

-- Crear índice para agilizar el filtrado por ubicación
CREATE INDEX IF NOT EXISTS idx_productos_ubicacion ON public.productos(ubicacion);
