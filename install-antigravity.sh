#!/bin/bash
set -e
echo "=== Установка Antigravity Claude Proxy ==="

# 1. Зависимости
echo "Устанавливаем зависимости..."
pkg update -y && pkg install -y nodejs git python

# 2. Скачиваем пакет
echo "Скачиваем пакет..."
cd ~
npm pack antigravity-claude-proxy@2.8.1
tar -xzf antigravity-claude-proxy-2.8.1.tgz
rm antigravity-claude-proxy-2.8.1.tgz
mv package antigravity
cd antigravity

# 3. Убираем better-sqlite3
echo "Убираем несовместимую зависимость..."
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json'));
delete pkg.dependencies['better-sqlite3'];
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"

# 4. Заменяем database.js
echo "Заменяем database.js..."
cat > src/auth/database.js << 'EOF'
import { readFileSync } from 'fs';
import { ANTIGRAVITY_DB_PATH } from '../constants.js';
import initSqlJs from 'sql.js';

export async function getAuthStatus(dbPath = ANTIGRAVITY_DB_PATH) {
    const SQL = await initSqlJs();
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

# 5. Устанавливаем зависимости
echo "Устанавливаем зависимости..."
npm install --ignore-scripts
npm install sql.js --ignore-scripts

# 6. Убираем кодинг-личность
echo "Убираем кодинг-личность..."
sed -i 's/export const ANTIGRAVITY_SYSTEM_INSTRUCTION = `.*`;/export const ANTIGRAVITY_SYSTEM_INSTRUCTION = ``;/' src/constants.js

# 7. requestType chat
echo "Меняем requestType на chat..."
cp src/cloudcode/request-builder.js src/cloudcode/request-builder.js.bak
sed -i "s/requestType: 'agent'/requestType: 'chat'/" src/cloudcode/request-builder.js

# 8. Увеличиваем Gemini output
echo "Увеличиваем Gemini max output tokens..."
sed -i 's/export const GEMINI_MAX_OUTPUT_TOKENS = 16384/export const GEMINI_MAX_OUTPUT_TOKENS = 65536/' src/constants.js

# 9. Gemini 3 авто thinking
echo "Настраиваем Gemini 3 авто thinking..."
node -e "
const fs = require('fs');
const path = 'src/format/thinking-utils.js';
let c = fs.readFileSync(path, 'utf8');
c = c.replace(
  \"const GEMINI_THINKING_BUDGET_LIMITS = {\n    '2.5': 24576,\n};\",
  \"const GEMINI_THINKING_BUDGET_LIMITS = {\n    '2.5': 24576,\n    '3': null,\n    '3.1': null,\n};\"
);
c = c.replace(
  'export function clampGeminiThinkingBudget(modelName, budget) {\n    const requestedBudget = budget || GEMINI_DEFAULT_THINKING_BUDGET;',
  \`export function clampGeminiThinkingBudget(modelName, budget, maxTokens) {
    const lower2 = (modelName || '').toLowerCase();
    const earlyMatch = lower2.match(/gemini-(\\\\d+(?:\\\\.\\\\d+)?)/);
    if (earlyMatch) {
        const v = earlyMatch[1];
        const major = v.split('.')[0];
        if (GEMINI_THINKING_BUDGET_LIMITS[v] === null || GEMINI_THINKING_BUDGET_LIMITS[major] === null) {
            return null;
        }
    }
    const requestedBudget = budget || Math.min(Math.floor((maxTokens || 16000) * 0.5), 24576);\`
);
fs.writeFileSync(path, c);
console.log('Done');
"

# 10. Claude thinking budget из ST
echo "Настраиваем Claude thinking budget..."
sed -i 's/const thinkingBudget = thinking?.budget_tokens || 32000;/const thinkingBudget = thinking?.budget_tokens || Math.max(Math.min(Math.floor((anthropicRequest.max_tokens || 16000) * 0.5), 32000), 1024);/' src/format/request-converter.js
sed -i 's/thinkingBudget: clampGeminiThinkingBudget(modelName, thinking?.budget_tokens)/thinkingBudget: clampGeminiThinkingBudget(modelName, thinking?.budget_tokens, anthropicRequest.max_tokens) ?? undefined/' src/format/request-converter.js

# 11. Config
echo "Настраиваем config..."
mkdir -p ~/.config/antigravity-proxy
cat > ~/.config/antigravity-proxy/config.json << 'EOF'
{
  "maxRetries": 3,
  "defaultCooldownMs": 5000,
  "persistTokenCache": true,
  "accountSelection": {
    "strategy": "hybrid",
    "healthScore": {
      "initial": 70,
      "successReward": 2,
      "rateLimitPenalty": -5,
      "recoveryPerHour": 15
    }
  }
}
EOF

# 12. Алиас
echo "alias ag='cd ~/antigravity && node bin/cli.js'" >> ~/.bashrc
source ~/.bashrc

echo ""
echo "=== Установка завершена! ==="
echo ""
echo "Следующий шаг — добавить Google аккаунт:"
echo "  cd ~/antigravity && node bin/cli.js accounts add --no-browser"
echo ""
echo "Запуск:"
echo "  ag start"
