import express from 'express'
import cookieParser from 'cookie-parser'
import { postgraphile } from 'postgraphile'
import { generatePostgraphileOptions } from './postgraphile-options'
import { constructPgPool } from './utils/construct-pg-pool'
import { envVarToBool, portFromEnv } from './utils/env-utils'
import { generateSessionMiddleware } from './middleware/session-middleware'
import { errorMiddleware } from './middleware/error-middleware'

const port = portFromEnv('PORT', 13001)

const pgPool = constructPgPool()
const postgraphileDbSchemas = ['eg_public']
const postgraphileMiddleware = postgraphile(
    pgPool,
    postgraphileDbSchemas,
    generatePostgraphileOptions()
)

const app = express()
app.use(cookieParser())
app.use(generateSessionMiddleware(pgPool))
app.use(postgraphileMiddleware)
app.use(errorMiddleware)

if (envVarToBool('EXPORT_GQL_SCHEMA_ONLY')) {
    console.log('Exporting the schema only. Returning before starting server.')
    process.exit(0)
}

app.listen(port, () => {
    console.log(`Listening on ${port}`)
})
