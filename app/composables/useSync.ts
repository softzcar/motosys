import { useNetworkStore } from '~/stores/network'
import { db } from './useOfflineDb'

export const useSync = () => {
  const networkStore = useNetworkStore()
  const { procesarVenta } = useVentas()
  const { crearCliente, getClienteByCedula, fetchClientes } = useClientes()
  const { fetchProductos } = useProductos()
  const { fetchTasas } = useTasas()
  const { fetchMetodosPago } = useMetodosPago()
  const { cacheProductos, cacheClientes, cacheTasas, cacheMetodos, purgeOldData } = useOfflineDb()
  const toast = useToast()

  const syncMasterData = async () => {
    if (!networkStore.isOnline) return
    console.log('[SyncEngine] Sincronizando catálogo maestro...')
    try {
      // 1. Productos (Máx 1000 activos)
      const { data: pData } = await fetchProductos({ rows: 1000, soloActivos: true })
      if (pData) await cacheProductos(pData)

      // 2. Clientes (Frecuentes)
      const { data: cData } = await fetchClientes({ rows: 500 })
      if (cData) await cacheClientes(cData)

      // 3. Tasas
      const tData = await fetchTasas()
      if (tData) await cacheTasas(tData)

      // 4. Métodos
      const mData = await fetchMetodosPago()
      if (mData) await cacheMetodos(mData.filter(m => m.activo))

      // Aprovechar el sync de catálogo para purgar datos viejos
      await purgeOldData()

      console.log('[SyncEngine] ✅ Catálogo maestro actualizado localmente')
    } catch (e) {
      console.error('[SyncEngine] Error sincronizando catálogo:', e)
    }
  }

  const syncPendingSales = async () => {
    // 1. Intentar adquirir el bloqueo de forma síncrona
    if (!networkStore.acquireSyncLock()) return

    try {
      // 2. Verificar internet real
      if (!networkStore.isOnline) {
        networkStore.releaseSyncLock()
        return
      }

      // 3. Buscar ventas no sincronizadas
      const todas = await db.ventas_pendientes.toArray()
      const pendientes = todas.filter(v => !v.sincronizada)
      
      if (pendientes.length === 0) {
        // Aun si no hay pendientes, intentamos purgar si hay internet
        await purgeOldData()
        networkStore.releaseSyncLock()
        return
      }

      console.log(`[SyncEngine] Iniciando sincronización de ${pendientes.length} facturas...`)
      let exitos = 0

      for (const v of pendientes) {
        // Marcamos localmente ANTES de enviar para evitar duplicados en UI
        await db.ventas_pendientes.update(v.id_temporal, { sincronizada: true })

        try {
          let finalClientId = v.cliente_id

          if (v.client_data && !finalClientId) {
            try {
              const newClient = await crearCliente({
                cedula: v.client_data.cedula,
                nombre: v.client_data.nombre,
                telefono: v.client_data.telefono
              })
              finalClientId = newClient.id
            } catch (err: any) {
              const existing = await getClienteByCedula(v.client_data.cedula)
              finalClientId = existing?.id
            }
          }
          
          const { perfil } = usePerfil()
          await procesarVenta(v.items, v.pagos, finalClientId!, undefined, perfil.value?.id)
          // Ya no eliminamos inmediatamente para permitir historial local (Purga se encarga después)
          exitos++
        } catch (error) {
          await db.ventas_pendientes.update(v.id_temporal, { sincronizada: false })
          console.error(`[SyncEngine] Error en factura ${v.id_temporal}:`, error)
        }
      }

      if (exitos > 0) {
        await purgeOldData()
        toast.add({ 
          severity: 'success', 
          summary: 'Sincronización Completada', 
          detail: `Se han subido ${exitos} facturas con éxito.`, 
          life: 5000 
        })
      }
    } catch (e: any) {
      console.error('[SyncEngine] Fallo en el motor:', e)
    } finally {
      // 4. Liberar bloqueo con un margen de seguridad
      setTimeout(() => {
        networkStore.releaseSyncLock()
      }, 2000)
    }
  }

  return { syncPendingSales, syncMasterData }
}
