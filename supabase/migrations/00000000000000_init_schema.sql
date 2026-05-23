-- ============================================
-- MOTOSYS - Esquema Completo Consolidado (Local)
-- ============================================

-- 1. EXTENSIONES Y FUNCIONES DE SEGURIDAD
-- --------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trigger de updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 2. TABLAS BASE
-- --------------------------------------------

-- Perfiles de usuario
CREATE TABLE IF NOT EXISTS perfiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL CHECK (rol IN ('admin', 'vendedor')) DEFAULT 'vendedor',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Marcas
CREATE TABLE IF NOT EXISTS marcas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Productos
CREATE TABLE IF NOT EXISTS productos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  codigo_parte TEXT NOT NULL UNIQUE,
  stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
  precio_venta DECIMAL(12,2) NOT NULL CHECK (precio_venta >= 0),
  imagen_url TEXT,
  activo BOOLEAN NOT NULL DEFAULT true,
  marca_id UUID REFERENCES marcas(id) ON DELETE SET NULL,
  categoria_id UUID, -- Agregada en migraciones de categorias
  ubicacion TEXT, -- Agregada en migraciones
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Clientes
CREATE TABLE IF NOT EXISTS clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cedula TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  telefono TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Proveedores
CREATE TABLE IF NOT EXISTS proveedores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL UNIQUE,
  telefono TEXT,
  direccion TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Métodos de Pago
CREATE TABLE IF NOT EXISTS metodos_pago (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  moneda TEXT NOT NULL DEFAULT 'USD',
  activo BOOLEAN NOT NULL DEFAULT true,
  requiere_detalle BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Tasas de Cambio
CREATE TABLE IF NOT EXISTS tasas_cambio (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  tasa DECIMAL(14,4) NOT NULL DEFAULT 1 CHECK (tasa > 0),
  is_auto BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Cierres de caja (Cabecera)
CREATE TABLE IF NOT EXISTS cierres_caja (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha DATE NOT NULL UNIQUE,
  fecha_hora_cierre TIMESTAMPTZ NOT NULL DEFAULT now(),
  responsable_id UUID NOT NULL REFERENCES auth.users(id),
  total_sistema_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_contado_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  diferencia_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  observaciones TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Ventas (Cabecera)
CREATE TABLE IF NOT EXISTS ventas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero BIGINT GENERATED ALWAYS AS IDENTITY,
  vendedor_id UUID NOT NULL REFERENCES auth.users(id),
  cliente_id UUID REFERENCES clientes(id) ON DELETE RESTRICT,
  cierre_id UUID REFERENCES cierres_caja(id) ON DELETE SET NULL,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  anulada BOOLEAN NOT NULL DEFAULT false,
  motivo_anulacion TEXT,
  anulada_por UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  anulada_at TIMESTAMPTZ,
  corrige_venta_id UUID,
  fecha TIMESTAMPTZ DEFAULT now()
);

-- Detalle Ventas
CREATE TABLE IF NOT EXISTS detalle_ventas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venta_id UUID NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
  producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE RESTRICT,
  cantidad INT NOT NULL CHECK (cantidad > 0),
  precio_unitario DECIMAL(12,2) NOT NULL CHECK (precio_unitario >= 0)
);

-- Ventas Pagos (Detalle de métodos de cobro en ventas)
CREATE TABLE IF NOT EXISTS ventas_pagos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venta_id UUID NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
  metodo_pago_id UUID NOT NULL REFERENCES metodos_pago(id) ON DELETE RESTRICT,
  monto_recibido DECIMAL(12,2) NOT NULL CHECK (monto_recibido >= 0),
  tasa_aplicada DECIMAL(14,4) NOT NULL DEFAULT 1,
  monto_usd DECIMAL(12,2) NOT NULL DEFAULT 0,
  referencia TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Movimientos de Caja
CREATE TABLE IF NOT EXISTS movimientos_caja (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cierre_id UUID REFERENCES cierres_caja(id) ON DELETE SET NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('ingreso', 'egreso')),
  concepto TEXT NOT NULL,
  monto DECIMAL(14,2) NOT NULL CHECK (monto > 0),
  tasa_bcv DECIMAL(14,4) NOT NULL DEFAULT 1,
  monto_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  metodo_pago_id UUID NOT NULL REFERENCES metodos_pago(id) ON DELETE RESTRICT,
  usuario_id UUID NOT NULL REFERENCES auth.users(id),
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Cierres de caja Detalle
CREATE TABLE IF NOT EXISTS cierres_caja_detalle (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cierre_id UUID NOT NULL REFERENCES cierres_caja(id) ON DELETE CASCADE,
  metodo_pago_id UUID NOT NULL REFERENCES metodos_pago(id) ON DELETE RESTRICT,
  monto_sistema DECIMAL(14,2) NOT NULL DEFAULT 0,
  monto_contado DECIMAL(14,2) NOT NULL DEFAULT 0,
  diferencia DECIMAL(14,2) NOT NULL DEFAULT 0,
  monto_sistema_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  monto_contado_usd DECIMAL(14,2) NOT NULL DEFAULT 0,
  tasa_referencia DECIMAL(14,4) NOT NULL DEFAULT 1,
  UNIQUE (cierre_id, metodo_pago_id)
);

-- Compras (Cabecera)
CREATE TABLE IF NOT EXISTS compras (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero BIGINT GENERATED ALWAYS AS IDENTITY,
  numero_factura TEXT NOT NULL,
  fecha DATE NOT NULL,
  id_proveedor UUID NOT NULL REFERENCES proveedores(id) ON DELETE RESTRICT,
  descuento DECIMAL(5,2) NOT NULL DEFAULT 0 CHECK (descuento >= 0 AND descuento <= 100),
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
  iva DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  anulada BOOLEAN NOT NULL DEFAULT false,
  motivo_anulacion TEXT,
  anulada_por UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  anulada_at TIMESTAMPTZ,
  corrige_compra_id UUID REFERENCES compras(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Detalle Compras
CREATE TABLE IF NOT EXISTS detalle_compras (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_compra UUID NOT NULL REFERENCES compras(id) ON DELETE CASCADE,
  id_producto UUID NOT NULL REFERENCES productos(id) ON DELETE RESTRICT,
  cantidad INT NOT NULL CHECK (cantidad > 0),
  costo_unitario DECIMAL(12,2) NOT NULL CHECK (costo_unitario >= 0),
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0
);

-- Auditoría de Inventario
CREATE TABLE IF NOT EXISTS inventario_auditoria (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id UUID NOT NULL,
  codigo_parte TEXT NOT NULL,
  nombre TEXT NOT NULL,
  accion TEXT NOT NULL,
  motivo TEXT NOT NULL,
  valor_anterior JSONB,
  valor_nuevo JSONB,
  usuario_id UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. INDICES
-- --------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_ventas_numero ON ventas(numero);
CREATE UNIQUE INDEX IF NOT EXISTS idx_compras_numero ON compras(numero);
CREATE INDEX IF NOT EXISTS idx_productos_codigo ON productos(codigo_parte);
CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos(activo);
CREATE INDEX IF NOT EXISTS idx_productos_marca ON productos(marca_id);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha);
CREATE INDEX IF NOT EXISTS idx_ventas_cierre ON ventas(cierre_id);
CREATE INDEX IF NOT EXISTS idx_ventas_vendedor ON ventas(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_detalle_venta ON detalle_ventas(venta_id);
CREATE INDEX IF NOT EXISTS idx_clientes_cedula ON clientes(cedula);
CREATE INDEX IF NOT EXISTS idx_cierres_responsable ON cierres_caja(responsable_id);
CREATE INDEX IF NOT EXISTS idx_cierres_det_cierre ON cierres_caja_detalle(cierre_id);
CREATE INDEX IF NOT EXISTS idx_compras_anulada ON compras(anulada);
CREATE INDEX IF NOT EXISTS idx_compras_corrige ON compras(corrige_compra_id);

-- 4. TRIGGERS AUTOMÁTICOS
-- --------------------------------------------
CREATE TRIGGER trg_perfiles_updated_at BEFORE UPDATE ON perfiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_productos_updated_at BEFORE UPDATE ON productos FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_clientes_updated_at BEFORE UPDATE ON clientes FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_proveedores_updated_at BEFORE UPDATE ON proveedores FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_metodos_pago_updated_at BEFORE UPDATE ON metodos_pago FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_marcas_updated_at BEFORE UPDATE ON marcas FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_compras_updated_at BEFORE UPDATE ON compras FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5. SEGURIDAD Y RLS
-- --------------------------------------------
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'
  )
$$;

ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE metodos_pago ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasas_cambio ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas_pagos ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierres_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierres_caja_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE compras ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_compras ENABLE ROW LEVEL SECURITY;
ALTER TABLE marcas ENABLE ROW LEVEL SECURITY;

-- Políticas de Acceso Público / Lectura General
CREATE POLICY "Lectura perfiles" ON perfiles FOR SELECT USING (true);
CREATE POLICY "Lectura marcas" ON marcas FOR SELECT USING (true);
CREATE POLICY "Lectura productos" ON productos FOR SELECT USING (true);
CREATE POLICY "Lectura clientes" ON clientes FOR SELECT USING (true);
CREATE POLICY "Lectura proveedores" ON proveedores FOR SELECT USING (true);
CREATE POLICY "Lectura metodos" ON metodos_pago FOR SELECT USING (true);
CREATE POLICY "Lectura tasas" ON tasas_cambio FOR SELECT USING (true);
CREATE POLICY "Lectura ventas" ON ventas FOR SELECT USING (true);
CREATE POLICY "Lectura detalles_v" ON detalle_ventas FOR SELECT USING (true);
CREATE POLICY "Lectura pagos_v" ON ventas_pagos FOR SELECT USING (true);
CREATE POLICY "Lectura movimientos" ON movimientos_caja FOR SELECT USING (true);
CREATE POLICY "Lectura cierres" ON cierres_caja FOR SELECT USING (true);
CREATE POLICY "Lectura cierres_det" ON cierres_caja_detalle FOR SELECT USING (true);
CREATE POLICY "Lectura compras" ON compras FOR SELECT USING (true);
CREATE POLICY "Lectura detalles_c" ON detalle_compras FOR SELECT USING (true);

-- Políticas de Escritura para Usuarios / Admin
CREATE POLICY "Escritura perfiles admin" ON perfiles FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura marcas admin" ON marcas FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura productos admin" ON productos FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura clientes usuarios" ON clientes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Escritura proveedores admin" ON proveedores FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura metodos admin" ON metodos_pago FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura tasas admin" ON tasas_cambio FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura ventas usuarios" ON ventas FOR INSERT WITH CHECK (true);
CREATE POLICY "Escritura ventas admin" ON ventas FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura detalles_v usuarios" ON detalle_ventas FOR INSERT WITH CHECK (true);
CREATE POLICY "Escritura pagos_v usuarios" ON ventas_pagos FOR INSERT WITH CHECK (true);
CREATE POLICY "Escritura movimientos usuarios" ON movimientos_caja FOR INSERT WITH CHECK (true);
CREATE POLICY "Escritura cierres admin" ON cierres_caja FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura cierres_det admin" ON cierres_caja_detalle FOR ALL USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura compras usuarios" ON compras FOR INSERT WITH CHECK (true);
CREATE POLICY "Escritura compras admin" ON compras FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "Escritura detalles_c usuarios" ON detalle_compras FOR INSERT WITH CHECK (true);

-- 6. REGISTRO Y DISPARADORES AUTOMÁTICOS EN AUTH
-- --------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 7. BUCKETS DE ALMACENAMIENTO (STORAGE)
-- --------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Lectura imagenes publicas" ON storage.objects FOR SELECT USING (bucket_id = 'product-images');
CREATE POLICY "Escritura imagenes admin" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product-images' AND is_admin());
CREATE POLICY "Eliminacion imagenes admin" ON storage.objects FOR DELETE USING (bucket_id = 'product-images' AND is_admin());
