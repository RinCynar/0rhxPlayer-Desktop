import {
  themeFromSourceColor,
  argbFromHex,
  hexFromArgb,
} from '@material/material-color-utilities';

export const DEFAULT_SEED_HEX = '#39C5BB';

export function applyThemeColor(hex: string, isDark: boolean = false) {
  try {
    const validHex = hex && hex.startsWith('#') && hex.length >= 4 ? hex : DEFAULT_SEED_HEX;
    const argb = argbFromHex(validHex);
    const theme = themeFromSourceColor(argb);
    const scheme = isDark ? theme.schemes.dark : theme.schemes.light;

    const root = document.documentElement;

    const setVar = (name: string, argbVal: number) => {
      root.style.setProperty(`--md-sys-color-${name}`, hexFromArgb(argbVal));
    };

    setVar('primary', scheme.primary);
    setVar('on-primary', scheme.onPrimary);
    setVar('primary-container', scheme.primaryContainer);
    setVar('on-primary-container', scheme.onPrimaryContainer);

    setVar('secondary', scheme.secondary);
    setVar('on-secondary', scheme.onSecondary);
    setVar('secondary-container', scheme.secondaryContainer);
    setVar('on-secondary-container', scheme.onSecondaryContainer);

    setVar('tertiary', scheme.tertiary);
    setVar('on-tertiary', scheme.onTertiary);
    setVar('tertiary-container', scheme.tertiaryContainer);
    setVar('on-tertiary-container', scheme.onTertiaryContainer);

    setVar('surface', scheme.surface);
    setVar('on-surface', scheme.onSurface);
    setVar('surface-variant', scheme.surfaceVariant);
    setVar('on-surface-variant', scheme.onSurfaceVariant);

    setVar('outline', scheme.outline);
    setVar('outline-variant', scheme.outlineVariant);
    setVar('shadow', scheme.shadow);
    setVar('scrim', scheme.scrim);

    // Container elevations
    if (isDark) {
      root.style.setProperty('--md-sys-color-surface-dim', hexFromArgb(scheme.surface));
      root.style.setProperty('--md-sys-color-surface-bright', hexFromArgb(scheme.surfaceVariant));
      root.style.setProperty('--md-sys-color-surface-container-lowest', '#0F0D13');
      root.style.setProperty('--md-sys-color-surface-container-low', hexFromArgb(scheme.surfaceVariant));
      root.style.setProperty('--md-sys-color-surface-container', hexFromArgb(scheme.surface));
      root.style.setProperty('--md-sys-color-surface-container-high', hexFromArgb(scheme.surfaceVariant));
      root.style.setProperty('--md-sys-color-surface-container-highest', hexFromArgb(scheme.inverseSurface));
    } else {
      root.style.setProperty('--md-sys-color-surface-dim', '#DED8E1');
      root.style.setProperty('--md-sys-color-surface-bright', '#FEF7FF');
      root.style.setProperty('--md-sys-color-surface-container-lowest', '#FFFFFF');
      root.style.setProperty('--md-sys-color-surface-container-low', '#F7F2FA');
      root.style.setProperty('--md-sys-color-surface-container', '#F3EDF7');
      root.style.setProperty('--md-sys-color-surface-container-high', '#ECE6F0');
      root.style.setProperty('--md-sys-color-surface-container-highest', '#E6E0E9');
    }
  } catch (err) {
    console.error('Failed to apply theme color:', err);
  }
}
