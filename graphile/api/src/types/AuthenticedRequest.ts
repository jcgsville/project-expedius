import { Request } from 'express'
import { EgUserRole } from '~common/models/EgUserRole'

export type AuthenticatedRequest = Request & {
    userId?: string
    userRole: EgUserRole
}
