import fastify from 'fastify'
import { postgraphile } from 'postgraphile'
import { addPostgraphileToFastify } from './add-postgraphile-to-fastify'
import { generatePostgraphileOptions } from './postgraphile-options'
import { constructPgPool } from './utils/construct-pg-pool'

const pgPool = constructPgPool()
const postgraphileDbSchemas = ['eg_public']

const fastifyInstance = fastify({ logger: true })
const postgraphileMiddleware = postgraphile(
    pgPool,
    postgraphileDbSchemas,
    generatePostgraphileOptions()
)

addPostgraphileToFastify(fastifyInstance, postgraphileMiddleware)

// Declare a route
fastifyInstance.get('/', async () => {
    return { hello: 'world' }
})

// Run the server!
const start = async () => {
    try {
        await fastifyInstance.listen(3000)
    } catch (err) {
        fastifyInstance.log.error(err)
        process.exit(1)
    }
}
start()
