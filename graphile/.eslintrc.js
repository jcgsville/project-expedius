/* eslint-disable no-undef */
module.exports = {
    parser: '@typescript-eslint/parser',
    plugins: ['@typescript-eslint', 'prettier', 'prefer-arrow'],
    parserOptions: {
        project: './tsconfig.eslint.json',
        tsconfigRootDir: __dirname,
    },
    extends: [
        'eslint:recommended',
        'plugin:@typescript-eslint/eslint-recommended',
        'plugin:@typescript-eslint/recommended',
        'plugin:prettier/recommended',
    ],
    overrides: [
        {
            files: ['*.test.ts'],
            rules: {
                'max-lines': 'off',
                'max-lines-per-function': 'off',
                'no-unused-expressions': 'off',
            },
        },
    ],
    rules: {
        '@typescript-eslint/array-type': [
            'error',
            {
                default: 'array',
            },
        ],
        '@typescript-eslint/explicit-module-boundary-types': [
            'error',
            {
                allowArgumentsExplicitlyTypedAsAny: true,
            },
        ],
        '@typescript-eslint/member-ordering': 'error',
        '@typescript-eslint/naming-convention': [
            'error',
            {
                selector: 'typeParameter',
                format: ['PascalCase'],
                prefix: ['T'],
            },
            {
                selector: 'memberLike',
                modifiers: ['private'],
                format: ['camelCase'],
                leadingUnderscore: 'require',
            },
        ],
        '@typescript-eslint/no-explicit-any': 'off',
        '@typescript-eslint/no-extraneous-class': 'error',
        '@typescript-eslint/no-parameter-properties': 'error',
        '@typescript-eslint/no-require-imports': 'error',
        '@typescript-eslint/no-unnecessary-condition': 'off',
        '@typescript-eslint/no-unnecessary-type-arguments': 'error',
        '@typescript-eslint/no-useless-constructor': 'error',
        '@typescript-eslint/no-use-before-define': 'off',
        '@typescript-eslint/prefer-for-of': 'error',
        '@typescript-eslint/prefer-readonly': 'error',
        '@typescript-eslint/promise-function-async': 'error',
        camelcase: 'error',
        'comma-dangle': ['error', 'always-multiline'],
        curly: 'error',
        eqeqeq: ['error', 'always'],
        'id-length': [
            'error',
            {
                min: 2,
                exceptions: ['_'],
            },
        ],
        'max-depth': [2, 4],
        'max-len': [
            'error',
            {
                code: 100,
                comments: 120,
                ignorePattern: '^import\\s.+\\sfrom\\s.+;?$',
                ignoreStrings: true,
                ignoreRegExpLiterals: true,
                ignoreTemplateLiterals: true,
                ignoreTrailingComments: true,
                ignoreUrls: true,
            },
        ],
        'max-lines': 'off',
        'max-lines-per-function': [
            'error',
            {
                max: 100,
                skipBlankLines: true,
                skipComments: true,
            },
        ],
        'no-array-constructor': 'error',
        'no-else-return': 'error',
        'no-empty-function': 'error',
        'no-extra-semi': 'error',
        'no-invalid-this': 'error',
        'no-lonely-if': 'off',
        'no-negated-condition': 'error',
        'no-nested-ternary': 'error',
        'no-new-object': 'error',
        'no-param-reassign': 'error',
        'no-plusplus': 'error',
        'no-return-await': 'error',
        'no-tabs': 'error',
        'no-throw-literal': 'error',
        'no-unmodified-loop-condition': 'error',
        'no-unused-expressions': 'error',
        'no-useless-call': 'error',
        'no-useless-return': 'error',
        'prefer-arrow/prefer-arrow-functions': 'error',
        'prettier/prettier': [
            'error',
            {
                singleQuote: true,
                tabWidth: 4,
                arrowParens: 'avoid',
                semi: false,
            },
        ],
        'prefer-arrow-callback': 'error',
        quotes: 'off',
        'quote-props': ['error', 'as-needed'],
        'require-await': 'off',
        semi: ['error', 'never'],
        'spaced-comment': ['error', 'always'],
    },
}