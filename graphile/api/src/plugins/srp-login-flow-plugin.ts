/* eslint-disable max-lines-per-function */
import { gql, makeExtendSchemaPlugin } from 'graphile-utils'
import { SRPServer } from 'srp6a'
import {
    initiateSession,
    retrieveLoginFlow,
    saveLoginFlow,
    selectSrpCredsByEmail,
} from '../sql/generated'
import { EgUserRole } from '../types/EgUserRole'
import { queryOne } from '../utils/pg-query-utils'

let srpServer: SRPServer

export const SrpLoginFlowPlugin = makeExtendSchemaPlugin(() => ({
    typeDefs: gql`
        input InitiateSrpLoginInput {
            email: String!
            clientPublicKey: String!
        }

        type InitiateSrpLoginPayload {
            loginFlowId: String
            serverPublicKey: String
        }

        input CompleteSrpLoginInput {
            loginFlowId: String!
            clientProof: String!
        }

        type CompleteSrpLoginResponse {
            serverProof: String
        }

        extend type Mutation {
            """
            Use this mutation to initiate the SRP login flow
            """
            initiateSrpLogin(
                input: InitiateSrpLoginInput!
            ): InitiateSrpLoginPayload

            """
            Use this mutation to complete the SRP login flow.
            If the server proof returned is null, the client
            proof is invalid.
            """
            completeSrpLogin(
                input: CompleteSrpLoginInput!
            ): CompleteSrpLoginResponse
        }
    `,
    resolvers: {
        Mutation: {
            initiateSrpLogin: async (_mutation, args, context) => {
                if (context.userRole !== EgUserRole.ANON) {
                    throw new Error('Cannot login while in existing session.')
                }
                const { email, clientPublicKey } = args.input
                const { rows } = await context.pgClient.query(
                    selectSrpCredsByEmail({ email })
                )
                if (rows.length !== 1) {
                    return {}
                }
                const { id: userId, verifier, salt } = rows[0]

                srpServer = new SRPServer('default')
                if (
                    !srpServer.setCredentials(
                        email,
                        Buffer.from(verifier, 'base64'),
                        Buffer.from(salt, 'base64')
                    )
                ) {
                    throw new Error('Failed to set SRP credentials')
                }

                if (
                    !srpServer.setClientKey(
                        Buffer.from(clientPublicKey, 'base64')
                    )
                ) {
                    throw new Error('Failed to set SRP client key')
                }

                const serializedServerState = serializeSrpServer(srpServer)
                const { id: loginFlowId } = await queryOne(
                    context.pgClient,
                    saveLoginFlow({ userId, serializedServerState })
                )

                return {
                    loginFlowId,
                    serverPublicKey: srpServer.publicKey.toString('base64'),
                }
            },
            completeSrpLogin: async (_mutation, args, context) => {
                if (context.userRole !== EgUserRole.ANON) {
                    throw new Error('Cannot login while in existing session.')
                }
                const { loginFlowId, clientProof } = args.input
                const { rows } = await context.pgClient.query(
                    retrieveLoginFlow({ loginFlowId })
                )
                if (rows.length !== 1) {
                    throw new Error(
                        'Login flow with ID is not present or has expired.'
                    )
                }
                const {
                    serialized_server_state: serializedServerState,
                    user_id: userId,
                } = rows[0]
                const srpServer = deserializeSrpServer(serializedServerState)
                if (
                    !srpServer.validateProof(Buffer.from(clientProof, 'base64'))
                ) {
                    return {}
                }
                const sessionId = srpServer.sessionKey.toString('base64')
                await queryOne(
                    context.pgClient,
                    initiateSession({ sessionId, userId })
                )
                return {
                    serverProof: srpServer.proof.toString('base64'),
                }
            },
        },
    },
}))

// ======================
// Serializing and deserializing server state will be contributed back
// to the library
// ======================

const serializeSrpServer = (srpServer: SRPServer): string => {
    return Buffer.from(
        JSON.stringify({
            /* eslint-disable @typescript-eslint/ban-ts-comment */
            // @ts-ignore
            username: srpServer._username.toString('base64'),
            // @ts-ignore
            verifier: srpServer._verifier.toString('base64'),
            // @ts-ignore
            salt: srpServer._salt.toString('base64'),
            // @ts-ignore
            ephemeralSecretKey: srpServer._ephemeralKey.secretKey.toString(
                'base64'
            ),
            // @ts-ignore
            ephemeralPublicKey: srpServer._ephemeralKey.publicKey.toString(
                'base64'
            ),
            // @ts-ignore
            clientKey: srpServer._clientKey.toString('base64'),
            // @ts-ignore
            proof: srpServer._proof.toString('base64'),
            // @ts-ignore
            clientProof: srpServer._clientProof.toString('base64'),
            // @ts-ignore
            sessionKey: srpServer._sessionKey.toString('base64'),
            // @ts-ignore
            state: srpServer._state,
            /* eslint-enable @typescript-eslint/ban-ts-comment */
        })
    ).toString('base64')
}

const deserializeSrpServer = (serializedServerState: string): SRPServer => {
    const deserializedState = JSON.parse(
        Buffer.from(serializedServerState, 'base64').toString()
    )
    const server = new SRPServer('default')
    /* eslint-disable @typescript-eslint/ban-ts-comment */
    // @ts-ignore
    server._username = Buffer.from(deserializedState.username, 'base64')
    // @ts-ignore
    server._verifier = Buffer.from(deserializedState.verifier, 'base64')
    // @ts-ignore
    server._salt = Buffer.from(deserializedState.salt, 'base64')
    // @ts-ignore
    server._ephemeralKey = {
        secretKey: Buffer.from(deserializedState.ephemeralSecretKey, 'base64'),
        publicKey: Buffer.from(deserializedState.ephemeralPublicKey, 'base64'),
    }
    // @ts-ignore
    server._clientKey = Buffer.from(deserializedState.clientKey, 'base64')
    // @ts-ignore
    server._proof = Buffer.from(deserializedState.proof, 'base64')
    // @ts-ignore
    server._clientProof = Buffer.from(deserializedState.clientProof, 'base64')
    // @ts-ignore
    server._sessionKey = Buffer.from(deserializedState.sessionKey, 'base64')
    // @ts-ignore
    server._state = deserializedState.state
    /* eslint-enable @typescript-eslint/ban-ts-comment */
    return server
}
