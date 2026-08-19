import QtQuick

QtObject {
    id: root

    // Follows the shared state by default; assign to pin an instance to one mode
    property bool isDarkMode: ThemeState.isDarkMode
    function toggle() { ThemeState.toggle() }

    // Surfaces
    readonly property color bgMain: Configuration.useCustomColors
        ? Configuration.customBg
        : (isDarkMode ? "#141719" : "#F0ECE6")
    readonly property color bgCard: Configuration.useCustomColors
        ? Qt.lighter(Configuration.customBg, 1.35) : (isDarkMode ? "#1e2326" : "#E3DED6")
    readonly property color bgItem: Configuration.useCustomColors
        ? Qt.lighter(Configuration.customBg, 1.8) : (isDarkMode ? "#2d353b" : Qt.rgba(0, 0, 0, 0.05))
    readonly property color bgItemHover: Configuration.useCustomColors
        ? Qt.lighter(Configuration.customBg, 2.2) : (isDarkMode ? "#374145" : Qt.rgba(0, 0, 0, 0.08))
    readonly property color bgWidget: bgCard

    // Text
    readonly property color textPrimary: Configuration.useCustomColors
        ? Configuration.customForeground : (isDarkMode ? "#dde5dfc5" : "#252E33")
    readonly property color textSecondary: Configuration.useCustomColors
        ? Configuration.customSecondary : (isDarkMode ? "#9da9a0" : "#546670")
    readonly property color textOnAccent: Configuration.useCustomColors
        ? Configuration.customBg : (isDarkMode ? "#232a2e" : "#F0ECE6")

    // Accents
    readonly property color accent: Configuration.useCustomColors
        ? Configuration.customAccent
        : "#7AA1A6"
    readonly property color accentBlue: Configuration.useCustomColors
        ? Configuration.customAccent
        : "#7AA1A6"
    readonly property color accentRed: Configuration.useCustomColors
        ? Configuration.customDanger : (isDarkMode ? "#e67e80" : "#c74042")
    readonly property color accentSlider: Configuration.useCustomColors
        ? Configuration.customAccent : accent
    readonly property color accentSlider2: Configuration.useCustomColors
        ? Configuration.customSecondary : (isDarkMode ? "#f1af97" : "#d39984")

    // Lines and hovers
    readonly property color border: Qt.rgba(accent.r, accent.g, accent.b, 0.44)
    readonly property color outline:         isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color subtleFill:      isDarkMode ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.05)
    readonly property color subtleFillHover: isDarkMode ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.10)
    readonly property color hoverSpotlight:  isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.10)

    // Sizing
    readonly property int radiusOuter: 12
    readonly property int radiusInner: 16
    readonly property int padCard:     12
    readonly property int gapCard:     10
    readonly property int btnH:        54
    readonly property int sliderH:     24

    // Used by the top-style calendar card
    readonly property color weatherColor: Configuration.useCustomColors
        ? Configuration.customSecondary : (isDarkMode ? "#9da9a0" : "#3c4841")

    readonly property string textFont: "Manrope"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
}
