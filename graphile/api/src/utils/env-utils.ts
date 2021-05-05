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
