import { ClientBase, QueryConfig } from 'pg'

export class PgNotFoundError extends Error {}
export class PgTooManyRowsError extends Error {}

export const queryOne = async <TReturnType extends unknown>(
    pgClient: ClientBase,
    query: QueryConfig
): Promise<TReturnType> => {
    const { rows } = await pgClient.query(query)
    if (rows.length < 1) {
        throw new PgNotFoundError()
    }
    if (rows.length > 1) {
        throw new PgTooManyRowsError()
    }
    return rows[0]
}
