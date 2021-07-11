// For now, we'll copy over utils from /api that we need
// TODO: put them in a common place between /api and /db
export const requireEnvVar = (variableName: string): string => {
    const envVar = process.env[variableName]
    if (!envVar) {
        throw new Error(`Environment variable ${variableName} is required.`)
    }
    return envVar
}
