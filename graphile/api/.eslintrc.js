/* eslint-disable no-undef */
module.exports = {
    extends: ['../.eslintrc'],
    ignorePatterns: ['**/sql/generated/*'],
    parser: '@typescript-eslint/parser',
    parserOptions: {
        project: './tsconfig.eslint.json',
        tsconfigRootDir: __dirname,
    },
}
