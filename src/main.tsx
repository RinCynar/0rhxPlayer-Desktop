import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';
import { applyTheme, DEFAULT_SEED_HEX } from './theme/theme';

// Immediate theme initialization on cold boot
if (typeof window !== 'undefined') {
  const initialSeed =
    localStorage.getItem('theme_seed') ||
    localStorage.getItem('0rhx_custom_seed_color') ||
    DEFAULT_SEED_HEX;
  const initialMode =
    (localStorage.getItem('theme_mode') ||
      localStorage.getItem('0rhx_theme_mode') ||
      'dark') as 'dark' | 'light';
  applyTheme(initialSeed, initialMode);
}

// Global context menu & shortcut protection
if (typeof window !== 'undefined') {
  window.addEventListener('contextmenu', (e) => {
    const target = e.target as HTMLElement;
    if (target && target.tagName !== 'INPUT' && target.tagName !== 'TEXTAREA') {
      e.preventDefault();
    }
  });

  window.addEventListener('keydown', (e) => {
    // Block destructive refresh and print shortcuts
    if (
      e.key === 'F5' ||
      ((e.ctrlKey || e.metaKey) && (e.key === 'r' || e.key === 'R' || e.key === 'p' || e.key === 'P'))
    ) {
      e.preventDefault();
    }
  });
}

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
