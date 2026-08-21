/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        m3: {
          bgDark: '#131317',
          surfaceDark: '#1C1B20',
          cardDark: '#28272F',
          cardHoverDark: '#36343B',
          primaryDark: '#D0BCFF',
          onPrimaryDark: '#381E72',
          primaryContainerDark: '#4F378B',
          secondaryDark: '#CCC2DC',

          bgLight: '#F6F2F8',
          surfaceLight: '#EDE7F0',
          cardLight: '#E2DBE8',
          cardHoverLight: '#D8D0DF',
          primaryLight: '#6750A4',
          onPrimaryLight: '#FFFFFF',
          primaryContainerLight: '#EADDFF',
          secondaryLight: '#625B71',
        },
        md: {
          primary: 'var(--md-sys-color-primary)',
          'on-primary': 'var(--md-sys-color-on-primary)',
          'primary-container': 'var(--md-sys-color-primary-container)',
          'on-primary-container': 'var(--md-sys-color-on-primary-container)',
          secondary: 'var(--md-sys-color-secondary)',
          'on-secondary': 'var(--md-sys-color-on-secondary)',
          'secondary-container': 'var(--md-sys-color-secondary-container)',
          'on-secondary-container': 'var(--md-sys-color-on-secondary-container)',
          tertiary: 'var(--md-sys-color-tertiary)',
          'on-tertiary': 'var(--md-sys-color-on-tertiary)',
          'tertiary-container': 'var(--md-sys-color-tertiary-container)',
          'on-tertiary-container': 'var(--md-sys-color-on-tertiary-container)',
          surface: 'var(--md-sys-color-surface)',
          'on-surface': 'var(--md-sys-color-on-surface)',
          'surface-variant': 'var(--md-sys-color-surface-variant)',
          'on-surface-variant': 'var(--md-sys-color-on-surface-variant)',
          'surface-dim': 'var(--md-sys-color-surface-dim)',
          'surface-bright': 'var(--md-sys-color-surface-bright)',
          'surface-container-lowest': 'var(--md-sys-color-surface-container-lowest)',
          'surface-container-low': 'var(--md-sys-color-surface-container-low)',
          'surface-container': 'var(--md-sys-color-surface-container)',
          'surface-container-high': 'var(--md-sys-color-surface-container-high)',
          'surface-container-highest': 'var(--md-sys-color-surface-container-highest)',
          outline: 'var(--md-sys-color-outline)',
          'outline-variant': 'var(--md-sys-color-outline-variant)',
          shadow: 'var(--md-sys-color-shadow)',
          scrim: 'var(--md-sys-color-scrim)',
        }
      },
      borderRadius: {
        'xs': '4px',
        'sm': '8px',
        'md': '12px',
        'lg': '16px',
        'xl': '20px',
        '2xl': '24px',
        '3xl': '28px',
        'full': '9999px',
      },
      fontFamily: {
        brand: ['"Google Sans Flex"', '"Google Sans"', 'sans-serif'],
        sans: ['"Noto Sans"', '"Noto Sans SC"', '"Noto Sans JP"', 'Inter', 'system-ui', '-apple-system', 'sans-serif'],
      }
    },
  },
  plugins: [],
}

