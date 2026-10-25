import js from '@eslint/js';
import tseslint from 'typescript-eslint';

// Determinism rule: chaincode runs on several endorsers, which must agree exactly.
// These calls give each endorser a different answer, so the lint fails on them.
const io = ['http', 'https', 'net', 'dgram', 'child_process', 'fs', 'os', 'node-fetch'];
const nonDeterministic = {
    'no-restricted-properties': ['error',
        {object: 'Math', property: 'random', message: 'Random numbers differ by endorser.'},
        {object: 'Date', property: 'now', message: 'Use ctx.stub.getDateTimestamp().'},
        {object: 'process', property: 'env', message: 'Peers do not share environment.'},
        {object: 'crypto', property: 'randomUUID', message: 'Derive ids from getTxID().'},
    ],
    'no-restricted-syntax': ['error',
        {selector: "NewExpression[callee.name='Date'][arguments.length=0]",
            message: 'new Date() reads the system clock; use ctx.stub.getDateTimestamp().'},
        {selector: 'CallExpression[callee.name=/^set(Timeout|Interval|Immediate)$/]',
            message: 'Timers make chaincode depend on scheduling.'},
    ],
    'no-restricted-imports': ['error', {paths: io.map((name) => ({name,
        message: 'Chaincode must not depend on I/O outside the ledger.'}))}],
};

const testProject = {project: 'tsconfig.test.json', tsconfigRootDir: import.meta.dirname};

export default tseslint.config(
    js.configs.recommended,
    ...tseslint.configs.recommendedTypeChecked,
    {
        languageOptions: {
            parserOptions: {project: 'tsconfig.json', tsconfigRootDir: import.meta.dirname},
        },
        rules: nonDeterministic,
    },
    {files: ['lint-examples/**/*.ts'], languageOptions: {parserOptions: testProject}},
    {
        // Tests and fakes run on a developer machine, not on endorsers
        files: ['src/**/*.spec.ts', 'src/test-support/**/*.ts'],
        languageOptions: {parserOptions: testProject},
        rules: {
            'no-restricted-syntax': 'off',
            'no-restricted-properties': 'off',
            '@typescript-eslint/require-await': 'off',
            '@typescript-eslint/no-unused-expressions': 'off',
        },
    },
);
