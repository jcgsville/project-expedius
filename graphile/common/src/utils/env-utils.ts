export const requireEnvVar = (variableName: string): string => {
    const envVar = process.env[variableName]
    if (!envVar) {
        throw new Error(`Environment variable ${variableName} is required.`)
    }
    return envVar
}
