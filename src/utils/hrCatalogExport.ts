import { createAdminClient } from '@/utils/supabase/admin';

const PAGE_SIZE = 1000;
const MAX_PAGES = 1000;

/**
 * Reads every page of a table/view using a UNIQUE, stable order (the caller
 * supplies key columns that are together unique). Any query error, a null
 * `data`, or a non-array page is a hard failure — never treated as empty.
 */
export async function fetchAllPages(
    admin: ReturnType<typeof createAdminClient>,
    table: string,
    columns: string,
    orderBy: string[]
): Promise<Record<string, unknown>[]> {
    const rows: Record<string, unknown>[] = [];
    for (let page = 0; page < MAX_PAGES; page++) {
        const from = page * PAGE_SIZE;
        let q: any = admin.from(table).select(columns);
        for (const col of orderBy) q = q.order(col, { ascending: true });
        const { data, error } = await q.range(from, from + PAGE_SIZE - 1);
        if (error) throw new Error(`Failed to fetch ${table}: ${error.message}`);
        if (!Array.isArray(data)) throw new Error(`Malformed response for ${table}: data is not an array`);
        rows.push(...(data as Record<string, unknown>[]));
        if (data.length < PAGE_SIZE) return rows;
    }
    throw new Error(`Pagination guard exceeded for ${table}`);
}
