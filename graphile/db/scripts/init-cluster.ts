import { Client } from 'pg'
import format from 'pg-format'
import yargsInteractive, { Option } from 'yargs-interactive'
import { EgUserRole } from './utils/EgUserRole'
import { requireEnvVar } from './utils/require-env-var'

// Script to set up cluster-level objects. Most (not all) of these
// queries require super user access. Script is idempotent.

const YARGS_OPTIONS: Option = {
    dev: {
        type: 'checkbox',
        describe: 'Whether or not this is a development environment',
        default: false,
        prompt: 'never',
    },
}

const main = async (): Promise<void> => {
    const args = await yargsInteractive()
        .usage('$0 [args]')
        .interactive(YARGS_OPTIONS)
    await initCluster(args.dev)
}

const PG_PUBLIC_ROLE_NAME = 'public'

const initCluster = async (isDev: boolean): Promise<void> => {
    const databaseName = requireEnvVar('DATABASE_NAME')
    const shadowDatabaseName = `${databaseName}_shadow`
    const migratorRoleName = requireEnvVar('MIGRATOR_ROLE')
    const migratorRolePassword = requireEnvVar('MIGRATOR_ROLE_PASSWORD')
    const apiRoleName = requireEnvVar('API_ROLE')
    const apiRolePassword = requireEnvVar('API_ROLE_PASSWORD')

    const pgClient = new Client({
        connectionString: requireEnvVar('ROOT_DATABASE_URL'),
    })
    await pgClient.connect()

    try {
        await creatLoginRoleIfNotExists(
            pgClient,
            migratorRoleName,
            migratorRolePassword
        )
        await createDbIfNotExists(pgClient, databaseName, migratorRoleName)
        await grantConnectPrivelegesIfNecessary(
            pgClient,
            migratorRoleName,
            databaseName
        )

        if (isDev) {
            await createDbIfNotExists(
                pgClient,
                shadowDatabaseName,
                migratorRoleName
            )
        }

        await creatLoginRoleIfNotExists(pgClient, apiRoleName, apiRolePassword)
        await grantConnectPrivelegesIfNecessary(
            pgClient,
            apiRoleName,
            databaseName
        )

        await createRoleIfNotExists(pgClient, EgUserRole.ANON)
        await grantRoleMembershipIfNecessary(
            pgClient,
            EgUserRole.ANON,
            apiRoleName
        )

        await createRoleIfNotExists(pgClient, EgUserRole.STUDENT)
        await grantRoleMembershipIfNecessary(
            pgClient,
            EgUserRole.STUDENT,
            apiRoleName
        )
        await createRoleIfNotExists(pgClient, EgUserRole.TEACHER)
        await grantRoleMembershipIfNecessary(
            pgClient,
            EgUserRole.TEACHER,
            apiRoleName
        )
    } finally {
        await pgClient.end()
    }
}

// These functions to create resources are not robust enough to change proprties
// such as a role's password or a DB's owner if they don't align with what's configured
// thy simply create the resource if it doesn't exist

const creatLoginRoleIfNotExists = async (
    pgClient: Client,
    roleName: string,
    rolePassword: string
): Promise<void> => {
    if (!(await doesRoleExist(pgClient, roleName))) {
        await pgClient.query(
            format('create user %I password %L;', roleName, rolePassword)
        )
        console.log(`Created login role ${roleName}.`)
    }
}

const createRoleIfNotExists = async (
    pgClient: Client,
    roleName: string
): Promise<void> => {
    if (!(await doesRoleExist(pgClient, roleName))) {
        await pgClient.query(format('create role %I;', roleName))
        console.log(`Created role ${roleName}.`)
    }
}

const doesRoleExist = async (
    pgClient: Client,
    roleName: string
): Promise<boolean> =>
    queryReturnsAtLeastOneRow(
        pgClient,
        'select 1 from pg_roles where rolname = $1;',
        [roleName]
    )

const createDbIfNotExists = async (
    pgClient: Client,
    dbName: string,
    ownerRoleName: string
): Promise<void> => {
    if (!(await dbExists(pgClient, dbName))) {
        await pgClient.query(
            format('create database %I owner %I;', dbName, ownerRoleName)
        )
        console.log(`Created db ${dbName} with owner ${ownerRoleName}.`)
    }
    // Do this once and it seems like future login roles created
    // will not have connect privileges for this DB. I haven't found
    // any documentation confirming this, it's just based on testing
    await revokePublicConnectIfNecessary(pgClient, dbName)
}

const dbExists = async (pgClient: Client, dbName: string): Promise<boolean> =>
    queryReturnsAtLeastOneRow(
        pgClient,
        'select 1 from pg_database where datname = $1;',
        [dbName]
    )

const grantConnectPrivelegesIfNecessary = async (
    pgClient: Client,
    roleName: string,
    dbName: string
): Promise<void> => {
    if (!(await roleHasConnectPriveleges(pgClient, roleName, dbName))) {
        await pgClient.query(
            format('grant connect on database %I to %I;', dbName, roleName)
        )
        console.log(`Granted ${roleName} ability to connect to ${dbName}.`)
    }
}

const revokePublicConnectIfNecessary = async (
    pgClient: Client,
    dbName: string
): Promise<void> => {
    await pgClient.query(
        format(
            'revoke connect on database %I from %I;',
            dbName,
            PG_PUBLIC_ROLE_NAME
        )
    )
    console.log(`Revoked public roles ability to connect to ${dbName}.`)
}

const roleHasConnectPriveleges = async (
    pgClient: Client,
    roleName: string,
    dbName: string
): Promise<boolean> =>
    queryReturnsAtLeastOneRow(
        pgClient,
        "select 1 from pg_roles where has_database_privilege($1, $2, 'connect');",
        [roleName, dbName]
    )

const grantRoleMembershipIfNecessary = async (
    pgClient: Client,
    roleNameToGrant: string,
    grantedToRoleName: string
): Promise<void> => {
    if (!(await isRoleMember(pgClient, roleNameToGrant, grantedToRoleName))) {
        await pgClient.query(
            format('grant %I to %I;', roleNameToGrant, grantedToRoleName)
        )
        console.log(`Granted ${roleNameToGrant} to ${grantedToRoleName}.`)
    }
}

const isRoleMember = async (
    pgClient: Client,
    roleNameToGrant: string,
    grantedToRoleName: string
): Promise<boolean> =>
    queryReturnsAtLeastOneRow(
        pgClient,
        "select 1 from pg_roles where pg_has_role($1, oid, 'member') and rolname = $2;",
        [grantedToRoleName, roleNameToGrant]
    )

const queryReturnsAtLeastOneRow = async (
    pgClient: Client,
    queryString: string,
    queryValues?: string[]
): Promise<boolean> => {
    const { rowCount } = await pgClient.query(queryString, queryValues)
    return rowCount > 0
}

main().catch(console.error)
