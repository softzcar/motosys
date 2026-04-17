import { serverSupabaseUser } from '#supabase/server'

export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event)
  const userId = user?.id || user?.sub
  if (!userId) throw createError({ statusCode: 401, message: 'No autenticado o sesión expirada' })

  const body = await readBody(event)
  const nombre = (body?.nombre ?? '').toString().trim()
  const email = (body?.email ?? '').toString().trim().toLowerCase()
  const password = (body?.password ?? '').toString()
  const rol = body?.rol === 'admin' ? 'admin' : 'vendedor'

  if (!nombre || nombre.length < 3) throw createError({ statusCode: 400, message: 'Nombre inválido' })
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw createError({ statusCode: 400, message: 'Correo inválido' })
  if (password.length < 8) throw createError({ statusCode: 400, message: 'La contraseña debe tener al menos 8 caracteres' })

  const admin = useSupabaseAdmin()

  // Verificar que el solicitante es admin
  const { data: perfilCaller, error: perfilErr } = await admin
    .from('perfiles')
    .select('rol')
    .eq('id', userId)
    .single()

  if (perfilErr || !perfilCaller) throw createError({ statusCode: 403, message: 'Perfil no encontrado' })
  if (perfilCaller.rol !== 'admin') throw createError({ statusCode: 403, message: 'Solo un administrador puede crear empleados' })

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      nombre,
      rol
    }
  })

  if (createErr) {
    const msg = createErr.message || ''
    if (/already registered|already exists|duplicate/i.test(msg)) {
      throw createError({ statusCode: 409, message: 'Ya existe un usuario con ese correo' })
    }
    throw createError({ statusCode: 500, message: msg || 'No se pudo crear el empleado' })
  }

  return { success: true, id: created.user?.id }
})
