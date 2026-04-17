<template>
  <div class="min-h-screen flex items-center justify-center bg-slate-50 px-4">
    <div class="w-full max-w-md">
      <div class="text-center mb-8 flex flex-col items-center">
        <img src="/android-icon-192x192.png" alt="MotoSys Logo" class="w-24 h-24 mb-4 object-contain" />
        <p class="text-slate-500 font-bold text-sm tracking-tight">Motorepuestos Accesorios y Lubricantes Parra</p>
      </div>
      <div class="bg-white rounded-xl shadow-lg p-8">
        <slot />
      </div>
    </div>
  </div>
</template>
