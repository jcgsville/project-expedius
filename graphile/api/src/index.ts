import fastify from 'fastify'
import { postgraphile } from 'postgraphile'
import { addPostgraphileToFastify } from './add-postgraphile-to-fastify'
import { generatePostgraphileOptions } from './postgraphile-options'
import { constructPgPool } from './utils/construct-pg-pool'
import { envVarToBool, portFromEnv } from './utils/env-utils'

const pgPool = constructPgPool()
const postgraphileDbSchemas = ['eg_public']

const fastifyInstance = fastify({ logger: true })
const postgraphileMiddleware = postgraphile(
    pgPool,
    postgraphileDbSchemas,
    generatePostgraphileOptions()
)

if (envVarToBool('EXPORT_GQL_SCHEMA_ONLY')) {
    fastifyInstance.log.info(
        'Exporting the schema only. Returning before starting server.'
    )
    process.exit(0)
}

addPostgraphileToFastify(fastifyInstance, postgraphileMiddleware)

const start = async () => {
    try {
        await fastifyInstance.listen(portFromEnv('PORT', 13001))
    } catch (err) {
        fastifyInstance.log.error(err)
        process.exit(1)
    }
}
start()
