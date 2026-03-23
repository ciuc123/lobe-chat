import { TRPCError } from '@trpc/server';

import { getServerDB } from '@/database/core/db-adaptor';
import { pino } from '@/libs/logger';

import { trpc } from '../init';

export const serverDatabase = trpc.middleware(async (opts) => {
  try {
    const serverDB = await getServerDB();

    if (!serverDB) {
      // Defensive: if the DB adapter returned an empty object or null, surface a clear error
      pino.error('serverDatabase middleware: no database instance available');
      throw new TRPCError({ code: 'INTERNAL_SERVER_ERROR', message: 'Database is not configured' });
    }

    return opts.next({ ctx: { serverDB } });
  } catch (error) {
    // Log details server-side, but return a sanitized TRPC error to clients
    pino.error({ err: error, msg: 'Failed to initialize or get server database' });
    throw new TRPCError({
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Failed to connect to database',
    });
  }
});
