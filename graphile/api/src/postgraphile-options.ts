import { EnvironmentName, requireNodeEnv } from './utils/env-utils'

import { PostGraphileOptions } from 'postgraphile'
import { SmartTagsPlugin } from './plugins/smart-tags-plugin'
import { NodePlugin } from 'graphile-build'
import PgSimplifyInflectorPlugin from '@graphile-contrib/pg-simplify-inflector'
import { RemoveRootQueryPlugin } from './plugins/remove-root-query-plugin'
import { SrpLoginFlowPlugin } from './plugins/srp-login-flow-plugin'

export const generatePostgraphileOptions = (): PostGraphileOptions => {
    const isDev = requireNodeEnv() === EnvironmentName.DEV

    return {
        graphiql: isDev,
        enhanceGraphiql: isDev,
        exportGqlSchemaPath: isDev
            ? `${__dirname}/../schema.graphql`
            : undefined,
        allowExplain: isDev,
        showErrorStack: isDev ? 'json' : undefined,
        extendedErrors: isDev ? ['hint', 'detail', 'errcode'] : undefined,
        skipPlugins: [NodePlugin],
        appendPlugins: [
            PgSimplifyInflectorPlugin,
            RemoveRootQueryPlugin,
            SmartTagsPlugin,
            SrpLoginFlowPlugin,
        ],
    }
}
