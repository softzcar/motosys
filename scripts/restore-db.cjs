#!/usr/bin/env node

/**
 * MOTOSYS - SCRIPT DE RESTAURACIÓN DE BASE DE DATOS SUPABASE
 * =========================================================
 * Este script automatiza el proceso de restauración de un archivo de respaldo (.sql)
 * en la base de datos de Supabase.
 * 
 * Uso:
 *   node scripts/restore-db.cjs [ruta-al-archivo-backup.sql] [opciones]
 * 
 * Opciones:
 *   --local, -l        Restaura en la base de datos local (Supabase local).
 *   --remote, -r       Restaura en la base de datos remota.
 *   --db-url, -u       URL de conexión directa (postgresql://...) en lugar de usar configuraciones automáticas.
 *   --env, -e          Archivo de variables de entorno a leer. Por defecto: './.env.local-dev'
 *   --no-confirm       Salta la confirmación interactiva.
 *   --help, -h         Muestra este mensaje de ayuda.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

// 1. Configuración por defecto
const DEFAULT_OPTS = {
  local: true,
  dbUrl: null,
  envFile: path.join(__dirname, '..', '.env.local-dev'),
  confirm: true,
  backupFile: null
};

// 2. Parseo de argumentos
const args = process.argv.slice(2);
const options = { ...DEFAULT_OPTS };

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--local' || arg === '-l') {
    options.local = true;
  } else if (arg === '--remote' || arg === '-r') {
    options.local = false;
  } else if (arg === '--db-url' || arg === '-u') {
    options.dbUrl = args[++i];
    options.local = false;
  } else if (arg === '--env' || arg === '-e') {
    options.envFile = args[++i];
  } else if (arg === '--no-confirm') {
    options.confirm = false;
  } else if (arg === '--help' || arg === '-h') {
    showHelp();
    process.exit(0);
  } else if (!arg.startsWith('-')) {
    options.backupFile = arg;
  } else {
    console.warn(`⚠️ Opción desconocida ignorada: "${arg}"`);
  }
}

function showHelp() {
  console.log(`
MOTOSYS - SCRIPT DE RESTAURACIÓN DE BASE DE DATOS SUPABASE
=========================================================
Uso:
  node scripts/restore-db.cjs [ruta-al-archivo-backup.sql] [opciones]

Opciones:
  -l, --local        Restaura en la base de datos de desarrollo local.
  -r, --remote       Restaura en la base de datos remota configurada en .env.
  -u, --db-url <url> URL de conexión directa a Postgres (postgresql://usuario:pass@host:puerto/db)
  -e, --env <path>   Archivo de variables de entorno a leer. Por defecto: './.env.local-dev'
  --no-confirm       Ejecuta la restauración sin pedir confirmación (útil para scripts).
  -h, --help         Muestra esta ayuda.
`);
}

// Cargar variables de entorno si es necesario
function loadEnv(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const content = fs.readFileSync(filePath, 'utf8');
  const env = {};
  content.split(/\r?\n/).forEach(line => {
    line = line.trim();
    if (!line || line.startsWith('#')) return;
    const separatorIdx = line.indexOf('=');
    if (separatorIdx > 0) {
      const key = line.slice(0, separatorIdx).trim();
      let val = line.slice(separatorIdx + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      env[key] = val;
    }
  });
  return env;
}

const env = loadEnv(options.envFile);

// 3. Validar archivo de respaldo
if (!options.backupFile) {
  // Proponer el último respaldo de la carpeta backups si existe
  const backupsDir = path.join(__dirname, '..', 'backups');
  if (fs.existsSync(backupsDir)) {
    const files = fs.readdirSync(backupsDir)
      .filter(f => f.endsWith('.sql'))
      .map(f => ({ name: f, time: fs.statSync(path.join(backupsDir, f)).mtime.getTime() }))
      .sort((a, b) => b.time - a.time);
    
    if (files.length > 0) {
      options.backupFile = path.join(backupsDir, files[0].name);
      console.log(`💡 No se especificó archivo. Seleccionando el más reciente automáticamente: ${files[0].name}`);
    }
  }
}

if (!options.backupFile || !fs.existsSync(options.backupFile)) {
  console.error(`❌ Error: El archivo de respaldo especificado no existe o no se encontró ningún backup en el directorio backups/`);
  console.error(`Especifica un archivo válido, ej: node scripts/restore-db.cjs backups/mi_backup_all.sql`);
  process.exit(1);
}

// Resolver ruta absoluta
const backupFilePath = path.resolve(options.backupFile);
const backupFileName = path.basename(backupFilePath);

// 4. Determinar destino
let dbUrl = options.dbUrl;
if (!dbUrl && !options.local) {
  dbUrl = process.env.DATABASE_URL || env.DATABASE_URL || env.SUPABASE_DB_URL;
  if (!dbUrl) {
    console.error('❌ Error: Has especificado --remote pero no se encontró DATABASE_URL ni SUPABASE_DB_URL en el archivo env.');
    process.exit(1);
  }
}

const targetDesc = dbUrl ? 'Base de datos Remota (URL)' : (options.local ? 'Base de datos Local (Docker)' : 'Base de datos Remota');

// 5. Preguntar confirmación antes de destruir datos
function askConfirmation(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      const ans = answer.trim().toLowerCase();
      resolve(ans === 'y' || ans === 'yes' || ans === 's' || ans === 'si' || ans === 'sí');
    });
  });
}

async function run() {
  console.log(`\n🚨 ALERTA DE RESTAURACIÓN 🚨`);
  console.log(`===========================`);
  console.log(`Archivo de respaldo: ${backupFileName}`);
  console.log(`Destino:             ${targetDesc}`);
  console.log(`===========================`);
  console.log(`⚠️  ATENCIÓN: La restauración de la base de datos puede sobreescribir o duplicar datos actuales.`);
  
  if (options.confirm) {
    const confirmed = await askConfirmation('¿Estás seguro de que deseas continuar con la restauración? (s/N): ');
    if (!confirmed) {
      console.log('❌ Restauración cancelada por el usuario.');
      process.exit(0);
    }
  }

  // 6. Ejecutar restauración
  console.log(`\n⌛ Iniciando proceso de restauración...`);
  
  if (options.local) {
    // Restaurar localmente
    // Intentaremos usar Docker para evitar requerir psql instalado localmente
    try {
      console.log('⚙️  Detectando contenedor docker de base de datos...');
      // Comprobar si el contenedor supabase_db_motosys está corriendo
      const containerName = 'supabase_db_motosys';
      const isRunning = execSync(`docker ps -q -f name=${containerName}`, { encoding: 'utf8' }).trim();
      
      if (isRunning) {
        console.log(`🐳 Contenedor ${containerName} en ejecución. Restaurando mediante Docker...`);
        // Redirigir el archivo SQL al cliente psql dentro del contenedor Docker
        const cmd = `docker exec -i ${containerName} psql -U postgres -d postgres < "${backupFilePath}"`;
        execSync(cmd, { stdio: 'inherit' });
        console.log(`\n✅ Restauración completada con éxito en base de datos local usando Docker.`);
        process.exit(0);
      } else {
        console.log(`⚠️ Contenedor ${containerName} no se encontró en ejecución.`);
      }
    } catch (dockerErr) {
      console.warn(`⚠️ Error al intentar restaurar con Docker: ${dockerErr.message}`);
      console.log('Intentando restaurar mediante psql local...');
    }

    // Si Docker no está disponible, intentar con psql local
    try {
      const localDbUrl = 'postgresql://postgres:postgres@localhost:54322/postgres';
      console.log(`⚙️  Restaurando usando psql local en el puerto 54322...`);
      const cmd = `psql "${localDbUrl}" -f "${backupFilePath}"`;
      execSync(cmd, { stdio: 'inherit' });
      console.log(`\n✅ Restauración completada con éxito usando psql local.`);
      process.exit(0);
    } catch (psqlErr) {
      console.error(`\n❌ Error: No se pudo restaurar en local.`);
      console.error(`Asegúrate de que Supabase esté iniciado ('supabase start') y que tengas docker corriendo.`);
      console.error(`Detalles del error: ${psqlErr.message}`);
      process.exit(1);
    }
  } else {
    // Restaurar base de datos remota
    try {
      console.log(`⚙️  Restaurando en base de datos remota mediante psql...`);
      const cmd = `psql "${dbUrl}" -f "${backupFilePath}"`;
      execSync(cmd, { stdio: 'inherit' });
      console.log(`\n✅ Restauración completada con éxito en base de datos remota.`);
      process.exit(0);
    } catch (remoteErr) {
      console.error(`\n❌ Error al restaurar en base de datos remota:`);
      console.error(remoteErr.message);
      console.error(`\n💡 Tip: Si no tienes el comando 'psql' instalado en tu terminal, puedes copiar el contenido de tu archivo de respaldo y pegarlo en el editor SQL de Supabase Studio en la nube.`);
      process.exit(1);
    }
  }
}

run();
