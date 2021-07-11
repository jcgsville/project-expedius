import { ErrorRequestHandler } from 'express'

export enum ERROR_CODES {
    UNAUTHORIZED = 'UNAUTHORIZED',
    INTERNAL = 'INTERNAL_SERVER_ERROR',
}

export const errorMiddleware: ErrorRequestHandler = (err, req, res): void => {
    res.status(500)
        .json({ errors: [{ code: ERROR_CODES.INTERNAL }] })
        .send()
}
