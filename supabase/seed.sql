-- ============================================
-- MOTOSYS - Datos de Semilla de Pruebas (Seed) - UUIDs Válidos
-- ============================================

-- 1. Insertar Marcas base
INSERT INTO public.marcas (id, nombre) VALUES
  ('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'Yamaha'),
  ('b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e', 'Suzuki'),
  ('c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f', 'Kenda'),
  ('d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a', 'Motul')
ON CONFLICT (nombre) DO NOTHING;

-- 2. Insertar Métodos de Pago base
INSERT INTO public.metodos_pago (id, nombre, moneda, activo, requiere_detalle) VALUES
  ('12345678-1234-1234-1234-123456789012', 'Efectivo USD', 'USD', true, false),
  ('23456789-2345-2345-2345-234567890123', 'Pago Móvil (Bs)', 'VES', true, true),
  ('34567890-3456-3456-3456-345678901234', 'Transferencia Bs', 'VES', true, true),
  ('45678901-4567-4567-4567-456789012345', 'Efectivo COP', 'COP', true, false)
ON CONFLICT (id) DO NOTHING;

-- 3. Insertar Proveedores de prueba
INSERT INTO public.proveedores (id, nombre, telefono, direccion) VALUES
  ('a0a0a0a0-0000-0000-0000-000000000001', 'Distribuidora Repuestos Moto-Centro', '+58 212-5551234', 'Av. Principal de Bello Monte, Caracas'),
  ('b0b0b0b0-0000-0000-0000-000000000002', 'Suministros Totales V-Twin', '+58 241-8889900', 'Zona Industrial de Valencia, Edo. Carabobo')
ON CONFLICT (nombre) DO NOTHING;

-- 4. Insertar Productos base con stock inicial
INSERT INTO public.productos (id, nombre, codigo_parte, stock, precio_venta, activo, marca_id, ubicacion) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'Caucho Kenda 90/90-18 (Pistol)', 'K-909018', 25, 45.00, true, 'c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f', 'Estante A-4'),
  ('550e8400-e29b-41d4-a716-446655440001', 'Pastillas de Freno Delanteras MD', 'PA-MD123', 50, 12.50, true, 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e', 'Estante B-12'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Aceite Motul 5100 15W50 1L', 'AC-MOT15W50', 80, 15.00, true, 'd4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a', 'Estante C-2'),
  ('550e8400-e29b-41d4-a716-446655440003', 'Kit de Transmisión FZ-16', 'KT-FZ16', 15, 35.00, true, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'Estante D-6')
ON CONFLICT (codigo_parte) DO NOTHING;
