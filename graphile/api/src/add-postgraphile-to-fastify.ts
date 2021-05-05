import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify'
import {
    HttpRequestHandler,
    PostGraphileResponse,
    PostGraphileResponseFastify3,
} from 'postgraphile'

const convertHandler = (
    handler: (res: PostGraphileResponse) => Promise<void>
) => async (request: FastifyRequest, reply: FastifyReply) =>
    handler(new PostGraphileResponseFastify3(request, reply))

export const addPostgraphileToFastify = (
    fastifyInstance: FastifyInstance,
    postgraphileMiddleware: HttpRequestHandler
): void => {
    // OPTIONS requests, for CORS/etc
    fastifyInstance.options(
        postgraphileMiddleware.graphqlRoute,
        convertHandler(postgraphileMiddleware.graphqlRouteHandler)
    )

    // This is the main middleware
    fastifyInstance.post(
        postgraphileMiddleware.graphqlRoute,
        convertHandler(postgraphileMiddleware.graphqlRouteHandler)
    )

    // GraphiQL, if you need it
    if (postgraphileMiddleware.options.graphiql) {
        if (postgraphileMiddleware.graphiqlRouteHandler) {
            fastifyInstance.head(
                postgraphileMiddleware.graphiqlRoute,
                convertHandler(postgraphileMiddleware.graphiqlRouteHandler)
            )
            fastifyInstance.get(
                postgraphileMiddleware.graphiqlRoute,
                convertHandler(postgraphileMiddleware.graphiqlRouteHandler)
            )
        }
        // Remove this if you don't want the PostGraphile logo as your favicon!
        if (postgraphileMiddleware.faviconRouteHandler) {
            fastifyInstance.get(
                '/favicon.ico',
                convertHandler(postgraphileMiddleware.faviconRouteHandler)
            )
        }
    }
}
