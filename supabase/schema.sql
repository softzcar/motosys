-- ============================================
-- MOTOSYS - Schema Mono-Empresa
-- ============================================

-- 1. TABLAS
-- --------------------------------------------

CREATE TABLE perfiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL CHECK (rol IN ('admin', 'vendedor')) DEFAULT 'vendedor',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE productos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  codigo_parte TEXT NOT NULL UNIQUE,
  stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
  precio_venta DECIMAL(12,2) NOT NULL CHECK (precio_venta >= 0),
  imagen_url TEXT,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE ventas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendedor_id UUID NOT NULL REFERENCES auth.users(id),
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  fecha TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE detalle_ventas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venta_id UUID NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
  producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE RESTRICT,
  cantidad INT NOT NULL CHECK (cantidad > 0),
  precio_unitario DECIMAL(12,2) NOT NULL CHECK (precio_unitario >= 0)
);

CREATE TABLE metodos_pago (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  moneda TEXT NOT NULL DEFAULT 'USD',
  activo BOOLEAN NOT NULL DEFAULT true,
  requiere_detalle BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. INDICES
-- --------------------------------------------

CREATE INDEX idx_productos_codigo ON productos(codigo_parte);
CREATE INDEX idx_productos_activo ON productos(activo);
CREATE INDEX idx_ventas_fecha ON ventas(fecha);
CREATE INDEX idx_ventas_vendedor ON ventas(vendedor_id);
CREATE INDEX idx_detalle_venta ON detalle_ventas(venta_id);

-- 3. TRIGGER REUTILIZABLE - updated_at automático
-- --------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_perfiles_updated_at
  BEFORE UPDATE ON perfiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_productos_updated_at
  BEFORE UPDATE ON productos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_metodos_pago_updated_at
  BEFORE UPDATE ON metodos_pago
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 4. FUNCIONES HELPER
-- --------------------------------------------

-- Helper: verificar si el usuario actual es admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'
  )
$$;

-- 5. RLS - Activar en todas las tablas
-- --------------------------------------------

ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE metodos_pago ENABLE ROW LEVEL SECURITY;

-- 6. POLICIES
-- --------------------------------------------

-- == metodos_pago ==
CREATE POLICY "Usuarios ven metodos_pago"
  ON metodos_pago FOR SELECT
  USING (true);

CREATE POLICY "Admin gestiona metodos_pago"
  ON metodos_pago FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- == perfiles ==
CREATE POLICY "Usuarios ven perfiles"
  ON perfiles FOR SELECT
  USING (true);

CREATE POLICY "Admin inserta perfiles"
  ON perfiles FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "Admin actualiza perfiles"
  ON perfiles FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admin elimina perfiles"
  ON perfiles FOR DELETE
  USING (is_admin());

-- == productos ==
CREATE POLICY "Usuarios ven productos activos"
  ON productos FOR SELECT
  USING (activo = true OR is_admin());

CREATE POLICY "Admin crea productos"
  ON productos FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "Admin actualiza productos"
  ON productos FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admin elimina productos"
  ON productos FOR DELETE
  USING (is_admin());

-- == ventas ==
CREATE POLICY "Usuarios ven ventas"
  ON ventas FOR SELECT
  USING (true);

CREATE POLICY "Usuarios crean ventas"
  ON ventas FOR INSERT
  WITH CHECK (true);

-- == detalle_ventas ==
CREATE POLICY "Usuarios ven detalles"
  ON detalle_ventas FOR SELECT
  USING (true);

CREATE POLICY "Usuarios crean detalles"
  ON detalle_ventas FOR INSERT
  WITH CHECK (true);

-- 7. FUNCION RPC - Procesar venta con transacción atómica
-- --------------------------------------------

CREATE OR REPLACE FUNCTION procesar_venta(
  p_items JSONB -- [{"producto_id": "uuid", "cantidad": 2, "precio_unitario": 150.00}, ...]
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

  -- Crear la venta con vendedor_id
  INSERT INTO ventas (vendedor_id, total, fecha)
  VALUES (auth.uid(), v_total, now())
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

-- 8. TRIGGER - Crear perfil automáticamente al registrarse
-- --------------------------------------------

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO perfiles (id, nombre, rol)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nombre', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'rol', 'vendedor')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- 9. STORAGE - Bucket para imágenes de productos
-- Ejecutar en SQL Editor de Supabase
-- --------------------------------------------

INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Usuarios ven imagenes"
  ON storage.objects FOR SELECT
  USING ( bucket_id = 'product-images' );

CREATE POLICY "Admin sube imagenes"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND is_admin()
  );

CREATE POLICY "Admin elimina imagenes"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'product-images'
    AND is_admin()
  );
