#!/usr/bin/env node

/**
 * MOTOSYS - SCRIPT DE RESPALDO DE BASE DE DATOS SUPABASE
 * =====================================================
 * Este script automatiza el proceso de volcado de la base de datos (esquema y datos)
 * utilizando Supabase CLI.
 * 
 * Uso:
 *   node scripts/backup-db.js [opciones]
 * 
 * Opciones:
 *   --local, -l        Realiza el respaldo de la base de datos local (Supabase local).
 *   --remote, -r       Realiza el respaldo de la base de datos remota.
 *   --type, -t         Tipo de respaldo: 'all' (esquema + datos), 'schema' (solo esquema), 'data' (solo datos). Por defecto: 'all'
 *   --db-url, -u       URL de conexión directa (postgresql://...) en lugar de usar configuraciones automáticas.
 *   --output-dir, -o   Directorio de destino para los respaldos. Por defecto: './backups'
 *   --help, -h         Muestra este mensaje de ayuda.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// 1. Configuración por defecto
const DEFAULT_OPTS = {
  local: true, // Por defecto se asume local si no se especifica --remote
  type: 'all', // 'all', 'schema', 'data'
  outputDir: path.join(__dirname, '..', 'backups'),
  dbUrl: null,
  envFile: path.join(__dirname, '..', '.env.local-dev')
};

// 2. Parseo rudimentario de argumentos (sin dependencias externas)
const args = process.argv.slice(2);
const options = { ...DEFAULT_OPTS };

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--local' || arg === '-l') {
    options.local = true;
  } else if (arg === '--remote' || arg === '-r') {
    options.local = false;
  } else if (arg === '--type' || arg === '-t') {
    const val = args[++i];
    if (['all', 'schema', 'data'].includes(val)) {
      options.type = val;
    } else {
      console.error(`❌ Tipo inválido: "${val}". Debe ser 'all', 'schema' o 'data'.`);
      process.exit(1);
    }
  } else if (arg === '--db-url' || arg === '-u') {
    options.dbUrl = args[++i];
    options.local = false;
  } else if (arg === '--output-dir' || arg === '-o') {
    options.outputDir = args[++i];
  } else if (arg === '--env' || arg === '-e') {
    options.envFile = args[++i];
  } else if (arg === '--help' || arg === '-h') {
    showHelp();
    process.exit(0);
  } else {
    console.warn(`⚠️ Opción desconocida ignorada: "${arg}"`);
  }
}

function showHelp() {
  console.log(`
MOTOSYS - SCRIPT DE RESPALDO DE BASE DE DATOS SUPABASE
=====================================================
Uso:
  node scripts/backup-db.js [opciones]

Opciones:
  -l, --local        Realiza el respaldo de la base de datos de desarrollo local.
  -r, --remote       Realiza el respaldo de una base de datos remota configurada en .env.
  -t, --type <all|schema|data>
                     Tipo de respaldo: 
                       - 'all' (esquema y datos)
                       - 'schema' (solo esquema/estructura)
                       - 'data' (solo datos de las tablas)
                     Por defecto: 'all'
  -u, --db-url <url> URL de conexión de Postgres (postgresql://usuario:pass@host:puerto/db)
                     Esto sobreescribe el modo --local o las variables de entorno.
  -o, --output-dir <path>
                     Carpeta donde se guardarán los respaldos. Por defecto: './backups'
  -e, --env <path>   Archivo de variables de entorno a leer. Por defecto: './.env.local-dev'
  -h, --help         Muestra esta ayuda.
`);
}

// 3. Cargar variables de entorno si existe el archivo
function loadEnv(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  const content = fs.readFileSync(filePath, 'utf8');
  const env = {};
  content.split(/\r?\n/).forEach(line => {
    line = line.trim();
    if (!line || line.startsWith('#')) return;
    const separatorIdx = line.indexOf('=');
    if (separatorIdx > 0) {
      const key = line.slice(0, separatorIdx).trim();
      let val = line.slice(separatorIdx + 1).trim();
      // Quitar comillas
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      env[key] = val;
    }
  });
  return env;
}

// Cargar variables
const env = loadEnv(options.envFile);

// 4. Asegurar que la carpeta de respaldos existe
if (!fs.existsSync(options.outputDir)) {
  fs.mkdirSync(options.outputDir, { recursive: true });
}

// Generar nombre de archivo basado en fecha y hora
const now = new Date();
const timestamp = now.toISOString()
  .replace(/T/, '_')
  .replace(/\..+/, '')
  .replace(/:/g, '-');

const envPrefix = options.local ? 'local' : 'remote';
const outputBasename = `backup_${envPrefix}_${timestamp}`;

// 5. Comprobar disponibilidad de Supabase CLI
let supabaseCmd = 'supabase';
try {
  execSync('supabase --version', { stdio: 'ignore' });
} catch (e) {
  try {
    execSync('npx supabase --version', { stdio: 'ignore' });
    supabaseCmd = 'npx supabase';
  } catch (err) {
    console.error('❌ Error: Supabase CLI no está instalado. Instálalo globalmente o ejecútalo en un entorno con npm.');
    console.error('Instalación: npm install -g supabase');
    process.exit(1);
  }
}

// 6. Construir comandos
const commandsToRun = [];

// Si se define una URL de base de datos directa, o si se detecta en env
let dbUrl = options.dbUrl;
if (!dbUrl && !options.local) {
  // Intentar obtener de variables de entorno
  dbUrl = process.env.DATABASE_URL || env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!dbUrl) {
    console.error('❌ Error: Has especificado --remote pero no se encontró DATABASE_URL ni SUPABASE_DB_URL en el archivo env.');
    process.exit(1);
  }
}

const targetDesc = dbUrl ? 'Base de datos Remota (URL)' : (options.local ? 'Base de datos Local' : 'Base de datos Remota');
console.log(`🛡️  Iniciando respaldo de: ${targetDesc}`);
console.log(`📁 Directorio de salida: ${options.outputDir}\n`);

// Definir los archivos de salida
const schemaFile = path.join(options.outputDir, `${outputBasename}_schema.sql`);
const dataFile = path.join(options.outputDir, `${outputBasename}_data.sql`);
const allFile = path.join(options.outputDir, `${outputBasename}_all.sql`);

if (options.type === 'schema' || options.type === 'all') {
  let cmd = `${supabaseCmd} db dump`;
  if (options.local) {
    cmd += ' --local';
  } else {
    cmd += ` --db-url "${dbUrl}"`;
  }
  cmd += ` -f "${schemaFile}"`;
  commandsToRun.push({
    type: 'esquema',
    cmd,
    file: schemaFile
  });
}

if (options.type === 'data' || options.type === 'all') {
  let cmd = `${supabaseCmd} db dump --data-only`;
  if (options.local) {
    cmd += ' --local';
  } else {
    cmd += ` --db-url "${dbUrl}"`;
  }
  // Utilizar inserts listos para usar en lugar de COPY para máxima compatibilidad
  cmd += ` -f "${dataFile}"`;
  commandsToRun.push({
    type: 'datos',
    cmd,
    file: dataFile
  });
}

// 7. Ejecutar respaldos
let successCount = 0;
commandsToRun.forEach(({ type, cmd, file }) => {
  console.log(`⌛ Generando respaldo del ${type}...`);
  console.log(`   Comando: ${cmd}`);
  
  try {
    execSync(cmd, { stdio: 'inherit' });
    if (fs.existsSync(file)) {
      const stats = fs.statSync(file);
      const sizeKB = (stats.size / 1024).toFixed(2);
      console.log(`✅ Respaldo de ${type} creado con éxito: ${path.basename(file)} (${sizeKB} KB)`);
      successCount++;
    } else {
      console.error(`❌ El archivo no se creó correctamente: ${file}`);
    }
  } catch (error) {
    console.error(`❌ Error al crear el respaldo del ${type}:`, error.message);
  }
  console.log('');
});

// 8. Crear archivo combinador si tipo es 'all' y se crearon ambos archivos
if (options.type === 'all' && successCount === 2) {
  try {
    console.log(`⌛ Creando respaldo completo combinado (esquema + datos)...`);
    const schemaContent = fs.readFileSync(schemaFile, 'utf8');
    const dataContent = fs.readFileSync(dataFile, 'utf8');
    
    const combinedContent = `-- MOTOSYS BACKUP COMPLETO\n` +
      `-- Fecha: ${now.toLocaleString()}\n` +
      `-- Tipo: Esquema + Datos\n\n` +
      `-- ==========================================\n` +
      `-- 1. ESTRUCTURA (ESQUEMA)\n` +
      `-- ==========================================\n\n` +
      schemaContent +
      `\n\n-- ==========================================\n` +
      `-- 2. DATOS DE TABLAS\n` +
      `-- ==========================================\n\n` +
      dataContent;
      
    fs.writeFileSync(allFile, combinedContent, 'utf8');
    const stats = fs.statSync(allFile);
    console.log(`✅ Respaldo completo combinado creado con éxito: ${path.basename(allFile)} (${(stats.size / 1024).toFixed(2)} KB)`);
  } catch (err) {
    console.error('❌ Error al combinar esquema y datos:', err.message);
  }
}

console.log(`\n🎉 Proceso finalizado. Total de archivos generados: ${successCount + (options.type === 'all' && successCount === 2 ? 1 : 0)}`);
