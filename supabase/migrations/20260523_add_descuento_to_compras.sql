-- Migración: Añadir columna de descuento a la tabla de compras
-- Creado el: 2026-05-23

-- Agregar columna descuento a la tabla compras
ALTER TABLE compras 
ADD COLUMN IF NOT EXISTS descuento DECIMAL(5,2) NOT NULL DEFAULT 0 CHECK (descuento >= 0 AND descuento <= 100);

-- Si existen funciones RPC asociadas que requieran regeneración (no es el caso ya que la RPC anular_compra usa p_compra_id),
-- de lo contrario este DDL es completamente seguro y compatible.
