import { useSupabaseClient } from '#imports'

export interface MetodoPago {
  id: string
  nombre: string
  moneda: string
  activo: boolean
  requiere_detalle: boolean
}

export const useMetodosPago = () => {
  const client = useSupabaseClient()

  const fetchMetodosPago = async () => {
    const { data, error } = await client
      .from('metodos_pago')
      .select('*')
      .order('activo', { ascending: false })
      .order('nombre', { ascending: true })

    if (error) throw error
    return data as MetodoPago[]
  }

  const createMetodoPago = async (metodo: Omit<MetodoPago, 'id'>) => {
    const { data, error } = await client
      .from('metodos_pago')
      .insert([metodo])
      .select()
      .single()

    if (error) throw error
    return data as MetodoPago
  }

  const updateMetodoPago = async (id: string, metodo: Partial<MetodoPago>) => {
    const { data, error } = await client
      .from('metodos_pago')
      .update(metodo)
      .eq('id', id)
      .select()
      .single()

    if (error) throw error
    return data as MetodoPago
  }

  const deleteMetodoPago = async (id: string) => {
    const { data, error } = await client
      .from('metodos_pago')
      .delete()
      .eq('id', id)
      .select()

    if (error) throw error
    return data
  }

  return { fetchMetodosPago, createMetodoPago, updateMetodoPago, deleteMetodoPago }
}
