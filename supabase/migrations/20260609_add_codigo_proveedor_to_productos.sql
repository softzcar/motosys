-- Añadir columna codigo_proveedor a la tabla productos
ALTER TABLE public.productos 
ADD COLUMN IF NOT EXISTS codigo_proveedor TEXT;

-- Copiar los valores existentes de codigo_parte a codigo_proveedor
UPDATE public.productos 
SET codigo_proveedor = codigo_parte 
WHERE codigo_proveedor IS NULL;

-- Comentario explicativo
COMMENT ON COLUMN public.productos.codigo_proveedor IS 'Código de parte asignado por el proveedor (opcional)';
