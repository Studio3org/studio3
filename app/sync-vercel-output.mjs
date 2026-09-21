import { cpSync, copyFileSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const appDir = dirname(fileURLToPath(import.meta.url));
const distDir = join(appDir, 'dist');
const dotDistDir = join(appDir, '.dist');

copyFileSync(join(appDir, 'vercel.static.json'), join(distDir, 'vercel.json'));
copyFileSync(join(distDir, 'index.html'), join(distDir, '404.html'));

rmSync(dotDistDir, { recursive: true, force: true });
mkdirSync(dotDistDir, { recursive: true });
cpSync(distDir, dotDistDir, { recursive: true });
