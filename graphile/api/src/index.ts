import fastify from 'fastify'

const fastifyInstance = fastify({ logger: true })

// Declare a route
fastifyInstance.get('/', async () => {
    return { hello: 'world' }
})

// Run the server!
const start = async () => {
    try {
        await fastifyInstance.listen(3000)
    } catch (err) {
        fastifyInstance.log.error(err)
        process.exit(1)
    }
}
start()
