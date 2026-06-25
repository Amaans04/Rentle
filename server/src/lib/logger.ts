type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogMeta {
  [key: string]: unknown;
}

function write(level: LogLevel, event: string, meta?: LogMeta): void {
  const entry = {
    level,
    event,
    timestamp: new Date().toISOString(),
    service: 'rentle-api',
    ...meta,
  };

  const line = JSON.stringify(entry);
  if (level === 'error') {
    console.error(line);
    return;
  }
  if (level === 'warn') {
    console.warn(line);
    return;
  }
  console.log(line);
}

export const logger = {
  debug: (event: string, meta?: LogMeta) => write('debug', event, meta),
  info: (event: string, meta?: LogMeta) => write('info', event, meta),
  warn: (event: string, meta?: LogMeta) => write('warn', event, meta),
  error: (event: string, meta?: LogMeta) => write('error', event, meta),
};
