/* eslint-disable no-undef */
module.exports = {
    extends: ['../.eslintrc'],
    parser: '@typescript-eslint/parser',
    parserOptions: {
        project: './tsconfig.eslint.json',
        tsconfigRootDir: __dirname,
    },
}
