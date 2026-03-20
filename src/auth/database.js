import { readFileSync, existsSync } from 'fs';
import { ANTIGRAVITY_DB_PATH } from '../constants.js';
import initSqlJs from 'sql.js';

export async function getAuthStatus(dbPath = ANTIGRAVITY_DB_PATH) {
    const SQL = await initSqlJs();
    const fileBuffer = readFileSync(dbPath);
    const db = new SQL.Database(fileBuffer);
    const result = db.exec("SELECT value FROM ItemTable WHERE key = 'antigravityAuthStatus'");
    db.close();
    if (!result.length || !result[0].values.length) throw new Error('No auth status found in database');
    const authData = JSON.parse(result[0].values[0][0]);
    if (!authData.apiKey) throw new Error('Auth data missing apiKey field');
    return authData;
}

export function isDatabaseAccessible(dbPath = ANTIGRAVITY_DB_PATH) {
    try { readFileSync(dbPath); return true; } catch { return false; }
}

export default { getAuthStatus, isDatabaseAccessible };
