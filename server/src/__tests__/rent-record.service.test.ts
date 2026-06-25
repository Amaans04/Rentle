import { describe, it, expect, vi, beforeEach } from 'vitest';
import { RentRecordService } from '@/services/rent/rent-record.service';

function createMockDb() {
  const stores: Record<string, Map<string, Record<string, unknown>>> = {
    pgs: new Map(),
    tenants: new Map(),
    rentRecords: new Map(),
    users: new Map(),
  };

  const db = {
    collection(name: string) {
      const store = stores[name] ?? new Map();
      stores[name] = store;
      return {
        doc(id?: string) {
          const docId = id ?? `auto-${Math.random()}`;
          return {
            id: docId,
            async get() {
              const data = store.get(docId);
              return {
                exists: !!data,
                id: docId,
                data: () => data,
              };
            },
            set: vi.fn(async (data: Record<string, unknown>) => {
              store.set(docId, data);
            }),
            update: vi.fn(),
            delete: vi.fn(),
          };
        },
        where(field: string, _op: string, value: unknown) {
          const filters: Array<{ field: string; value: unknown }> = [
            { field, value },
          ];
          const chain = {
            where(f: string, _o: string, v: unknown) {
              filters.push({ field: f, value: v });
              return chain;
            },
            limit(n: number) {
              return {
                async get() {
                  const docs = [...store.entries()]
                    .filter(([, data]) =>
                      filters.every((f) => data[f.field] === f.value),
                    )
                    .slice(0, n)
                    .map(([id, data]) => ({
                      id,
                      data: () => data,
                    }));
                  return { empty: docs.length === 0, docs };
                },
              };
            },
            async get() {
              const docs = [...store.entries()]
                .filter(([, data]) =>
                  filters.every((f) => data[f.field] === f.value),
                )
                .map(([id, data]) => ({
                  id,
                  data: () => data,
                }));
              return { empty: docs.length === 0, docs };
            },
          };
          return chain;
        },
      };
    },
    batch() {
      const ops: Array<() => void> = [];
      return {
        set(ref: { set: (d: Record<string, unknown>) => Promise<void> }, data: Record<string, unknown>) {
          ops.push(() => ref.set(data));
        },
        commit: vi.fn(async () => {
          for (const op of ops) op();
        }),
      };
    },
    stores,
  };

  return db;
}

vi.mock('@/lib/firebase', () => ({
  COLLECTIONS: {
    PGS: 'pgs',
    TENANTS: 'tenants',
    RENT_RECORDS: 'rentRecords',
    USERS: 'users',
  },
  getDb: vi.fn(),
}));

describe('RentRecordService', () => {
  let mockDb: ReturnType<typeof createMockDb>;
  let service: RentRecordService;

  beforeEach(async () => {
    mockDb = createMockDb();
    const { getDb } = await import('@/lib/firebase');
    vi.mocked(getDb).mockReturnValue(mockDb as never);
    service = new RentRecordService();
  });

  it('generates rent records for active tenants', async () => {
    mockDb.stores.pgs.set('pg1', { rentDueDate: 5 });
    mockDb.stores.tenants.set('t1', {
      uid: 'user1',
      pgId: 'pg1',
      roomId: 'room1',
      rentAmount: 8000,
      status: 'active',
    });

    const result = await service.generateForCurrentMonth('pg1');
    expect(result.created).toBe(1);
    expect(result.month).toBe(new Date().getMonth() + 1);
    expect(mockDb.stores.rentRecords.size).toBe(1);
  });

  it('skips tenants that already have a record for the month', async () => {
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    mockDb.stores.pgs.set('pg1', { rentDueDate: 5 });
    mockDb.stores.tenants.set('t1', {
      uid: 'user1',
      pgId: 'pg1',
      roomId: 'room1',
      rentAmount: 8000,
      status: 'active',
    });
    mockDb.stores.rentRecords.set('existing', {
      pgId: 'pg1',
      tenantId: 'user1',
      month,
      year,
    });

    const result = await service.generateForCurrentMonth('pg1');
    expect(result.created).toBe(0);
    expect(mockDb.stores.rentRecords.size).toBe(1);
  });

  it('lists records with tenant names', async () => {
    mockDb.stores.rentRecords.set('r1', {
      pgId: 'pg1',
      tenantId: 'user1',
      roomId: 'room1',
      month: 6,
      year: 2025,
      amount: 8000,
      lateFine: 0,
      status: 'unpaid',
      createdAt: { toMillis: () => Date.now() },
    });
    mockDb.stores.users.set('user1', { name: 'Kavya' });

    const records = await service.listRecords('pg1');
    expect(records).toHaveLength(1);
    expect(records[0].tenantName).toBe('Kavya');
  });
});
