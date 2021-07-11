import { Pool } from 'pg'
import { requireEnvVar } from '~common/utils/env-utils'

export const constructPgPool = (): Pool => {
    const dbConnectionString = requireEnvVar('DATABASE_URL')
    return new Pool({ connectionString: dbConnectionString })
}
