import { Pool, PoolClient } from 'pg'

export const withPgClient = async <TCallbackReturn extends unknown>(
    pgPool: Pool,
    callback: (pgClient: PoolClient) => Promise<TCallbackReturn>
): Promise<TCallbackReturn> => {
    const pgClient = await pgPool.connect()
    try {
        return await callback(pgClient)
    } finally {
        pgClient.release()
    }
}
