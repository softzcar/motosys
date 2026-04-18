import Dexie, { type Table } from 'dexie';
import type { Producto, Cliente, Perfil } from '~/types/database';
import { useNetworkStore } from '~/stores/network';

export interface VentaOffline {
  id_temporal: string;
  items: any[];
  pagos: any[];
  cliente_id?: string;
  client_data?: any;
  fecha: string;
  sincronizada: boolean;
  total: number;
}

export class MotoSysDatabase extends Dexie {
  productos!: Table<Producto>;
  clientes!: Table<Cliente>;
  tasas!: Table<any>;
  metodos_pago!: Table<any>;
  ventas_pendientes!: Table<VentaOffline>;
  perfil!: Table<Perfil>; // Usuario actualmente activo (sesión)
  profiles_cache!: Table<Perfil>; // Bóveda de usuarios autorizados (persiste al logout)

  constructor() {
    super('MotoSysDB_v2');
    this.version(3).stores({
      productos: 'id, nombre, codigo_parte, categoria_id, ubicacion',
      clientes: 'id, cedula, nombre',
      tasas: 'codigo', 
      metodos_pago: 'id, nombre, moneda',
      ventas_pendientes: 'id_temporal, fecha, sincronizada',
      perfil: 'id',
      profiles_cache: 'email' // Identificamos por email para el login offline
    });
  }
}

export const db = new MotoSysDatabase();

export const useOfflineDb = () => {
  const networkStore = useNetworkStore();

  const cachePerfil = async (p: Perfil) => {
    // 1. Guardar como sesión activa
    await db.perfil.clear();
    await db.perfil.add(p);
    // 2. Guardar en la bóveda permanente para login offline
    if (p.email) {
      await db.profiles_cache.put(p);
    }
  };

  const getLocalPerfil = async () => {
    return await db.perfil.toCollection().first();
  };

  const getAuthorizedProfile = async (email: string) => {
    return await db.profiles_cache.get(email);
  };

  const cacheProductos = async (prods: Producto[]) => {
    await db.productos.clear();
    await db.productos.bulkAdd(prods);
  };

  const cacheClientes = async (clients: Cliente[]) => {
    await db.clientes.clear();
    await db.clientes.bulkAdd(clients);
  };

  const cacheTasas = async (tasas: any[]) => {
    await db.tasas.clear();
    await db.tasas.bulkAdd(tasas);
  };

  const cacheMetodos = async (metodos: any[]) => {
    await db.metodos_pago.clear();
    await db.metodos_pago.bulkAdd(metodos);
  };

  const registrarVentaOffline = async (venta: Omit<VentaOffline, 'sincronizada' | 'id_temporal'>) => {
    const id_temporal = `OFF-${Date.now()}`;
    await db.ventas_pendientes.add({
      ...venta,
      id_temporal,
      sincronizada: false
    });
    return id_temporal;
  };

  return {
    isOnline: computed(() => networkStore.isOnline),
    cacheProductos,
    cacheClientes,
    cacheTasas,
    cacheMetodos,
    cachePerfil,
    getLocalPerfil,
    getAuthorizedProfile,
    registrarVentaOffline
  };
};
