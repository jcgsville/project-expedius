"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fastify_1 = __importDefault(require("fastify"));
const fastifyInstance = fastify_1.default({ logger: true });
// Declare a route
fastifyInstance.get('/', async () => {
    return { hello: 'world' };
});
// Run the server!
const start = async () => {
    try {
        await fastifyInstance.listen(3000);
    }
    catch (err) {
        fastifyInstance.log.error(err);
        process.exit(1);
    }
};
start();
//# sourceMappingURL=index.js.map