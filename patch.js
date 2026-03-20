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
            content = content.replace(from, to);
            console.log(`✓ ${filePath.split('/').pop().split('\\').pop()}`);
        } else {
            console.log(`⚠ Не найдено в ${filePath.split('/').pop().split('\\').pop()}: ${from.substring(0, 50)}...`);
        }
    }
    writeFileSync(filePath, content);
}

patch(join(dir, 'src/constants.js'), [
    [
        `export const ANTIGRAVITY_SYSTEM_INSTRUCTION = \`You are Antigravity, a powerful agentic AI coding assistant designed by the Google Deepmind team working on Advanced Agentic Coding.You are pair programming with a USER to solve their coding task. The task may require creating a new codebase, modifying or debugging an existing codebase, or simply answering a question.**Absolute paths only****Proactiveness**\`;`,
        `export const ANTIGRAVITY_SYSTEM_INSTRUCTION = \`\`;`
    ],
    [
        'export const GEMINI_MAX_OUTPUT_TOKENS = 16384',
        'export const GEMINI_MAX_OUTPUT_TOKENS = 65536'
    ]
]);

patch(join(dir, 'src/cloudcode/request-builder.js'), [
    ["requestType: 'agent'", "requestType: 'chat'"]
]);

patch(join(dir, 'src/format/thinking-utils.js'), [
    [
        `const GEMINI_THINKING_BUDGET_LIMITS = {\n    '2.5': 24576,\n};`,
        `const GEMINI_THINKING_BUDGET_LIMITS = {\n    '2.5': 24576,\n    '3': null,\n    '3.1': null,\n};`
    ],
    [
        `export function clampGeminiThinkingBudget(modelName, budget) {\n    const requestedBudget = budget || GEMINI_DEFAULT_THINKING_BUDGET;`,
        `export function clampGeminiThinkingBudget(modelName, budget, maxTokens) {
    const lower2 = (modelName || '').toLowerCase();
    const earlyMatch = lower2.match(/gemini-(\d+(?:\.\d+)?)/);
    if (earlyMatch) {
        const v = earlyMatch[1];
        const major = v.split('.')[0];
        if (GEMINI_THINKING_BUDGET_LIMITS[v] === null || GEMINI_THINKING_BUDGET_LIMITS[major] === null) {
            return null;
        }
    }
    const requestedBudget = budget || Math.min(Math.floor((maxTokens || 16000) * 0.5), 24576);`
    ]
]);

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
