import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';
import { homedir, platform } from 'os';

const isWindows = platform() === 'win32';

function findInstallDir() {
    if (isWindows) {
        const npmRoot = process.env.npm_root || join(process.env.APPDATA || '', 'npm', 'node_modules');
        return join(npmRoot, 'antigravity-claude-proxy');
    }
    return join(homedir(), 'antigravity');
}

const dir = process.argv[2] || findInstallDir();
console.log(`Патчим: ${dir}`);

function patch(filePath, patches) {
    let content = readFileSync(filePath, 'utf8');
    for (const [from, to] of patches) {
        if (content.includes(from)) {
            content = content.split(from).join(to);
            console.log(`✓ ${filePath.split('/').pop().split('\\').pop()}`);
        } else {
            console.log(`⚠ Не найдено в ${filePath.split('/').pop().split('\\').pop()}: ${from.substring(0, 50)}...`);
        }
    }
    writeFileSync(filePath, content);
}

// 1. constants.js
patch(join(dir, 'src/constants.js'), [
    [
        'You are Antigravity, a powerful agentic AI coding assistant',
        'REPLACED_ANTIGRAVITY_PLACEHOLDER'
    ]
]);

// Находим и заменяем всю строку ANTIGRAVITY_SYSTEM_INSTRUCTION
let constantsContent = readFileSync(join(dir, 'src/constants.js'), 'utf8');
constantsContent = constantsContent.replace(
    /export const ANTIGRAVITY_SYSTEM_INSTRUCTION = `[^`]*`;/,
    'export const ANTIGRAVITY_SYSTEM_INSTRUCTION = ``;'
);
constantsContent = constantsContent.split('export const GEMINI_MAX_OUTPUT_TOKENS = 16384').join('export const GEMINI_MAX_OUTPUT_TOKENS = 65536');
writeFileSync(join(dir, 'src/constants.js'), constantsContent);
console.log('✓ constants.js');

// 2. request-builder.js
patch(join(dir, 'src/cloudcode/request-builder.js'), [
    ["requestType: 'agent'", "requestType: 'chat'"]
]);

// 3. thinking-utils.js — используем regex для надёжности
let thinkingContent = readFileSync(join(dir, 'src/format/thinking-utils.js'), 'utf8');
thinkingContent = thinkingContent.replace(
    /const GEMINI_THINKING_BUDGET_LIMITS = \{[\s\S]*?\};/,
    `const GEMINI_THINKING_BUDGET_LIMITS = {\n    '2.5': 24576,\n    '3': null,\n    '3.1': null,\n};`
);
thinkingContent = thinkingContent.replace(
    /export function clampGeminiThinkingBudget\(modelName, budget\) \{/,
    `export function clampGeminiThinkingBudget(modelName, budget, maxTokens) {`
);
thinkingContent = thinkingContent.replace(
    /const requestedBudget = budget \|\| GEMINI_DEFAULT_THINKING_BUDGET;/,
    `const lower2 = (modelName || '').toLowerCase();
    const earlyMatch = lower2.match(/gemini-(\\d+(?:\\.\\d+)?)/);
    if (earlyMatch) {
        const v = earlyMatch[1];
        const major = v.split('.')[0];
        if (GEMINI_THINKING_BUDGET_LIMITS[v] === null || GEMINI_THINKING_BUDGET_LIMITS[major] === null) {
            return null;
        }
    }
    const requestedBudget = budget || Math.min(Math.floor((maxTokens || 16000) * 0.5), 24576);`
);
writeFileSync(join(dir, 'src/format/thinking-utils.js'), thinkingContent);
console.log('✓ thinking-utils.js');

// 4. request-converter.js
patch(join(dir, 'src/format/request-converter.js'), [
    [
        'const thinkingBudget = thinking?.budget_tokens || 32000;',
        'const thinkingBudget = thinking?.budget_tokens || Math.max(Math.min(Math.floor((anthropicRequest.max_tokens || 16000) * 0.5), 32000), 1024);'
    ],
    [
        'thinkingBudget: clampGeminiThinkingBudget(modelName, thinking?.budget_tokens)',
        'thinkingBudget: clampGeminiThinkingBudget(modelName, thinking?.budget_tokens, anthropicRequest.max_tokens) ?? undefined'
    ]
]);

// 5. config.json
const configDir = join(homedir(), '.config', 'antigravity-proxy');
if (!existsSync(configDir)) mkdirSync(configDir, { recursive: true });
writeFileSync(join(configDir, 'config.json'), JSON.stringify({
    maxRetries: 3,
    defaultCooldownMs: 5000,
    persistTokenCache: true,
    accountSelection: {
        strategy: 'hybrid',
        healthScore: {
            initial: 70,
            successReward: 2,
            rateLimitPenalty: -5,
            recoveryPerHour: 15
        }
    }
}, null, 2));
console.log('✓ config.json');
console.log('\n=== Все патчи применены! ===');
