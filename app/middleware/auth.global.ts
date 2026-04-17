export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser()
  const publicRoutes = ['/login', '/register', '/forgot-password', '/reset-password']
  const isPublic = publicRoutes.includes(to.path)

  if (!user.value && !isPublic) {
    return navigateTo('/login')
  }

  if (user.value && isPublic) {
    return navigateTo('/')
  }
})
