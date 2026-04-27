TRUNCATE TABLE 
     -- 1. Ventas y Pagos
     public.ventas, 
     public.detalle_ventas, 
     public.ventas_pagos, 
     -- 2. Compras y Proveedores
     public.compras, 
     public.detalle_compras, 
     public.proveedores,
     -- 3. Inventario
     public.productos,
     public.categorias_productos,
     public.inventario_auditoria,
     -- 4. Caja y Cierres
     public.movimientos_caja, 
     public.cierres_caja, 
     public.cierres_caja_detalle,
     -- 5. Otros
     public.clientes,
     public.tasas_cambio
 RESTART IDENTITY CASCADE;
