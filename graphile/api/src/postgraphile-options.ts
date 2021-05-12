import { EnvironmentName, requireNodeEnv } from './utils/env-utils'

import { PostGraphileOptions } from 'postgraphile'
import { SmartTagsPlugin } from './plugins/smart-tags-plugin'
import { NodePlugin } from 'graphile-build'
import PgSimplifyInflectorPlugin from '@graphile-contrib/pg-simplify-inflector'
import { RemoveQueryQueryPlugin } from './plugins/remove-root-query-plugin'

export const generatePostgraphileOptions = (): PostGraphileOptions => {
    const isDev = requireNodeEnv() === EnvironmentName.DEV

    return {
        graphiql: isDev,
        enhanceGraphiql: isDev,
        allowExplain: isDev,
        showErrorStack: 'json',
        extendedErrors: ['hint', 'detail', 'errcode'],
        skipPlugins: [NodePlugin],
        appendPlugins: [
            PgSimplifyInflectorPlugin,
            RemoveQueryQueryPlugin,
            SmartTagsPlugin,
        ],
    }
}
