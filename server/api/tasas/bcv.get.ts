import https from 'node:https'
import axios from 'axios'
import * as cheerio from 'cheerio'

const BCV_URL = 'https://www.bcv.org.ve/'

// El certificado del BCV suele estar vencido/mal encadenado; sin esto axios rechaza la conexión.
// Se limita a este agente (no a NODE_TLS_REJECT_UNAUTHORIZED global) para no debilitar TLS en el resto de la función.
const httpsAgent = new https.Agent({ rejectUnauthorized: false })

// El firewall del BCV bloquea clientes sin pinta de navegador real.
const BROWSER_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'es-VE,es;q=0.9,en;q=0.8',
  Connection: 'keep-alive',
  Referer: 'https://www.bcv.org.ve/'
}

// Scrapea bcv.org.ve directamente (server-side) para evitar el retraso de APIs de terceros los fines de semana.
export default defineEventHandler(async () => {
  try {
    const response = await axios.get(BCV_URL, {
      httpsAgent,
      headers: BROWSER_HEADERS,
      timeout: 15000
    })

    const $ = cheerio.load(response.data)

    let rawValue = $('#dolar strong').first().text()

    // Fallback por si el BCV cambia el id exacto pero conserva el patrón "id que contiene dolar".
    if (!rawValue || !rawValue.trim()) {
      rawValue = $('[id*="dolar"] strong').first().text()
    }

    if (!rawValue || !rawValue.trim()) {
      throw new Error('No se encontró el contenedor del dólar en el HTML de bcv.org.ve (la estructura pudo haber cambiado)')
    }

    // Descarta puntos de miles y convierte la coma decimal venezolana a punto.
    const cleaned = rawValue
      .trim()
      .replace(/[^\d,.-]/g, '')
      .replace(/\./g, '')
      .replace(',', '.')

    const tasa = parseFloat(cleaned)

    if (Number.isNaN(tasa)) {
      throw new Error(`El valor extraído ("${rawValue.trim()}") no pudo convertirse a número`)
    }

    return {
      fuente: 'Banco Central de Venezuela',
      moneda: 'USD',
      tasa,
      fecha_extraccion: new Date().toISOString()
    }
  } catch (error: any) {
    throw createError({
      statusCode: 502,
      message: `No se pudo obtener la tasa BCV: ${error.message}`
    })
  }
})
