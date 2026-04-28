import { useSupabaseClient } from '#imports'

export interface TasaCambio {
  codigo: 'BCV' | 'PARALELO' | 'COP'
  nombre: string
  tasa: number
  is_auto: boolean
  updated_at: string
}

export const useTasas = () => {
  const client = useSupabaseClient()

  // Sincroniza la tasa oficial del BCV llamando a la API
  const syncBcvRate = async () => {
    // Si estamos offline, no intentamos sincronizar para evitar errores
    if (import.meta.client && !navigator.onLine) return;
    
    try {
      const response = await fetch('https://ve.dolarapi.com/v1/dolares')
      const data = await response.json()
      
      const bcvData = data.find((d: any) => d.fuente === 'oficial')
      
      if (bcvData && bcvData.promedio) {
        const roundedRate = Number(bcvData.promedio.toFixed(2))

        // Usar upsert para crear si no existe
        await client
          .from('tasas_cambio')
          .upsert({
             codigo: 'BCV',
             nombre: 'Dólar BCV',
             tasa: roundedRate,
             is_auto: true,
             updated_at: new Date().toISOString()
          }, { onConflict: 'codigo' })
      }
    } catch (e) {
      console.warn('Error sincronizando tasa BCV:', e)
    }
  }

  // Obtiene todas las tasas desde la DB
  const fetchTasas = async () => {
    try {
      const { data, error } = await client
        .from('tasas_cambio')
        .select('*')
        .order('codigo', { ascending: true })

      if (error) throw error

      // Si no hay datos, intentar inicializar (solo si es admin o si el RLS lo permite)
      if (!data || data.length === 0) {
        console.log('🔄 Inicializando tasas base...')
        const defaultTasas = [
          { codigo: 'BCV', nombre: 'Dólar BCV', tasa: 36.50, is_auto: true },
          { codigo: 'PARALELO', nombre: 'Dólar Paralelo', tasa: 40.00, is_auto: false },
          { codigo: 'COP', nombre: 'Peso Colombiano', tasa: 3900.00, is_auto: false }
        ]
        
        const { data: inserted, error: insError } = await client
          .from('tasas_cambio')
          .upsert(defaultTasas, { onConflict: 'codigo' })
          .select()

        if (insError) {
          console.warn('No se pudieron inicializar las tasas automáticamente (posible falta de permisos).')
          return []
        }
        
        // Intentar sincronizar BCV de una vez si acabamos de insertar
        await syncBcvRate()
        return inserted as TasaCambio[]
      }

      return data as TasaCambio[]
    } catch (e) {
      console.error('Error en fetchTasas:', e)
      return []
    }
  }

  // Actualiza una tasa manual (ej. Paralelo o COP)
  const updateTasa = async (codigo: string, tasaValue: number) => {
    const { data, error } = await client
      .from('tasas_cambio')
      .update({
         tasa: tasaValue,
         updated_at: new Date().toISOString()
      })
      .eq('codigo', codigo)
      .select()
      .single()

    if (error) throw error
    return data as TasaCambio
  }

  return { syncBcvRate, fetchTasas, updateTasa }
}
