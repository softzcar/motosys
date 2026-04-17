-- Añadir columna activo a la tabla productos
ALTER TABLE public.productos 
ADD COLUMN activo BOOLEAN NOT NULL DEFAULT true;

-- Actualizar comentarios de la tabla
COMMENT ON COLUMN public.productos.activo IS 'Indica si el producto está disponible para la venta y operaciones activas';
