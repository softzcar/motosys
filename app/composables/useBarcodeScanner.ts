export const useBarcodeScanner = (onScan: (code: string) => void) => {
  const buffer = ref('')
  const lastKeyTime = ref(0)
  const isListening = ref(true)

  const SCAN_THRESHOLD_MS = 50
  const RESET_THRESHOLD_MS = 150
  const MIN_CODE_LENGTH = 3

  const handleKeydown = (e: KeyboardEvent) => {
    if (!isListening.value) return

    const target = e.target as HTMLElement
    const isInput = target.tagName === 'INPUT' || target.tagName === 'TEXTAREA'
    if (isInput && !target.dataset.barcodeInput) return

    const now = Date.now()

    if (now - lastKeyTime.value > RESET_THRESHOLD_MS) {
      buffer.value = ''
    }

    lastKeyTime.value = now

    if (e.key === 'Enter' && buffer.value.length >= MIN_CODE_LENGTH) {
      e.preventDefault()
      e.stopPropagation()
      const code = buffer.value.trim()
      buffer.value = ''
      onScan(code)
    } else if (e.key.length === 1) {
      buffer.value += e.key
    }
  }

  onMounted(() => window.addEventListener('keydown', handleKeydown, true))
  onUnmounted(() => window.removeEventListener('keydown', handleKeydown, true))

  return { isListening, buffer }
}
