-- Crear tabla de clientes
CREATE TABLE clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cedula TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  telefono TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indices
CREATE INDEX idx_clientes_cedula ON clientes(cedula);

-- Trigger para updated_at
CREATE TRIGGER trg_clientes_updated_at
  BEFORE UPDATE ON clientes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RLS
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios ven clientes"
  ON clientes FOR SELECT
  USING (true);

CREATE POLICY "Usuarios crean clientes"
  ON clientes FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Usuarios actualizan clientes"
  ON clientes FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Agregar cliente_id a ventas (opcional al inicio, luego obligatorio o lo dejamos NULL si venta rapida)
-- Como requerimos cliente en POS, lo pondremos NOT NULL tras limpiar la data si existera, pero mejor dejarlo nullable por ahora por compatibilidad, aunque la app obligará.
ALTER TABLE ventas ADD COLUMN cliente_id UUID REFERENCES clientes(id) ON DELETE RESTRICT;

-- Actualizar funcion procesar_venta
DROP FUNCTION IF EXISTS procesar_venta(JSONB);
CREATE OR REPLACE FUNCTION procesar_venta(
  p_items JSONB,
  p_cliente_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_venta_id UUID;
  v_total DECIMAL(12,2) := 0;
  v_item JSONB;
  v_stock_actual INT;
BEGIN
  -- Validar que hay items
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'La venta debe tener al menos un item';
  END IF;

  -- Calcular total
  SELECT COALESCE(SUM((item->>'cantidad')::INT * (item->>'precio_unitario')::DECIMAL), 0)
  INTO v_total
  FROM jsonb_array_elements(p_items) AS item;

  -- Crear la venta con vendedor_id y cliente_id
  INSERT INTO ventas (vendedor_id, cliente_id, total, fecha)
  VALUES (auth.uid(), p_cliente_id, v_total, now())
  RETURNING id INTO v_venta_id;

  -- Procesar cada item
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Verificar stock con bloqueo FOR UPDATE (evita concurrencia)
    SELECT stock INTO v_stock_actual
    FROM productos
    WHERE id = (v_item->>'producto_id')::UUID
      AND activo = true
    FOR UPDATE;

    IF v_stock_actual IS NULL THEN
      RAISE EXCEPTION 'Producto % no encontrado o inactivo', v_item->>'producto_id';
    END IF;

    IF v_stock_actual < (v_item->>'cantidad')::INT THEN
      RAISE EXCEPTION 'Stock insuficiente para producto %. Disponible: %, Solicitado: %',
        v_item->>'producto_id', v_stock_actual, v_item->>'cantidad';
    END IF;

    -- Restar stock
    UPDATE productos
    SET stock = stock - (v_item->>'cantidad')::INT
    WHERE id = (v_item->>'producto_id')::UUID;

    -- Insertar detalle
    INSERT INTO detalle_ventas (venta_id, producto_id, cantidad, precio_unitario)
    VALUES (
      v_venta_id,
      (v_item->>'producto_id')::UUID,
      (v_item->>'cantidad')::INT,
      (v_item->>'precio_unitario')::DECIMAL
    );
  END LOOP;

  RETURN v_venta_id;
END;
$$;
