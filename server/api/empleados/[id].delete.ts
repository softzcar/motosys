import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'

export default defineEventHandler(async (event) => {
  const client = await serverSupabaseClient(event)
  const user = await serverSupabaseUser(event)
  const userId = user?.id || user?.sub
  if (!userId) throw createError({ statusCode: 401, message: 'No autenticado o sesión expirada' })

  const id = getRouterParam(event, 'id')
  if (!id) throw createError({ statusCode: 400, message: 'ID requerido' })
  if (id === userId) throw createError({ statusCode: 400, message: 'No puedes eliminarte a ti mismo' })

  const admin = useSupabaseAdmin()

  // Verificar que el solicitante es admin
  const { data: caller, error: callerErr } = await admin
    .from('perfiles')
    .select('rol')
    .eq('id', userId)
    .single()
  if (callerErr || !caller) throw createError({ statusCode: 403, message: 'Perfil no encontrado' })
  if (caller.rol !== 'admin') throw createError({ statusCode: 403, message: 'Solo un administrador puede eliminar empleados' })

  // Verificar que el empleado existe
  const { data: target, error: targetErr } = await admin
    .from('perfiles')
    .select('id')
    .eq('id', id)
    .single()
  if (targetErr || !target) throw createError({ statusCode: 404, message: 'Empleado no encontrado' })

  // Eliminar usuario en auth (cascade elimina perfil)
  const { error: delErr } = await admin.auth.admin.deleteUser(id)
  
  if (delErr) {
    const errorMsg = delErr.message.toLowerCase()
    if (errorMsg.includes('database error') || errorMsg.includes('foreign key')) {
      throw createError({ 
        statusCode: 409, 
        message: 'No se puede eliminar permanentemente este empleado porque tiene registros (ventas, compras o cierres) asociados. Se recomienda desactivarlo.' 
      })
    }
    throw createError({ statusCode: 500, message: delErr.message })
  }

  return { success: true }
})
