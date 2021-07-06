import { Request } from 'express'
import { EgUserRole } from './EgUserRole'

export type AuthenticatedRequest = Request & {
    userId?: string
    userRole: EgUserRole
}
