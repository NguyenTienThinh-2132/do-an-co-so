import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';

let app;
try {
  app = await NestFactory.create(AppModule, { logger: false, abortOnError: false });
  await app.listen(0, '127.0.0.1');
  const base = await app.getUrl();
  const root = fileURLToPath(new URL('../../', import.meta.url));
  const dart = process.env.DART_EXECUTABLE || 'dart';
  const code = await new Promise((resolve, reject) => {
    const child = spawn(dart, ['run', 'tool/check_task_reader.dart', base], {
      cwd: root,
      stdio: 'inherit',
      windowsHide: true,
    });
    child.once('error', reject);
    child.once('exit', (exitCode) => resolve(exitCode ?? 1));
  });
  process.exitCode = code;
} catch {
  console.error('FAIL: TaskReader integration runner; no raw errors logged.');
  process.exitCode = 1;
} finally {
  if (app) await app.close();
}