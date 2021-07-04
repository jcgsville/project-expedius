import { createClient, gql } from '@urql/core'
import 'cross-fetch/polyfill'
import { SRPClient } from 'srp6a'
import { requireEnvVar } from '../utils/env-utils'

const SALT_QUERY = gql`
    query Salt($userEmail: String!) {
        userLoginSalt(userEmail: $userEmail)
    }
`

const INITIATE_MUTATION = gql`
    mutation Initiate($userEmail: String!, $clientPublicKey: String!) {
        initiateSrpLogin(
            input: { email: $userEmail, clientPublicKey: $clientPublicKey }
        ) {
            loginFlowId
            serverPublicKey
        }
    }
`

const COMPLETE_MUTATION = gql`
    mutation Complete($loginFlowId: String!, $clientProof: String!) {
        completeSrpLogin(
            input: { loginFlowId: $loginFlowId, clientProof: $clientProof }
        ) {
            serverProof
        }
    }
`

// ============
// This would absolutely live in the frontend portion of the repo if I
// was going to build a frontend for this
// ============
const login = async (
    apiBaseUrl: string,
    userEmail: string,
    password: string
): Promise<string> => {
    const gqlClient = createClient({
        url: `${apiBaseUrl}/graphql`,
    })
    const saltResult = await gqlClient
        .query(SALT_QUERY, { userEmail })
        .toPromise()
    const {
        data: { userLoginSalt },
    } = saltResult

    const srpClient = new SRPClient('default')

    if (
        !srpClient.setCredentials(
            userEmail,
            password,
            Buffer.from(userLoginSalt, 'base64')
        )
    ) {
        throw Error('Unable to set client credentials')
    }

    const clientPublicKey = srpClient.publicKey.toString('base64')

    const initiateResult = await gqlClient
        .mutation(INITIATE_MUTATION, {
            userEmail,
            clientPublicKey,
        })
        .toPromise()
    const {
        data: {
            initiateSrpLogin: { loginFlowId, serverPublicKey },
        },
    } = initiateResult

    if (!srpClient.setServerKey(Buffer.from(serverPublicKey, 'base64'))) {
        throw Error('Unable to set server public key')
    }

    const clientProof = srpClient.proof.toString('base64')

    const completeResult = await gqlClient
        .mutation(COMPLETE_MUTATION, {
            loginFlowId,
            clientProof,
        })
        .toPromise()
    const {
        data: {
            completeSrpLogin: { serverProof },
        },
    } = completeResult
    if (!serverProof) {
        throw new Error('Password invalid')
    }
    if (!srpClient.validateProof(Buffer.from(serverProof, 'base64'))) {
        throw new Error('Server proof invalid')
    }

    return srpClient.sessionKey.toString('base64')
}

const main = async (): Promise<void> => {
    const apiBaseUrl = requireEnvVar('API_BASE_URL')
    const userEmail = requireEnvVar('LOGIN_USER_EMAIL')
    const password = requireEnvVar('LOGIN_USER_PASSWORD')
    const sessionKey = await login(apiBaseUrl, userEmail, password)
    console.log(`Session key: ${sessionKey}`)
}

main().catch(console.error)
