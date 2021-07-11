import { RequestHandler, Response, NextFunction } from 'express'
import { Pool } from 'pg'
import { retrieveSession } from '../sql/generated'
import { AuthenticatedRequest } from '../types/AuthenticedRequest'
import { EgUserRole } from '../types/EgUserRole'
import { UserType } from '../types/UserType'
import { queryOne } from '../utils/pg-query-utils'
import { withPgClient } from '../utils/with-pg-client'
import { ERROR_CODES } from './error-middleware'

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
                    res.status(401)
                        .json({
                            errors: [
                                {
                                    code: ERROR_CODES.UNAUTHORIZED,
                                    message:
                                        'Session has expired or is not present.',
                                },
                            ],
                        })
                        .send()
                }
            })
        } else {
            req.userRole = EgUserRole.ANON
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
            return EgUserRole.STUDENT
        case 'TEACHER':
            return EgUserRole.TEACHER
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
