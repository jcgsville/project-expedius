export const requireEnvVar = (variableName: string): string => {
    const envVar = process.env[variableName]
    if (!envVar) {
        throw new Error(`Environment variable ${variableName} is required.`)
    }
    return envVar
}

export enum EnvironmentName {
    DEV = 'development',
    PROD = 'production',
}

export const requireNodeEnv = (): EnvironmentName => {
    const unvalidatedNodeEnv = requireEnvVar('NODE_ENV')
    if (
        !Object.values(EnvironmentName).includes(
            unvalidatedNodeEnv as EnvironmentName
        )
    ) {
        throw new Error(
            `NODE_ENV must be set to one of the following: ${Object.values(
                EnvironmentName
            )}`
        )
    }
    return unvalidatedNodeEnv as EnvironmentName
}

export const portFromEnv = (
    variableName: string,
    defaultPort: number
): number => {
    const envVar = process.env[variableName]
    if (envVar) {
        const portNumber = parseInt(envVar, 10)
        // Usable port numbers taken from https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
        if (isNaN(portNumber) || portNumber < 1024 || portNumber > 49151) {
            throw new Error(`Port env var ${envVar} is not a valid port number`)
        }
        return portNumber
    }
    return defaultPort
}

const TRUTHY_ENV_VAR_VALUES_LOWER_CASED = ['y', 'yes', 't', 'true']

export const envVarToBool = (variableName: string): boolean => {
    const envVar = process.env[variableName]
    return (
        !!envVar &&
        TRUTHY_ENV_VAR_VALUES_LOWER_CASED.includes(envVar.toLowerCase())
    )
}
