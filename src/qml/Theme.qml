pragma Singleton
import QtQuick
import rhx.config 1.0

QtObject {
    id: theme

    // Current seed color and theme mode driven by ConfigManager
    property string seedColor: (typeof ConfigManager !== "undefined" && ConfigManager && ConfigManager.seedColor) ? ConfigManager.seedColor : "#39C5BB"
    property string themeMode: (typeof ConfigManager !== "undefined" && ConfigManager && ConfigManager.themeMode) ? ConfigManager.themeMode : "dark"
    readonly property bool isDark: themeMode === "light" ? false : true

    // ========================================================================
    // Dynamic M3 Palette Engine
    // Supports 8 Authentic M3 Presets + Full Algorithmic HSL Tone Generation
    // ========================================================================
    function hslToHex(h, s, l) {
        l /= 100;
        var a = s * Math.min(l, 1 - l) / 100;
        var f = function(n) {
            var k = (n + h / 30) % 12;
            var color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
            return Math.round(255 * color).toString(16).padStart(2, '0');
        };
        return "#" + f(0) + f(8) + f(4);
    }

    function hexToHsl(hex) {
        var clean = hex.replace("#", "");
        if (clean.length === 3) {
            clean = clean.split('').map(function(c) { return c + c; }).join('');
        }
        var r = parseInt(clean.substring(0, 2), 16) / 255;
        var g = parseInt(clean.substring(2, 4), 16) / 255;
        var b = parseInt(clean.substring(4, 6), 16) / 255;

        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h, s, l = (max + min) / 2;

        if (max === min) {
            h = s = 0; // achromatic
        } else {
            var d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch (max) {
                case r: h = (g - b) / d + (g < b ? 6 : 0); break;
                case g: h = (b - r) / d + 2; break;
                case b: h = (r - g) / d + 4; break;
            }
            h *= 60;
        }
        return { h: Math.round(h), s: Math.round(s * 100), l: Math.round(l * 100) };
    }

    function getPresetTokens(hex, dark) {
        var h = (hex || "").toUpperCase().trim();
        if (h === "#39C5BB") {
            return dark ? {
                primary: "#39C5BB", colorOnPrimary: "#003738", primaryContainer: "#004F50", colorOnPrimaryContainer: "#70F7EC",
                secondary: "#B0CCCB", colorOnSecondary: "#1B3534", secondaryContainer: "#324B4B", colorOnSecondaryContainer: "#CCE8E7",
                tertiary: "#B3C8E8", colorOnTertiary: "#1C314B", tertiaryContainer: "#334863", colorOnTertiaryContainer: "#D3E4FF",
                surface: "#0E1514", colorOnSurface: "#DEE4E3", surfaceVariant: "#3F4948", colorOnSurfaceVariant: "#BEC9C8",
                surfaceContainerLowest: "#090F0F", surfaceContainerLow: "#161D1D", surfaceContainer: "#1A2121", surfaceContainerHigh: "#252B2B", surfaceContainerHighest: "#303636",
                outline: "#889392", outlineVariant: "#3F4948", borderSubtle: "#222524"
            } : {
                primary: "#006A6B", colorOnPrimary: "#FFFFFF", primaryContainer: "#70F7EC", colorOnPrimaryContainer: "#002021",
                secondary: "#4A6363", colorOnSecondary: "#FFFFFF", secondaryContainer: "#CCE8E7", colorOnSecondaryContainer: "#051F20",
                tertiary: "#4B607C", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#D3E4FF", colorOnTertiaryContainer: "#041C35",
                surface: "#F4FBFA", colorOnSurface: "#161D1D", surfaceVariant: "#DAE5E4", colorOnSurfaceVariant: "#3F4948",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#EFF5F4", surfaceContainer: "#E9EFEF", surfaceContainerHigh: "#E3EAE9", surfaceContainerHighest: "#DEE4E3",
                outline: "#6F7979", outlineVariant: "#BEC9C8", borderSubtle: "#E0E6E5"
            };
        } else if (h === "#6750A4") {
            return dark ? {
                primary: "#D0BCFF", colorOnPrimary: "#381E72", primaryContainer: "#4F378B", colorOnPrimaryContainer: "#EADDFF",
                secondary: "#CCC2DC", colorOnSecondary: "#332D41", secondaryContainer: "#4A4458", colorOnSecondaryContainer: "#E8DEF8",
                tertiary: "#EFB8C8", colorOnTertiary: "#492532", tertiaryContainer: "#633B48", colorOnTertiaryContainer: "#FFD8E4",
                surface: "#141218", colorOnSurface: "#E6E0E9", surfaceVariant: "#49454F", colorOnSurfaceVariant: "#CAC4D0",
                surfaceContainerLowest: "#0F0D13", surfaceContainerLow: "#1D1B20", surfaceContainer: "#211F26", surfaceContainerHigh: "#2B2930", surfaceContainerHighest: "#36343B",
                outline: "#938F99", outlineVariant: "#49454F", borderSubtle: "#2A2730"
            } : {
                primary: "#6750A4", colorOnPrimary: "#FFFFFF", primaryContainer: "#EADDFF", colorOnPrimaryContainer: "#21005D",
                secondary: "#625B71", colorOnSecondary: "#FFFFFF", secondaryContainer: "#E8DEF8", colorOnSecondaryContainer: "#1D192B",
                tertiary: "#7D5260", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#FFD8E4", colorOnTertiaryContainer: "#31111D",
                surface: "#FEF7FF", colorOnSurface: "#1D1B20", surfaceVariant: "#E7E0EC", colorOnSurfaceVariant: "#49454F",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#F7F2FA", surfaceContainer: "#F3EDF7", surfaceContainerHigh: "#ECE6F0", surfaceContainerHighest: "#E6E0E9",
                outline: "#79747E", outlineVariant: "#CAC4D0", borderSubtle: "#E4DFE8"
            };
        } else if (h === "#00639B") {
            return dark ? {
                primary: "#97CBFF", colorOnPrimary: "#003355", primaryContainer: "#004B77", colorOnPrimaryContainer: "#CEE5FF",
                secondary: "#B8C8D9", colorOnSecondary: "#233240", secondaryContainer: "#3A4857", colorOnSecondaryContainer: "#D5E4F5",
                tertiary: "#D1C0E8", colorOnTertiary: "#372B4B", tertiaryContainer: "#4E4163", colorOnTertiaryContainer: "#EDDCFF",
                surface: "#101418", colorOnSurface: "#E1E2E8", surfaceVariant: "#41474D", colorOnSurfaceVariant: "#C1C7CE",
                surfaceContainerLowest: "#0B0E12", surfaceContainerLow: "#181C20", surfaceContainer: "#1D2024", surfaceContainerHigh: "#272A2E", surfaceContainerHighest: "#32353A",
                outline: "#8B9198", outlineVariant: "#41474D", borderSubtle: "#25292E"
            } : {
                primary: "#00639B", colorOnPrimary: "#FFFFFF", primaryContainer: "#CEE5FF", colorOnPrimaryContainer: "#001D33",
                secondary: "#51606F", colorOnSecondary: "#FFFFFF", secondaryContainer: "#D5E4F5", colorOnSecondaryContainer: "#0E1D2A",
                tertiary: "#67587A", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#EDDCFF", colorOnTertiaryContainer: "#221534",
                surface: "#F8F9FF", colorOnSurface: "#191C20", surfaceVariant: "#DDE3EA", colorOnSurfaceVariant: "#41474D",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#F2F3FA", surfaceContainer: "#ECEEF4", surfaceContainerHigh: "#E6E8EE", surfaceContainerHighest: "#E0E2E8",
                outline: "#72777E", outlineVariant: "#C1C7CE", borderSubtle: "#DEE1E6"
            };
        } else if (h === "#9C4146") {
            return dark ? {
                primary: "#FFB3B4", colorOnPrimary: "#5F121C", primaryContainer: "#7E2A30", colorOnPrimaryContainer: "#FFDADB",
                secondary: "#E6BDBC", colorOnSecondary: "#44292A", secondaryContainer: "#5D3F40", colorOnSecondaryContainer: "#FFDADA",
                tertiary: "#E5C18D", colorOnTertiary: "#422C05", tertiaryContainer: "#5B4219", colorOnTertiaryContainer: "#FFDDAF",
                surface: "#1A1112", colorOnSurface: "#F0DFDF", surfaceVariant: "#524343", colorOnSurfaceVariant: "#D7C1C1",
                surfaceContainerLowest: "#140C0D", surfaceContainerLow: "#23191A", surfaceContainer: "#271D1E", surfaceContainerHigh: "#322728", surfaceContainerHighest: "#3E3233",
                outline: "#A08C8C", outlineVariant: "#524343", borderSubtle: "#332526"
            } : {
                primary: "#9C4146", colorOnPrimary: "#FFFFFF", primaryContainer: "#FFDADB", colorOnPrimaryContainer: "#40000A",
                secondary: "#775657", colorOnSecondary: "#FFFFFF", secondaryContainer: "#FFDADA", colorOnSecondaryContainer: "#2C1516",
                tertiary: "#755A2F", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#FFDDAF", colorOnTertiaryContainer: "#281800",
                surface: "#FFF8F7", colorOnSurface: "#22191A", surfaceVariant: "#F4DDDD", colorOnSurfaceVariant: "#524343",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#FDF1F1", surfaceContainer: "#F7EBEB", surfaceContainerHigh: "#F2E5E5", surfaceContainerHighest: "#ECE0DF",
                outline: "#857373", outlineVariant: "#D7C1C1", borderSubtle: "#E6D8D8"
            };
        } else if (h === "#4C662B") {
            return dark ? {
                primary: "#B1D18A", colorOnPrimary: "#1F3701", primaryContainer: "#354E16", colorOnPrimaryContainer: "#CDF5A4",
                secondary: "#C0CAAE", colorOnSecondary: "#2B331F", secondaryContainer: "#414A34", colorOnSecondaryContainer: "#DCE6CA",
                tertiary: "#A0D0CB", colorOnTertiary: "#003734", tertiaryContainer: "#1E4E4B", colorOnTertiaryContainer: "#BCECE7",
                surface: "#12140E", colorOnSurface: "#E2E3D8", surfaceVariant: "#44483D", colorOnSurfaceVariant: "#C4C8BA",
                surfaceContainerLowest: "#0D0F0A", surfaceContainerLow: "#1A1D16", surfaceContainer: "#1F211A", surfaceContainerHigh: "#292C24", surfaceContainerHighest: "#34372E",
                outline: "#8E9285", outlineVariant: "#44483D", borderSubtle: "#262920"
            } : {
                primary: "#4C662B", colorOnPrimary: "#FFFFFF", primaryContainer: "#CDF5A4", colorOnPrimaryContainer: "#102000",
                secondary: "#586249", colorOnSecondary: "#FFFFFF", secondaryContainer: "#DCE6CA", colorOnSecondaryContainer: "#151E0B",
                tertiary: "#386663", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#BCECE7", colorOnTertiaryContainer: "#00201E",
                surface: "#F9FAEF", colorOnSurface: "#1A1C16", surfaceVariant: "#E1E4D5", colorOnSurfaceVariant: "#44483D",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#F4F5E9", surfaceContainer: "#EEEFE4", surfaceContainerHigh: "#E8E9DE", surfaceContainerHighest: "#E2E4D8",
                outline: "#75796C", outlineVariant: "#C4C8BA", borderSubtle: "#D9DCD0"
            };
        } else if (h === "#825500") {
            return dark ? {
                primary: "#FFBA53", colorOnPrimary: "#462A00", primaryContainer: "#633F00", colorOnPrimaryContainer: "#FFDDB5",
                secondary: "#DAC3A1", colorOnSecondary: "#3C2E16", secondaryContainer: "#54442A", colorOnSecondaryContainer: "#F8DFBC",
                tertiary: "#B6CE9D", colorOnTertiary: "#233612", tertiaryContainer: "#394D26", colorOnTertiaryContainer: "#D2EAB7",
                surface: "#17130B", colorOnSurface: "#EBE1D7", surfaceVariant: "#4F4539", colorOnSurfaceVariant: "#D2C4B4",
                surfaceContainerLowest: "#120E07", surfaceContainerLow: "#201B12", surfaceContainer: "#241F16", surfaceContainerHigh: "#2F2920", surfaceContainerHighest: "#3B342A",
                outline: "#9B8E80", outlineVariant: "#4F4539", borderSubtle: "#30281F"
            } : {
                primary: "#825500", colorOnPrimary: "#FFFFFF", primaryContainer: "#FFDDB5", colorOnPrimaryContainer: "#2A1800",
                secondary: "#6E5B40", colorOnSecondary: "#FFFFFF", secondaryContainer: "#F8DFBC", colorOnSecondaryContainer: "#261904",
                tertiary: "#51643C", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#D2EAB7", colorOnTertiaryContainer: "#101F02",
                surface: "#FFF8F4", colorOnSurface: "#1F1B13", surfaceVariant: "#EFE0CF", colorOnSurfaceVariant: "#4F4539",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#FAF2E8", surfaceContainer: "#F4ECE2", surfaceContainerHigh: "#EEE6DC", surfaceContainerHighest: "#E8E1D7",
                outline: "#817567", outlineVariant: "#D2C4B4", borderSubtle: "#E4D6C6"
            };
        } else if (h === "#7D5260") {
            return dark ? {
                primary: "#EFBDC8", colorOnPrimary: "#492532", primaryContainer: "#633B48", colorOnPrimaryContainer: "#FFD8E4",
                secondary: "#D2C1C6", colorOnSecondary: "#382D31", secondaryContainer: "#4F4347", colorOnSecondaryContainer: "#EEDDE2",
                tertiary: "#E5BD9B", colorOnTertiary: "#432A11", tertiaryContainer: "#5B3F25", colorOnTertiaryContainer: "#FFDCBE",
                surface: "#161214", colorOnSurface: "#E9E0E2", surfaceVariant: "#4F4347", colorOnSurfaceVariant: "#D3C2C6",
                surfaceContainerLowest: "#110D0F", surfaceContainerLow: "#1F1A1C", surfaceContainer: "#231E20", surfaceContainerHigh: "#2E282B", surfaceContainerHighest: "#393335",
                outline: "#9C8D91", outlineVariant: "#4F4347", borderSubtle: "#30282C"
            } : {
                primary: "#7D5260", colorOnPrimary: "#FFFFFF", primaryContainer: "#FFD8E4", colorOnPrimaryContainer: "#31111D",
                secondary: "#67595E", colorOnSecondary: "#FFFFFF", secondaryContainer: "#EEDDE2", colorOnSecondaryContainer: "#22171B",
                tertiary: "#76573B", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#FFDCBE", colorOnTertiaryContainer: "#2B1602",
                surface: "#FFF8F8", colorOnSurface: "#1F1A1B", surfaceVariant: "#F0DEE3", colorOnSurfaceVariant: "#4F4347",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#FAF1F3", surfaceContainer: "#F4EBED", surfaceContainerHigh: "#EEE5E7", surfaceContainerHighest: "#E8DFE1",
                outline: "#817377", outlineVariant: "#D3C2C6", borderSubtle: "#E3D5D9"
            };
        } else if (h === "#006874") {
            return dark ? {
                primary: "#4FD8EB", colorOnPrimary: "#00363D", primaryContainer: "#004F58", colorOnPrimaryContainer: "#97F0FF",
                secondary: "#B1CBD0", colorOnSecondary: "#1C3438", secondaryContainer: "#334B4F", colorOnSecondaryContainer: "#CDE7EC",
                tertiary: "#BAC6EA", colorOnTertiary: "#24304D", tertiaryContainer: "#3B4664", colorOnTertiaryContainer: "#DAE2FF",
                surface: "#0E1516", colorOnSurface: "#DEE4E5", surfaceVariant: "#3F484A", colorOnSurfaceVariant: "#BFC8CA",
                surfaceContainerLowest: "#090F10", surfaceContainerLow: "#161D1E", surfaceContainer: "#1A2122", surfaceContainerHigh: "#252B2D", surfaceContainerHighest: "#303637",
                outline: "#899294", outlineVariant: "#3F484A", borderSubtle: "#232A2C"
            } : {
                primary: "#006874", colorOnPrimary: "#FFFFFF", primaryContainer: "#97F0FF", colorOnPrimaryContainer: "#001F24",
                secondary: "#4A6267", colorOnSecondary: "#FFFFFF", secondaryContainer: "#CDE7EC", colorOnSecondaryContainer: "#051F23",
                tertiary: "#525E7D", colorOnTertiary: "#FFFFFF", tertiaryContainer: "#DAE2FF", colorOnTertiaryContainer: "#0E1A37",
                surface: "#F4FBFC", colorOnSurface: "#161D1E", surfaceVariant: "#DBE4E6", colorOnSurfaceVariant: "#3F484A",
                surfaceContainerLowest: "#FFFFFF", surfaceContainerLow: "#EFF5F6", surfaceContainer: "#E9EFF0", surfaceContainerHigh: "#E3E9EB", surfaceContainerHighest: "#DEE4E5",
                outline: "#70797A", outlineVariant: "#BFC8CA", borderSubtle: "#DFE5E7"
            };
        }
        return null;
    }

    function generatePalette(hex, dark) {
        var preset = getPresetTokens(hex, dark);
        if (preset) return preset;

        // Custom color algorithmic M3 generation
        var hsl = hexToHsl(hex || "#39C5BB");
        var h = hsl.h;
        var s = hsl.s;

        if (dark) {
            return {
                primary: hslToHex(h, Math.min(s, 85), 76),
                colorOnPrimary: hslToHex(h, Math.min(s, 90), 16),
                primaryContainer: hslToHex(h, Math.min(s, 75), 28),
                colorOnPrimaryContainer: hslToHex(h, Math.min(s, 90), 88),
                secondary: hslToHex(h, 25, 75),
                colorOnSecondary: hslToHex(h, 25, 18),
                secondaryContainer: hslToHex(h, 25, 30),
                colorOnSecondaryContainer: hslToHex(h, 25, 88),
                tertiary: hslToHex((h + 60) % 360, 35, 78),
                colorOnTertiary: hslToHex((h + 60) % 360, 35, 18),
                tertiaryContainer: hslToHex((h + 60) % 360, 35, 30),
                colorOnTertiaryContainer: hslToHex((h + 60) % 360, 35, 90),
                surface: hslToHex(h, 12, 7),
                colorOnSurface: hslToHex(h, 12, 90),
                surfaceVariant: hslToHex(h, 12, 28),
                colorOnSurfaceVariant: hslToHex(h, 12, 78),
                surfaceContainerLowest: hslToHex(h, 12, 5),
                surfaceContainerLow: hslToHex(h, 12, 10),
                surfaceContainer: hslToHex(h, 12, 12),
                surfaceContainerHigh: hslToHex(h, 12, 16),
                surfaceContainerHighest: hslToHex(h, 12, 21),
                outline: hslToHex(h, 10, 56),
                outlineVariant: hslToHex(h, 10, 28),
                borderSubtle: hslToHex(h, 10, 15)
            };
        } else {
            return {
                primary: hslToHex(h, Math.min(s, 90), 38),
                colorOnPrimary: "#FFFFFF",
                primaryContainer: hslToHex(h, Math.min(s, 90), 85),
                colorOnPrimaryContainer: hslToHex(h, Math.min(s, 90), 12),
                secondary: hslToHex(h, 20, 38),
                colorOnSecondary: "#FFFFFF",
                secondaryContainer: hslToHex(h, 25, 88),
                colorOnSecondaryContainer: hslToHex(h, 25, 12),
                tertiary: hslToHex((h + 60) % 360, 30, 40),
                colorOnTertiary: "#FFFFFF",
                tertiaryContainer: hslToHex((h + 60) % 360, 35, 88),
                colorOnTertiaryContainer: hslToHex((h + 60) % 360, 35, 12),
                surface: hslToHex(h, 15, 98),
                colorOnSurface: hslToHex(h, 12, 10),
                surfaceVariant: hslToHex(h, 12, 88),
                colorOnSurfaceVariant: hslToHex(h, 12, 28),
                surfaceContainerLowest: "#FFFFFF",
                surfaceContainerLow: hslToHex(h, 12, 96),
                surfaceContainer: hslToHex(h, 12, 94),
                surfaceContainerHigh: hslToHex(h, 12, 92),
                surfaceContainerHighest: hslToHex(h, 12, 89),
                outline: hslToHex(h, 10, 48),
                outlineVariant: hslToHex(h, 10, 78),
                borderSubtle: hslToHex(h, 10, 88)
            };
        }
    }

    // ========================================================================
    // Reactive Dynamic Material 3 System Color Properties
    // ========================================================================
    property color primary: "#39C5BB"
    property color colorOnPrimary: "#003738"
    property color primaryContainer: "#004F50"
    property color colorOnPrimaryContainer: "#70F7EC"

    property color secondary: "#B0CCCB"
    property color colorOnSecondary: "#1B3534"
    property color secondaryContainer: "#324B4B"
    property color colorOnSecondaryContainer: "#CCE8E7"

    property color tertiary: "#B3C8E8"
    property color colorOnTertiary: "#1C314B"
    property color tertiaryContainer: "#334863"
    property color colorOnTertiaryContainer: "#D3E4FF"

    // Material 3 Standard Naming Aliases
    readonly property alias onPrimary: theme.colorOnPrimary
    readonly property alias onSecondary: theme.colorOnSecondary
    readonly property alias onTertiary: theme.colorOnTertiary
    readonly property alias onSurface: theme.colorOnSurface
    readonly property alias onSurfaceVariant: theme.colorOnSurfaceVariant
    readonly property alias onPrimaryContainer: theme.colorOnPrimaryContainer
    readonly property alias onSecondaryContainer: theme.colorOnSecondaryContainer
    readonly property alias onTertiaryContainer: theme.colorOnTertiaryContainer

    property color surface: "#0E1514"
    property color colorOnSurface: "#DEE4E3"
    property color surfaceVariant: "#3F4948"
    property color colorOnSurfaceVariant: "#BEC9C8"
    property color surfaceDim: "#0E1514"
    property color surfaceBright: "#343A3A"

    property color surfaceContainerLowest: "#090F0F"
    property color surfaceContainerLow: "#161D1D"
    property color surfaceContainer: "#1A2121"
    property color surfaceContainerHigh: "#252B2B"
    property color surfaceContainerHighest: "#303636"

    property color outline: "#889392"
    property color outlineVariant: "#3F4948"
    property color borderSubtle: "#222524"

    property color textPrimary: "#FFFFFF"
    property color textSecondary: "#DEE4E3"
    property color textMuted: "#8E918F"
    property color iconNeutral: "#C4C7C5"

    function updatePalette() {
        var sColor = (typeof ConfigManager !== "undefined" && ConfigManager && ConfigManager.seedColor) ? ConfigManager.seedColor : theme.seedColor;
        var tMode = (typeof ConfigManager !== "undefined" && ConfigManager && ConfigManager.themeMode) ? ConfigManager.themeMode : theme.themeMode;
        var dark = tMode === "light" ? false : true;

        var tokens = generatePalette(sColor, dark);
        if (!tokens) return;

        primary = tokens.primary;
        colorOnPrimary = tokens.colorOnPrimary;
        primaryContainer = tokens.primaryContainer;
        colorOnPrimaryContainer = tokens.colorOnPrimaryContainer;

        secondary = tokens.secondary;
        colorOnSecondary = tokens.colorOnSecondary;
        secondaryContainer = tokens.secondaryContainer;
        colorOnSecondaryContainer = tokens.colorOnSecondaryContainer;

        tertiary = tokens.tertiary;
        colorOnTertiary = tokens.colorOnTertiary;
        tertiaryContainer = tokens.tertiaryContainer;
        colorOnTertiaryContainer = tokens.colorOnTertiaryContainer;

        surface = tokens.surface;
        colorOnSurface = tokens.colorOnSurface;
        surfaceVariant = tokens.surfaceVariant;
        colorOnSurfaceVariant = tokens.colorOnSurfaceVariant;
        surfaceDim = tokens.surface;
        surfaceBright = dark ? (tokens.surfaceContainerHighest || "#343A3A") : (tokens.surfaceContainerLowest || "#FFFFFF");

        surfaceContainerLowest = tokens.surfaceContainerLowest;
        surfaceContainerLow = tokens.surfaceContainerLow;
        surfaceContainer = tokens.surfaceContainer;
        surfaceContainerHigh = tokens.surfaceContainerHigh;
        surfaceContainerHighest = tokens.surfaceContainerHighest;

        outline = tokens.outline;
        outlineVariant = tokens.outlineVariant;
        borderSubtle = tokens.borderSubtle;

        textPrimary = dark ? "#FFFFFF" : tokens.colorOnSurface;
        textSecondary = tokens.colorOnSurfaceVariant;
        textMuted = tokens.outline;
        iconNeutral = tokens.outline;
    }

    property var _connections: Connections {
        target: ConfigManager
        function onSeedColorChanged() {
            theme.updatePalette();
        }
        function onThemeModeChanged() {
            theme.updatePalette();
        }
    }

    onSeedColorChanged: updatePalette()
    onIsDarkChanged: updatePalette()
    Component.onCompleted: updatePalette()
}
