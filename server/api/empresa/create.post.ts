export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const { nombre, email, password } = body

  if (!nombre || !email || !password) {
    throw createError({ statusCode: 400, message: 'Todos los campos son requeridos' })
  }

  const admin = useSupabaseAdmin()

  // 1. Crear usuario en Auth con metadata (el trigger crea el perfil)
  const { error: userError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      nombre,
      rol: 'admin'
    }
  })

  if (userError) {
    throw createError({ statusCode: 500, message: userError.message })
  }

  return { success: true }
})
