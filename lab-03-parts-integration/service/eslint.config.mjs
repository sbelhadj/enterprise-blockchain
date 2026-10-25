import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
    js.configs.recommended,
    ...tseslint.configs.recommendedTypeChecked,
    {
        languageOptions: {
            parserOptions: {project: 'tsconfig.test.json', tsconfigRootDir: import.meta.dirname},
        },
    },
    {
        // fakes in tests are async without awaiting, and throw plain objects like gRPC does
        files: ['test/**/*.ts'],
        rules: {
            '@typescript-eslint/no-unused-expressions': 'off',
            '@typescript-eslint/require-await': 'off',
            '@typescript-eslint/only-throw-error': 'off',
        },
    },
);
