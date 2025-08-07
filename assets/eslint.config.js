import globals from 'globals'
import js from '@eslint/js'
import stylistic from '@stylistic/eslint-plugin'

export default [
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.jest,
        global: 'writable',
      },
      ecmaVersion: 12,
      sourceType: 'module',
    },
  },
  js.configs.recommended,
  stylistic.configs.recommended,
  {
    rules: {
      'no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
        },
      ],
    },
  },
]
