import { Client } from 'pg'
import format from 'pg-format'
import { requireEnvVar } from '~common/utils/env-utils'
import yargsInteractive, { Option } from 'yargs-interactive'
import { EgUserRole } from '~common/models/EgUserRole'

// Script to setup DB. Run before graphile migrate's migrations.
// Script needs to be idemptotent.
// This script contains the following types of changes:
// 1. Things that need to be run as a super user. The migrations
//      are run as a separate role.
// 2. All the setup relatd to extensions. Not every command there
//      has to be run as a super user, but better to keep the setup
//      in one place. Additionally, setting the default search path
//      for the DB needs to be done in a separate connection from
//      the migrations, as the db-level default search path seems to
//      be set at connection time, not query time.

const EXTENSIONS_SCHEMA_NAME = 'extensions'

const YARGS_OPTIONS: Option = {
    interactive: {
        default: true,
    },
    superUserDatabaseUrl: {
        type: 'input',
        describe: 'Super user connection string used to initialize DB',
        default: process.env.SUPER_USER_DATABASE_URL,
        prompt: 'if-empty',
    },
    databaseName: {
        type: 'input',
        describe: 'Name of the database being initialized',
        default: process.env.DATABASE_NAME,
        prompt: 'if-empty',
    },
}

const main = async (): Promise<void> => {
    const args = await yargsInteractive()
        .usage('$0 [args]')
        .interactive(YARGS_OPTIONS)
    await initDb(args.superUserDatabaseUrl, args.databaseName)
}

const initDb = async (
    superUserDatabaseUrl: string,
    databaseName: string
): Promise<void> => {
    const migratorRoleName = requireEnvVar('MIGRATOR_ROLE')
    const apiRoleName = requireEnvVar('API_ROLE')

    const pgClient = new Client({
        connectionString: superUserDatabaseUrl,
    })
    await pgClient.connect()

    try {
        await dropPublicSchema(pgClient)
        await createSchema(pgClient, 'extensions', migratorRoleName)
        await revokeCreateOnSchema(pgClient, 'extensions')
        await createExtension(pgClient, 'plpgsql')
        await createExtension(pgClient, 'uuid-ossp')
        await createExtension(pgClient, 'citext')
        await grantSchemaUsage(pgClient, EXTENSIONS_SCHEMA_NAME, apiRoleName)
        await grantSchemaUsage(
            pgClient,
            EXTENSIONS_SCHEMA_NAME,
            EgUserRole.ANON
        )
        await grantSchemaUsage(
            pgClient,
            EXTENSIONS_SCHEMA_NAME,
            EgUserRole.TEACHER
        )
        await grantSchemaUsage(
            pgClient,
            EXTENSIONS_SCHEMA_NAME,
            EgUserRole.STUDENT
        )
        await alterDbSearchPath(pgClient, databaseName)
    } finally {
        await pgClient.end()
    }
}

const dropPublicSchema = async (pgClient: Client): Promise<void> => {
    await pgClient.query('drop schema if exists public;')
}

const createSchema = async (
    pgClient: Client,
    schemaName: string,
    schemaOwnerName?: string
): Promise<void> => {
    await pgClient.query(format('create schema if not exists %I;', schemaName))
    if (schemaOwnerName) {
        await pgClient.query(
            format('alter schema %I owner to %I;', schemaName, schemaOwnerName)
        )
    }
}

const revokeCreateOnSchema = async (
    pgClient: Client,
    schemaName: string
): Promise<void> => {
    await pgClient.query(
        format('revoke create on schema %I from public;', schemaName)
    )
}

const createExtension = async (
    pgClient: Client,
    extensionName: string
): Promise<void> => {
    await pgClient.query(
        format(
            'create extension if not exists %I with schema extensions;',
            extensionName
        )
    )
}

const grantSchemaUsage = async (
    pgClient: Client,
    schemaName: string,
    roleName: string
): Promise<void> => {
    await pgClient.query(
        format('grant usage on schema %I to %I;', schemaName, roleName)
    )
}

const alterDbSearchPath = async (
    pgClient: Client,
    dbName: string
): Promise<void> => {
    await pgClient.query(
        format(
            'alter database %I set search_path to %I;',
            dbName,
            EXTENSIONS_SCHEMA_NAME
        )
    )
}

main().catch(console.error)
