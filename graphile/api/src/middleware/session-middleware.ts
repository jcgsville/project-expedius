import { RequestHandler } from 'express'
import { Pool } from 'pg'
import { retrieveSession } from '../sql/generated'
import { queryOne } from '../utils/pg-query-utils'
import { withPgClient } from '../utils/with-pg-client'

const SESSION_HEADER_REGEXP = /Session (?<sessionId>.+)/

// TODO: tweak the types to be able to remove the ts-ignore

export const generateSessionMiddleware = (pgPool: Pool): RequestHandler => {
    const middleware: RequestHandler = (req, res, next) => {
        const sessionId =
            req.cookies.Session ||
            sessionIdAuthHeader(req.headers.authorization)
        if (sessionId) {
            withPgClient(pgPool, async pgClient =>
                queryOne(pgClient, retrieveSession({ sessionId }))
            ).then(({ id }) => {
                if (id) {
                    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
                    // @ts-ignore
                    req.userId = id
                    next()
                } else {
                    res.sendStatus(401)
                }
            })
        } else {
            // eslint-disable-next-line @typescript-eslint/ban-ts-comment
            // @ts-ignore
            req.userId = null
            next()
        }
    }
    return middleware
}

const sessionIdAuthHeader = (
    authorizationHeader: string | undefined
): string | undefined =>
    authorizationHeader?.match(SESSION_HEADER_REGEXP)?.groups?.sessionId
