import js from '@eslint/js'
import tseslint from 'typescript-eslint'
import reactHooks from 'eslint-plugin-react-hooks'
import globals from 'globals'

export default tseslint.config(
  { ignores: ['out/**', 'dist/**', 'node_modules/**'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['src/main/**/*.ts', 'src/preload/**/*.ts', 'tests/main/**/*.ts', '*.config.{ts,mjs}'],
    languageOptions: { globals: globals.node },
  },
  {
    files: ['src/renderer/**/*.{ts,tsx}', 'tests/renderer/**/*.{ts,tsx}'],
    languageOptions: { globals: globals.browser },
    plugins: { 'react-hooks': reactHooks },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // The renderer must reach Node/Electron only through window.ghp.
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            'electron',
            'node:*',
            'fs',
            'path',
            'child_process',
            'dugite',
            '../main/*',
            '../../main/*',
          ],
        },
      ],
    },
  },
  {
    rules: {
      // Some tools write a UTF-8 BOM; keep sources BOM-free.
      'unicode-bom': ['error', 'never'],
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  }
)
