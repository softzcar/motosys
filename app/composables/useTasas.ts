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
    if (typeof navigator !== 'undefined' && !navigator.onLine) return;
    
    try {
      const response = await fetch('https://ve.dolarapi.com/v1/dolares')
      const data = await response.json()
      
      const bcvData = data.find((d: any) => d.fuente === 'oficial')
      
      if (bcvData && bcvData.promedio) {
        // Redondear la tasa devuelta a exactamente 2 decimales
        const roundedRate = Number(bcvData.promedio.toFixed(2))

        await client
          .from('tasas_cambio')
          .update({
             tasa: roundedRate,
             updated_at: new Date().toISOString()
          })
          .eq('codigo', 'BCV')
      }
    } catch (e) {
      console.error('Error sincronizando tasa BCV:', e)
    }
  }

  // Obtiene todas las tasas desde la DB
  const fetchTasas = async () => {
    const { data, error } = await client
      .from('tasas_cambio')
      .select('*')
      .order('codigo', { ascending: true })

    if (error) throw error
    return data as TasaCambio[]
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
