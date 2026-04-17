<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import type { Producto, CategoriaProducto } from '~/types/database'

const props = defineProps<{
  producto?: Producto
  loading?: boolean
}>()

const emit = defineEmits<{
  submit: [data: { values: Partial<Producto> }]
  cancel: []
}>()

const { fetchAllCategorias, createCategoria, friendlyError: categoriaFriendlyError } = useCategoriasProductos()

const categorias = ref<CategoriaProducto[]>([])
const loadingCategorias = ref(false)

// Inline category creation modal state
const showCategoriaModal = ref(false)
const newCategoriaNombre = ref('')
const savingCategoria = ref(false)
const categoriaModalError = ref('')

const form = ref({
  nombre: props.producto?.nombre ?? '',
  codigo_parte: props.producto?.codigo_parte ?? '',
  stock: props.producto?.stock ?? 0,
  precio_venta: props.producto?.precio_venta ?? 0,
  categoria_id: props.producto?.categoria_id ?? null as string | null,
  activo: props.producto?.activo ?? true
})

// Sincronizar formulario si el producto cambia (carga inicial)
watch(() => props.producto, (p) => {
  if (p) {
    form.value = {
      nombre: p.nombre,
      codigo_parte: p.codigo_parte,
      stock: p.stock,
      precio_venta: p.precio_venta,
      categoria_id: p.categoria_id,
      activo: p.activo
    }
  }
}, { immediate: true })

const errors = ref<Record<string, string>>({})
const submitted = ref(false)

const loadCategorias = async () => {
  loadingCategorias.value = true
  try {
    categorias.value = await fetchAllCategorias()
  } catch {
    categorias.value = []
  } finally {
    loadingCategorias.value = false
  }
}

const openCategoriaModal = () => {
  newCategoriaNombre.value = ''
  categoriaModalError.value = ''
  showCategoriaModal.value = true
}

const handleCreateCategoria = async () => {
  const nombre = newCategoriaNombre.value.trim()
  if (!nombre) {
    categoriaModalError.value = 'El nombre es obligatorio'
    return
  }
  if (nombre.length < 2) {
    categoriaModalError.value = 'Debe tener al menos 2 caracteres'
    return
  }
  savingCategoria.value = true
  categoriaModalError.value = ''
  try {
    const nueva = await createCategoria(nombre)
    await loadCategorias()
    form.value.categoria_id = nueva.id
    showCategoriaModal.value = false
  } catch (e: any) {
    categoriaModalError.value = categoriaFriendlyError(e)
  } finally {
    savingCategoria.value = false
  }
}

onMounted(loadCategorias)

const validate = () => {
  const e: Record<string, string> = {}

  const nombre = form.value.nombre?.trim() ?? ''
  if (!nombre) e.nombre = 'El nombre es obligatorio'
  else if (nombre.length < 3) e.nombre = 'Debe tener al menos 3 caracteres'
  else if (nombre.length > 120) e.nombre = 'Máximo 120 caracteres'

  const codigo = form.value.codigo_parte?.trim() ?? ''
  if (!codigo) e.codigo_parte = 'El código de parte es obligatorio'
  else if (codigo.length < 2) e.codigo_parte = 'Debe tener al menos 2 caracteres'
  else if (codigo.length > 60) e.codigo_parte = 'Máximo 60 caracteres'

  if (form.value.stock === null || form.value.stock === undefined || isNaN(form.value.stock as number))
    e.stock = 'Ingresa un stock válido'
  else if ((form.value.stock as number) < 0) e.stock = 'El stock no puede ser negativo'
  else if (!Number.isInteger(form.value.stock as number)) e.stock = 'El stock debe ser un número entero'

  if (form.value.precio_venta === null || form.value.precio_venta === undefined || isNaN(form.value.precio_venta as number))
    e.precio_venta = 'Ingresa un precio válido'
  else if ((form.value.precio_venta as number) <= 0) e.precio_venta = 'El precio debe ser mayor a 0'

  errors.value = e
  return Object.keys(e).length === 0
}

watch(form, () => { if (submitted.value) validate() }, { deep: true })

const handleSubmit = () => {
  submitted.value = true
  if (!validate()) return

  emit('submit', {
    values: {
      nombre: form.value.nombre.trim(),
      codigo_parte: form.value.codigo_parte.trim(),
      stock: form.value.stock as number,
      precio_venta: form.value.precio_venta as number,
      categoria_id: form.value.categoria_id || null,
      activo: form.value.activo
    }
  })
}
</script>

<template>
  <form @submit.prevent="handleSubmit" class="flex flex-col gap-5" novalidate>

    <!-- Estado (Solo en edición) -->
    <div v-if="producto" class="flex flex-col gap-3 p-4 bg-slate-50 border border-slate-200 rounded-xl mb-1">
      <div class="flex items-center justify-between">
        <div class="flex flex-col gap-0.5">
          <label for="activo" class="text-xs font-bold text-slate-700 uppercase tracking-wide">Estado del producto</label>
          <span class="text-[10px] text-slate-500 font-medium">
            {{ form.activo ? 'El producto está activo y disponible' : 'El producto está inactivo y oculto' }}
          </span>
        </div>
        <ToggleSwitch id="activo" v-model="form.activo" />
      </div>

      <!-- Alerta Crítica de Desactivación -->
      <div v-if="!form.activo" class="bg-rose-50 border border-rose-200 rounded-lg p-3 flex gap-3 items-start animate-in zoom-in duration-300">
        <div class="p-1.5 bg-rose-100 rounded-md">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="text-rose-700"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
        </div>
        <div class="flex-1">
          <p class="text-[11px] font-black text-rose-800 uppercase tracking-tight mb-1">Modo Desactivación Blindado</p>
          <p class="text-xs text-rose-700 leading-tight mb-2">Se ignorará cualquier cambio en los campos de abajo. El sistema descargará las <b>{{ props.producto?.stock }} uds</b> actuales a <b>CERO</b> y registrará la incidencia automáticamente.</p>
          <p class="text-[10px] text-rose-600 italic">Si necesita editar información, vuelva a activar el producto primero.</p>
        </div>
      </div>
    </div>

    <!-- Nombre -->
    <div class="flex flex-col gap-1.5">
      <label for="nombre" class="text-sm font-medium text-slate-700">
        Nombre del producto <span class="text-red-500">*</span>
      </label>
      <InputText
        id="nombre"
        v-model="form.nombre"
        placeholder="Pastillas de freno Honda CGL"
        :invalid="!!errors.nombre"
        :disabled="!form.activo"
      />
      <small v-if="errors.nombre" class="text-red-600">{{ errors.nombre }}</small>
    </div>

    <!-- Código -->
    <div class="flex flex-col gap-1.5">
      <label for="codigo" class="text-sm font-medium text-slate-700">
        Código de parte <span class="text-red-500">*</span>
      </label>
      <InputText
        id="codigo"
        v-model="form.codigo_parte"
        placeholder="HON-CGL-PF-001"
        :invalid="!!errors.codigo_parte"
        :disabled="!form.activo"
      />
      <small v-if="errors.codigo_parte" class="text-red-600">{{ errors.codigo_parte }}</small>
    </div>

    <!-- Categoría -->
    <div class="flex flex-col gap-1.5">
      <label for="categoria" class="text-sm font-medium text-slate-700">
        Categoría
      </label>
      <div class="flex gap-2 items-center">
        <Select
          id="categoria"
          v-model="form.categoria_id"
          :options="categorias"
          option-label="nombre"
          option-value="id"
          placeholder="Seleccionar categoría"
          :loading="loadingCategorias"
          show-clear
          class="flex-1"
          :disabled="!form.activo"
        />
        <Button
          type="button"
          severity="success"
          class="aspect-square"
          aria-label="Crear categoría"
          @click="openCategoriaModal"
          :disabled="!form.activo">
          <Plus class="w-5 h-5" />
        </Button>
      </div>
    </div>

    <!-- Stock -->
    <div class="flex flex-col gap-1.5 w-full">
      <label for="stock" class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">
        Stock Inicial <span class="text-red-500">*</span>
      </label>
      <InputNumber
        id="stock"
        v-model="form.stock"
        :min="0"
        show-buttons
        :invalid="!!errors.stock"
        class="w-full"
        :disabled="!form.activo"
      />
      <small v-if="errors.stock" class="text-red-600 text-xs">{{ errors.stock }}</small>
    </div>

    <!-- Precio -->
    <div class="flex flex-col gap-1.5 w-full">
      <label for="precio" class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">
        Precio de venta <span class="text-red-500">*</span>
      </label>
      <InputNumber
        id="precio"
        v-model="form.precio_venta"
        :min="0"
        :min-fraction-digits="2"
        :max-fraction-digits="2"
        mode="currency"
        currency="USD"
        :invalid="!!errors.precio_venta"
        class="w-full"
        :disabled="!form.activo"
      />
      <small v-if="errors.precio_venta" class="text-red-600 text-xs">{{ errors.precio_venta }}</small>
    </div>

    <div class="flex gap-2 justify-end mt-2">
      <Button type="button" label="Cancelar" severity="secondary" :disabled="loading" @click="emit('cancel')" />
      <Button type="submit" :loading="loading" :label="producto ? 'Guardar cambios' : 'Crear producto'" />
    </div>
  </form>

  <!-- Modal crear categoría inline -->
  <Dialog
    v-model:visible="showCategoriaModal"
    header="Nueva Categoría"
    modal
    :style="{ width: '26rem' }"
    :closable="!savingCategoria"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1.5">
        <label for="nueva-cat-nombre" class="text-sm font-medium text-slate-700">
          Nombre <span class="text-red-500">*</span>
        </label>
        <InputText
          id="nueva-cat-nombre"
          v-model="newCategoriaNombre"
          placeholder="Ej: Aceites y Lubricantes"
          :invalid="!!categoriaModalError"
          @keyup.enter="handleCreateCategoria"
          autofocus
        />
        <small v-if="categoriaModalError" class="text-red-600">{{ categoriaModalError }}</small>
      </div>
    </div>

    <template #footer>
      <Button label="Cancelar" severity="secondary" :disabled="savingCategoria" @click="showCategoriaModal = false" />
      <Button label="Crear" :loading="savingCategoria" @click="handleCreateCategoria" />
    </template>
  </Dialog>
</template>
