export class MissingValueError extends Error {
    key: string;
    query: string | null | undefined;

    error = 'MissingValueError';

    constructor(key: string, query?: string) {
        super(`Missing value for key \`${key}\``);

        this.key = key;
        this.query = query;
    }
}
