import { Plugin } from 'postgraphile'

// Copied from https://github.com/graphile/starter/blob/main/%40app/server/src/plugins/RemoveQueryQueryPlugin.ts
export const RemoveRootQueryPlugin: Plugin = builder => {
    builder.hook('GraphQLObjectType:fields', (fields, build, context) => {
        if (context.scope.isRootQuery) {
            // eslint-disable-next-line @typescript-eslint/no-unused-vars
            const { query, ...rest } = fields
            // Drop the `query` field
            return rest
        }
        return fields
    })
}
