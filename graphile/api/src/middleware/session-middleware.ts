import { RequestHandler, Response, NextFunction } from 'express'
import { Pool } from 'pg'
import { retrieveSession } from '../sql/generated'
import { AuthenticatedRequest } from '../types/AuthenticedRequest'
import { EgUserRole } from '../types/EgUserRole'
import { UserType } from '../types/UserType'
import { queryOne } from '../utils/pg-query-utils'
import { withPgClient } from '../utils/with-pg-client'

const SESSION_HEADER_REGEXP = /Session (?<sessionId>.+)/

export const generateSessionMiddleware = (pgPool: Pool): RequestHandler => {
    return (
        req: AuthenticatedRequest,
        res: Response,
        next: NextFunction
    ): void => {
        const sessionId =
            req.cookies.Session ||
            sessionIdAuthHeader(req.headers.authorization)
        if (sessionId) {
            withPgClient(pgPool, async pgClient =>
                queryOne(pgClient, retrieveSession({ sessionId }))
            ).then(({ id, user_type: userType }) => {
                if (id && userType) {
                    req.userId = id
                    req.userRole = roleForUserType(userType)
                    next()
                } else {
                    res.sendStatus(401)
                }
            })
        } else {
            next()
        }
    }
}

const sessionIdAuthHeader = (
    authorizationHeader: string | undefined
): string | undefined =>
    authorizationHeader?.match(SESSION_HEADER_REGEXP)?.groups?.sessionId

const roleForUserType = (userType: UserType): EgUserRole => {
    switch (userType) {
        case 'STUDENT':
            return 'eg_student'
        case 'TEACHER':
            return 'eg_teacher'
        default:
            assertExhaustiveRoleType(userType)
    }
}

// Functions for exhaustive enum checking seem to not work
// with arrow functions
// eslint-disable-next-line prefer-arrow/prefer-arrow-functions
function assertExhaustiveRoleType(userType: never): never {
    throw new Error(`Did not handle user type: ${userType}`)
}
