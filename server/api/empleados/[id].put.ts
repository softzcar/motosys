import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'
import { useSupabaseAdmin } from '../../utils/supabase-admin'

export default defineEventHandler(async (event) => {
  const client = await serverSupabaseClient(event)
  const user = await serverSupabaseUser(event)
  const userId = user?.id || user?.sub
  if (!userId) throw createError({ statusCode: 401, message: 'No autenticado o sesión expirada' })

  const id = getRouterParam(event, 'id')
  if (!id) throw createError({ statusCode: 400, message: 'ID requerido' })

  const body = await readBody(event)
  const { nombre, rol, email, password } = body

  const admin = useSupabaseAdmin()

  // Verificar admin caller
  const { data: caller, error: callerErr } = await admin
    .from('perfiles')
    .select('rol')
    .eq('id', userId)
    .single()
  
  if (callerErr || !caller) throw createError({ statusCode: 403, message: 'Perfil no encontrado' })
  if (caller.rol !== 'admin') throw createError({ statusCode: 403, message: 'Solo un administrador puede editar empleados' })

  // Preparar actualizacion
  const authUpdates: any = {}
  if (email && email.trim()) authUpdates.email = email.trim().toLowerCase()
  if (password && password.trim()) authUpdates.password = password

  // Actualizar auth.users si hay datos
  if (Object.keys(authUpdates).length > 0) {
    const { error: authErr } = await admin.auth.admin.updateUserById(id, authUpdates)
    if (authErr) {
      if (/already registered|already exists|duplicate/i.test(authErr.message)) {
        throw createError({ statusCode: 409, message: 'Ya existe un usuario con ese correo' })
      }
      throw createError({ statusCode: 500, message: authErr.message || 'No se pudo actualizar credenciales' })
    }
  }

  // Actualizar perfiles
  const perfilUpdates: any = {}
  if (nombre !== undefined && nombre.trim()) perfilUpdates.nombre = nombre.trim()
  if (rol !== undefined) perfilUpdates.rol = rol

  if (Object.keys(perfilUpdates).length > 0) {
    const { data: updated, error: pErr } = await admin.from('perfiles')
      .update(perfilUpdates)
      .eq('id', id)
      .select()
      .single()

    if (pErr) throw createError({ statusCode: 500, message: 'Error actualizando perfil' })
    return updated
  }

  return { success: true }
})
