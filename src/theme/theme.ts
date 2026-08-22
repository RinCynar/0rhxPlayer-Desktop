import {
  themeFromSourceColor,
  argbFromHex,
  hexFromArgb,
} from '@material/material-color-utilities';

export const DEFAULT_SEED_HEX = '#39C5BB';

export function isValidHexColor(hex: string): boolean {
  return /^#[0-9A-Fa-f]{6}$/.test(hex);
}

/**
 * Applies a dynamic Material 3 theme generated from a seed color to the document root.
 * Injects complete system tokens for primary, containers, surface levels, and outlines.
 */
export function applyTheme(seedColor: string, mode: 'dark' | 'light' = 'dark') {
  try {
    const isDark = mode === 'dark';
    const cleanSeed = seedColor && isValidHexColor(seedColor)
      ? seedColor
      : (seedColor && seedColor.startsWith('#') && seedColor.length >= 4 ? seedColor : DEFAULT_SEED_HEX);

    const argb = argbFromHex(cleanSeed);
    const theme = themeFromSourceColor(argb);
    const scheme = isDark ? theme.schemes.dark : theme.schemes.light;
    const neutral = theme.palettes.neutral;
    const neutralVariant = theme.palettes.neutralVariant;

    const root = document.documentElement;

    if (isDark) {
      root.classList.add('dark');
      root.style.colorScheme = 'dark';
    } else {
      root.classList.remove('dark');
      root.style.colorScheme = 'light';
    }

    const setHex = (name: string, val: string) => {
      root.style.setProperty(`--md-sys-color-${name}`, val);
    };

    const setArgb = (name: string, argbVal: number) => {
      setHex(name, hexFromArgb(argbVal));
    };

    // Primary
    setArgb('primary', scheme.primary);
    setArgb('on-primary', scheme.onPrimary);
    setArgb('primary-container', scheme.primaryContainer);
    setArgb('on-primary-container', scheme.onPrimaryContainer);

    // Secondary
    setArgb('secondary', scheme.secondary);
    setArgb('on-secondary', scheme.onSecondary);
    setArgb('secondary-container', scheme.secondaryContainer);
    setArgb('on-secondary-container', scheme.onSecondaryContainer);

    // Tertiary
    setArgb('tertiary', scheme.tertiary);
    setArgb('on-tertiary', scheme.onTertiary);
    setArgb('tertiary-container', scheme.tertiaryContainer);
    setArgb('on-tertiary-container', scheme.onTertiaryContainer);

    // Surface & Surface Containers (Pure M3 Tone mapping from neutral palettes)
    setArgb('surface', isDark ? neutral.tone(6) : neutral.tone(98));
    setArgb('on-surface', isDark ? neutral.tone(90) : neutral.tone(10));
    setArgb('surface-variant', isDark ? neutralVariant.tone(30) : neutralVariant.tone(90));
    setArgb('on-surface-variant', isDark ? neutralVariant.tone(80) : neutralVariant.tone(30));

    setArgb('surface-dim', isDark ? neutral.tone(6) : neutral.tone(87));
    setArgb('surface-bright', isDark ? neutral.tone(24) : neutral.tone(98));
    setArgb('surface-container-lowest', isDark ? neutral.tone(4) : neutral.tone(100));
    setArgb('surface-container-low', isDark ? neutral.tone(10) : neutral.tone(96));
    setArgb('surface-container', isDark ? neutral.tone(12) : neutral.tone(94));
    setArgb('surface-container-high', isDark ? neutral.tone(17) : neutral.tone(92));
    setArgb('surface-container-highest', isDark ? neutral.tone(22) : neutral.tone(90));

    // Outline, Shadow, Scrim
    setArgb('outline', isDark ? neutralVariant.tone(60) : neutralVariant.tone(50));
    setArgb('outline-variant', isDark ? neutralVariant.tone(30) : neutralVariant.tone(80));
    setArgb('shadow', scheme.shadow);
    setArgb('scrim', scheme.scrim);

    // Root background color sync for native window
    const surfaceBg = isDark ? hexFromArgb(neutral.tone(6)) : hexFromArgb(neutral.tone(98));
    root.style.backgroundColor = surfaceBg;
  } catch (err) {
    console.error('Failed to apply theme:', err);
  }
}
