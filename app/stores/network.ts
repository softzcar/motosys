import { defineStore } from 'pinia'
import { useNetwork } from '@vueuse/core'

export const useNetworkStore = defineStore('network', () => {
  const isOnline = ref(true)
  const isSyncing = ref(false)
  const pendingCount = ref(0)
  
  const network = useNetwork()
  const client = useSupabaseClient()

  // Verificación real de internet (Heartbeat)
  const checkRealConnection = async () => {
    if (!network.isOnline.value) {
      isOnline.value = false
      return
    }

    try {
      const { error } = await client.from('empresa').select('id').limit(1).maybeSingle()
      isOnline.value = !error
    } catch {
      isOnline.value = false
    }
  }

  watch(network.isOnline, (online) => {
    if (online) checkRealConnection()
    else isOnline.value = false
  })

  let timer: any = null
  const startHeartbeat = () => {
    if (timer) return
    checkRealConnection()
    timer = setInterval(checkRealConnection, 30000)
  }

  // SEMÁFORO DE CONTROL: Solo permite una sincronización a la vez
  const acquireSyncLock = () => {
    if (isSyncing.value) return false
    isSyncing.value = true
    return true
  }

  const releaseSyncLock = () => {
    isSyncing.value = false
  }

  return { isOnline, isSyncing, pendingCount, startHeartbeat, acquireSyncLock, releaseSyncLock }
})
