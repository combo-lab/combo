import globals from 'globals'
import stylistic from '@stylistic/eslint-plugin'

export default [
  {
    languageOptions: {
      globals: {
        ...globals.browser,
      },
      sourceType: 'module',
    },
  },
  stylistic.configs.customize({
    braceStyle: '1tbs',
  }),
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
