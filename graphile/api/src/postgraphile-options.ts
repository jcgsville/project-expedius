import { PostGraphileOptions } from 'postgraphile'
import { EnvironmentName, requireNodeEnv } from './utils/env-utils'

export const generatePostgraphileOptions = (): PostGraphileOptions => {
    const isDev = requireNodeEnv() === EnvironmentName.DEV

    return {
        graphiql: isDev,
        enhanceGraphiql: isDev,
        allowExplain: isDev,
        showErrorStack: 'json',
        extendedErrors: ['hint', 'detail', 'errcode'],
    }
}
