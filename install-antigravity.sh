#!/bin/bash
set -e
echo "=== Antigravity Claude Proxy — Android ==="

pkg update -y && pkg install -y nodejs git python make clang

cd ~
npm pack antigravity-claude-proxy@2.8.1
tar -xzf antigravity-claude-proxy-2.8.1.tgz
rm antigravity-claude-proxy-2.8.1.tgz
mv package antigravity
cd antigravity

node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json'));
delete pkg.dependencies['better-sqlite3'];
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"

cat > src/auth/database.js << 'EOF'
import { readFileSync } from 'fs';
import { ANTIGRAVITY_DB_PATH } from '../constants.js';
import initSqlJs from 'sql.js';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

export async function getAuthStatus(dbPath = ANTIGRAVITY_DB_PATH) {
    const SQL = await initSqlJs({
    locateFile: file => require('path').join(require('path').dirname(require.resolve('sql.js')), file)
  });
    const fileBuffer = readFileSync(dbPath);
    const db = new SQL.Database(fileBuffer);
    const result = db.exec("SELECT value FROM ItemTable WHERE key = 'antigravityAuthStatus'");
    db.close();
    if (!result.length || !result[0].values.length) throw new Error('No auth status found');
    const authData = JSON.parse(result[0].values[0][0]);
    if (!authData.apiKey) throw new Error('Missing apiKey');
    return authData;
}

export function isDatabaseAccessible(dbPath = ANTIGRAVITY_DB_PATH) {
    try { readFileSync(dbPath); return true; } catch { return false; }
}

export default { getAuthStatus, isDatabaseAccessible };
EOF

npm install --ignore-scripts
npm install sql.js --ignore-scripts

echo "Применяем патчи..."
curl -s https://raw.githubusercontent.com/LGranted/antigravity-claude-proxy/master/patch.js -o patch.js
node patch.js ~/antigravity
rm patch.js

echo "alias ag='cd ~/antigravity && node bin/cli.js'" >> ~/.bashrc

echo ""
echo "=== Готово! ==="
echo "Добавь аккаунт: cd ~/antigravity && node bin/cli.js accounts add --no-browser"
echo "Запуск: ag start"
echo "Чтобы алиас заработал прямо сейчас, введи: source ~/.bashrc"
