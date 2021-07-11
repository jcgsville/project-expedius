import { Client, createClient, gql, OperationResult } from '@urql/core'
import 'cross-fetch/polyfill'
import { SRPClient } from 'srp6a'
import yargsInteractive, { Option } from 'yargs-interactive'

const YARGS_OPTIONS: Option = {
    interactive: {
        default: true,
    },
    apiBaseUrl: {
        type: 'input',
        describe: 'Base URL of GQL API to use. E.g. http://localhost:13001',
        default: process.env.API_BASE_URL,
        prompt: 'if-empty',
    },
    userEmail: {
        type: 'input',
        describe: 'Email of user in which to initiate a session',
        default: process.env.LOGIN_USER_EMAIL,
        prompt: 'if-empty',
    },
    password: {
        type: 'input',
        describe: "User's password",
        default: process.env.LOGIN_USER_PASSWORD,
        prompt: 'if-empty',
    },
}

const main = async (): Promise<void> => {
    const args = await yargsInteractive()
        .usage('$0 [args]')
        .interactive(YARGS_OPTIONS)
    const sessionKey = await login(
        args.apiBaseUrl,
        args.userEmail,
        args.password
    )
    console.log(`Session key: ${sessionKey}`)
}

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
    const userLoginSalt = await getUserSalt(gqlClient, userEmail)

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
    const { loginFlowId, serverPublicKey } = await initiateLogin(
        gqlClient,
        userEmail,
        clientPublicKey
    )

    if (!srpClient.setServerKey(Buffer.from(serverPublicKey, 'base64'))) {
        throw Error('Unable to set server public key')
    }

    const clientProof = srpClient.proof.toString('base64')
    const serverProof = await completeLogin(gqlClient, loginFlowId, clientProof)

    if (!srpClient.validateProof(Buffer.from(serverProof, 'base64'))) {
        throw new Error('Server proof invalid')
    }
    return srpClient.sessionKey.toString('base64')
}

const getUserSalt = async (
    gqlClient: Client,
    userEmail: string
): Promise<string> => {
    const { userLoginSalt } = throwIfGqlErrored(
        await gqlClient.query(SALT_QUERY, { userEmail }).toPromise()
    )
    if (!userLoginSalt) {
        throw new Error(`No user with email: ${userEmail}`)
    }
    return userLoginSalt
}

const initiateLogin = async (
    gqlClient: Client,
    userEmail: string,
    clientPublicKey: string
): Promise<{ loginFlowId: string; serverPublicKey: string }> => {
    const {
        initiateSrpLogin: { loginFlowId, serverPublicKey },
    } = throwIfGqlErrored(
        await gqlClient
            .query(INITIATE_MUTATION, {
                userEmail,
                clientPublicKey,
            })
            .toPromise()
    )
    if (!loginFlowId || !serverPublicKey) {
        throw new Error(
            `Initiate login could not find user with email: ${userEmail}`
        )
    }
    return { loginFlowId, serverPublicKey }
}

const completeLogin = async (
    gqlClient: Client,
    loginFlowId: string,
    clientProof: string
): Promise<string> => {
    const {
        completeSrpLogin: { serverProof },
    } = throwIfGqlErrored(
        await gqlClient
            .mutation(COMPLETE_MUTATION, {
                loginFlowId,
                clientProof,
            })
            .toPromise()
    )
    if (!serverProof) {
        throw new Error('Password invalid')
    }
    return serverProof
}

const throwIfGqlErrored = (gqlResult: OperationResult): any => {
    if (gqlResult.error) {
        if (gqlResult.error.networkError) {
            throw new Error(gqlResult.error.networkError.message)
        }
        if (gqlResult.error.graphQLErrors) {
            const errorMessages = gqlResult.error.graphQLErrors.map(
                gqlError => gqlError.message
            )
            throw new Error(errorMessages.join('; '))
        }
        throw new Error('Unkown error when calling GQL')
    }
    return gqlResult.data
}

main().catch(console.error)
