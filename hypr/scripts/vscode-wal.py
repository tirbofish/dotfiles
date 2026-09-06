#!/usr/bin/env python3
"""Write VS Code workbench colors from the current pywal palette."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def mix(a: str, b: str, t: float) -> str:
    ar, ag, ab = hex_to_rgb(a)
    br, bg, bb = hex_to_rgb(b)
    return rgb_to_hex(
        (
            round(ar + (br - ar) * t),
            round(ag + (bg - ag) * t),
            round(ab + (bb - ab) * t),
        )
    )


def alpha(color: str, amount: float) -> str:
    return f"{color}{round(amount * 255):02x}"


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    colors_path = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / ".cache/wal/colors.json")
    mode = sys.argv[2] if len(sys.argv) > 2 else "dark"
    settings_path = Path.home() / ".config/Code/User/settings.json"

    palette = load_json(colors_path)
    special = palette.get("special", {})
    colors = palette.get("colors", {})

    bg = special.get("background")
    fg = special.get("foreground")
    if not bg or not fg:
        return 1

    c = [colors.get(f"color{i}", fg) for i in range(16)]
    accent = c[4]
    secondary = c[6]
    danger = c[1]
    muted = c[8]
    dark = mode != "light"
    base_theme = "Default Dark Modern" if dark else "Default Light Modern"
    overlay = fg if dark else bg
    surface = mix(bg, overlay, 0.06)
    surface2 = mix(bg, overlay, 0.11)
    surface3 = mix(bg, overlay, 0.18)
    dim = mix(fg, bg, 0.35)

    settings = load_json(settings_path)
    settings["workbench.colorTheme"] = base_theme
    settings["workbench.preferredDarkColorTheme"] = "Default Dark Modern"
    settings["workbench.preferredLightColorTheme"] = "Default Light Modern"
    settings["window.autoDetectColorScheme"] = False
    settings["workbench.colorCustomizations"] = {
        "foreground": fg,
        "disabledForeground": muted,
        "descriptionForeground": muted,
        "errorForeground": danger,
        "focusBorder": accent,
        "icon.foreground": fg,
        "selection.background": alpha(accent, 0.45),
        "widget.border": surface3,
        "widget.shadow": alpha(bg, 0.55),
        "textLink.foreground": accent,
        "textLink.activeForeground": secondary,
        "textBlockQuote.background": surface,
        "textBlockQuote.border": accent,
        "textPreformat.foreground": secondary,
        "textSeparator.foreground": surface3,
        "button.background": accent,
        "button.foreground": bg,
        "button.hoverBackground": secondary,
        "button.secondaryBackground": surface2,
        "button.secondaryForeground": fg,
        "button.secondaryHoverBackground": surface3,
        "checkbox.background": surface,
        "checkbox.foreground": accent,
        "checkbox.border": muted,
        "dropdown.background": surface,
        "dropdown.foreground": fg,
        "dropdown.border": surface3,
        "input.background": surface,
        "input.foreground": fg,
        "input.border": surface3,
        "input.placeholderForeground": muted,
        "inputOption.activeBackground": alpha(accent, 0.28),
        "inputOption.activeBorder": accent,
        "inputOption.activeForeground": fg,
        "inputValidation.errorBackground": mix(bg, danger, 0.25),
        "inputValidation.errorBorder": danger,
        "inputValidation.errorForeground": fg,
        "inputValidation.infoBackground": mix(bg, accent, 0.25),
        "inputValidation.infoBorder": accent,
        "inputValidation.warningBackground": mix(bg, secondary, 0.25),
        "inputValidation.warningBorder": secondary,
        "badge.background": accent,
        "badge.foreground": bg,
        "progressBar.background": accent,
        "list.activeSelectionBackground": alpha(accent, 0.32),
        "list.activeSelectionForeground": fg,
        "list.inactiveSelectionBackground": alpha(accent, 0.18),
        "list.inactiveSelectionForeground": fg,
        "list.hoverBackground": alpha(overlay, 0.08),
        "list.focusBackground": alpha(accent, 0.24),
        "list.focusForeground": fg,
        "list.highlightForeground": accent,
        "list.warningForeground": secondary,
        "list.errorForeground": danger,
        "tree.indentGuidesStroke": surface3,
        "activityBar.background": bg,
        "activityBar.foreground": fg,
        "activityBar.inactiveForeground": muted,
        "activityBar.border": surface,
        "activityBar.activeBorder": accent,
        "activityBarBadge.background": accent,
        "activityBarBadge.foreground": bg,
        "sideBar.background": bg,
        "sideBar.foreground": fg,
        "sideBar.border": surface,
        "sideBarTitle.foreground": fg,
        "sideBarSectionHeader.background": surface,
        "sideBarSectionHeader.foreground": fg,
        "sideBarSectionHeader.border": surface,
        "titleBar.activeBackground": bg,
        "titleBar.activeForeground": fg,
        "titleBar.inactiveBackground": bg,
        "titleBar.inactiveForeground": muted,
        "titleBar.border": surface,
        "menubar.selectionBackground": surface2,
        "menubar.selectionForeground": fg,
        "menu.background": surface,
        "menu.foreground": fg,
        "menu.selectionBackground": alpha(accent, 0.32),
        "menu.selectionForeground": fg,
        "menu.separatorBackground": surface3,
        "menu.border": surface3,
        "statusBar.background": bg,
        "statusBar.foreground": fg,
        "statusBar.border": surface,
        "statusBar.debuggingBackground": danger,
        "statusBar.debuggingForeground": bg,
        "statusBar.noFolderBackground": surface2,
        "statusBar.noFolderForeground": fg,
        "statusBarItem.hoverBackground": alpha(overlay, 0.10),
        "statusBarItem.prominentBackground": surface2,
        "statusBarItem.prominentForeground": fg,
        "statusBarItem.remoteBackground": accent,
        "statusBarItem.remoteForeground": bg,
        "editorGroupHeader.tabsBackground": bg,
        "editorGroupHeader.tabsBorder": surface,
        "editorGroup.border": surface,
        "tab.activeBackground": surface,
        "tab.activeForeground": fg,
        "tab.activeBorderTop": accent,
        "tab.inactiveBackground": bg,
        "tab.inactiveForeground": muted,
        "tab.border": bg,
        "tab.hoverBackground": surface2,
        "tab.unfocusedActiveBackground": surface,
        "tab.unfocusedActiveForeground": dim,
        "tab.unfocusedInactiveForeground": muted,
        "editor.background": bg,
        "editor.foreground": fg,
        "editorLineNumber.foreground": muted,
        "editorLineNumber.activeForeground": fg,
        "editorCursor.foreground": accent,
        "editorCursor.background": bg,
        "editor.selectionBackground": alpha(accent, 0.38),
        "editor.inactiveSelectionBackground": alpha(accent, 0.18),
        "editor.selectionHighlightBackground": alpha(secondary, 0.22),
        "editor.wordHighlightBackground": alpha(accent, 0.18),
        "editor.wordHighlightStrongBackground": alpha(secondary, 0.22),
        "editor.lineHighlightBackground": alpha(overlay, 0.06),
        "editor.lineHighlightBorder": "#00000000",
        "editor.rangeHighlightBackground": alpha(secondary, 0.12),
        "editor.findMatchBackground": alpha(secondary, 0.45),
        "editor.findMatchHighlightBackground": alpha(accent, 0.28),
        "editor.findRangeHighlightBackground": alpha(accent, 0.12),
        "editor.hoverHighlightBackground": alpha(accent, 0.16),
        "editorLink.activeForeground": accent,
        "editorWhitespace.foreground": alpha(muted, 0.45),
        "editorIndentGuide.background1": surface2,
        "editorIndentGuide.activeBackground1": muted,
        "editorRuler.foreground": surface2,
        "editorBracketMatch.background": alpha(accent, 0.22),
        "editorBracketMatch.border": accent,
        "editorOverviewRuler.border": surface,
        "editorOverviewRuler.findMatchForeground": secondary,
        "editorOverviewRuler.modifiedForeground": accent,
        "editorOverviewRuler.addedForeground": secondary,
        "editorOverviewRuler.deletedForeground": danger,
        "editorOverviewRuler.errorForeground": danger,
        "editorOverviewRuler.warningForeground": secondary,
        "editorGutter.background": bg,
        "editorGutter.modifiedBackground": accent,
        "editorGutter.addedBackground": secondary,
        "editorGutter.deletedBackground": danger,
        "editorWidget.background": surface,
        "editorWidget.foreground": fg,
        "editorWidget.border": surface3,
        "editorSuggestWidget.background": surface,
        "editorSuggestWidget.border": surface3,
        "editorSuggestWidget.foreground": fg,
        "editorSuggestWidget.highlightForeground": accent,
        "editorSuggestWidget.selectedBackground": alpha(accent, 0.28),
        "editorHoverWidget.background": surface,
        "editorHoverWidget.border": surface3,
        "editorHoverWidget.foreground": fg,
        "peekView.border": accent,
        "peekViewEditor.background": mix(bg, overlay, 0.04),
        "peekViewEditor.matchHighlightBackground": alpha(secondary, 0.28),
        "peekViewResult.background": surface,
        "peekViewResult.fileForeground": fg,
        "peekViewResult.lineForeground": dim,
        "peekViewResult.matchHighlightBackground": alpha(accent, 0.28),
        "peekViewResult.selectionBackground": alpha(accent, 0.32),
        "peekViewTitle.background": surface2,
        "peekViewTitleLabel.foreground": fg,
        "peekViewTitleDescription.foreground": muted,
        "panel.background": bg,
        "panel.border": surface,
        "panelTitle.activeForeground": fg,
        "panelTitle.activeBorder": accent,
        "panelTitle.inactiveForeground": muted,
        "terminal.background": bg,
        "terminal.foreground": fg,
        "terminal.ansiBlack": c[0],
        "terminal.ansiRed": c[1],
        "terminal.ansiGreen": c[2],
        "terminal.ansiYellow": c[3],
        "terminal.ansiBlue": c[4],
        "terminal.ansiMagenta": c[5],
        "terminal.ansiCyan": c[6],
        "terminal.ansiWhite": c[7],
        "terminal.ansiBrightBlack": c[8],
        "terminal.ansiBrightRed": c[9],
        "terminal.ansiBrightGreen": c[10],
        "terminal.ansiBrightYellow": c[11],
        "terminal.ansiBrightBlue": c[12],
        "terminal.ansiBrightMagenta": c[13],
        "terminal.ansiBrightCyan": c[14],
        "terminal.ansiBrightWhite": c[15],
        "terminalCursor.foreground": accent,
        "terminal.selectionBackground": alpha(accent, 0.38),
        "breadcrumb.background": bg,
        "breadcrumb.foreground": muted,
        "breadcrumb.focusForeground": fg,
        "breadcrumb.activeSelectionForeground": accent,
        "minimap.background": bg,
        "minimap.selectionHighlight": alpha(accent, 0.45),
        "minimap.findMatchHighlight": alpha(secondary, 0.45),
        "minimapGutter.addedBackground": secondary,
        "minimapGutter.modifiedBackground": accent,
        "minimapGutter.deletedBackground": danger,
        "scrollbar.shadow": alpha(bg, 0.40),
        "scrollbarSlider.background": alpha(muted, 0.28),
        "scrollbarSlider.hoverBackground": alpha(muted, 0.42),
        "scrollbarSlider.activeBackground": alpha(accent, 0.55),
        "notifications.background": surface,
        "notifications.foreground": fg,
        "notifications.border": surface3,
        "notificationCenterHeader.background": surface2,
        "notificationCenterHeader.foreground": fg,
        "notificationLink.foreground": accent,
        "notificationsErrorIcon.foreground": danger,
        "notificationsWarningIcon.foreground": secondary,
        "notificationsInfoIcon.foreground": accent,
        "gitDecoration.addedResourceForeground": secondary,
        "gitDecoration.modifiedResourceForeground": accent,
        "gitDecoration.deletedResourceForeground": danger,
        "gitDecoration.untrackedResourceForeground": c[5],
        "gitDecoration.ignoredResourceForeground": muted,
        "gitDecoration.conflictingResourceForeground": c[3],
        "diffEditor.insertedTextBackground": alpha(secondary, 0.18),
        "diffEditor.removedTextBackground": alpha(danger, 0.18),
        "commandCenter.background": surface,
        "commandCenter.foreground": fg,
        "commandCenter.border": surface3,
        "commandCenter.activeBackground": surface2,
        "quickInput.background": surface,
        "quickInput.foreground": fg,
        "quickInputTitle.background": surface2,
        "pickerGroup.foreground": accent,
        "pickerGroup.border": surface3,
        "keybindingLabel.background": surface2,
        "keybindingLabel.foreground": fg,
        "keybindingLabel.border": surface3,
        "debugToolBar.background": surface,
        "debugToolBar.border": surface3,
        "settings.headerForeground": fg,
        "settings.modifiedItemIndicator": accent,
        "settings.focusedRowBackground": alpha(accent, 0.10),
        "walkThrough.embeddedEditorBackground": surface,
        "welcomePage.tileBackground": surface,
        "welcomePage.progress.background": surface2,
        "welcomePage.progress.foreground": accent,
    }
    settings["editor.tokenColorCustomizations"] = {
        "comments": muted,
        "strings": secondary,
        "keywords": accent,
        "functions": c[5],
        "numbers": c[3],
        "types": c[2],
        "variables": fg,
        "textMateRules": [
            {"scope": ["comment", "punctuation.definition.comment"], "settings": {"foreground": muted, "fontStyle": "italic"}},
            {"scope": ["string", "punctuation.definition.string"], "settings": {"foreground": secondary}},
            {"scope": ["constant.numeric", "constant.other.color"], "settings": {"foreground": c[3]}},
            {"scope": ["constant.language", "constant.character.escape"], "settings": {"foreground": danger}},
            {"scope": ["keyword", "storage", "storage.type", "storage.modifier"], "settings": {"foreground": accent}},
            {"scope": ["entity.name.function", "support.function", "meta.function-call"], "settings": {"foreground": c[5]}},
            {"scope": ["entity.name.class", "entity.name.type", "support.type", "support.class"], "settings": {"foreground": c[2]}},
            {"scope": ["variable", "support.variable", "meta.definition.variable"], "settings": {"foreground": fg}},
            {"scope": ["entity.name.tag", "punctuation.definition.tag"], "settings": {"foreground": accent}},
            {"scope": ["entity.other.attribute-name"], "settings": {"foreground": c[5]}},
            {"scope": ["markup.heading"], "settings": {"foreground": accent, "fontStyle": "bold"}},
            {"scope": ["markup.underline.link"], "settings": {"foreground": secondary}},
            {"scope": ["invalid", "invalid.illegal"], "settings": {"foreground": danger}},
        ],
    }
    settings["editor.semanticTokenColorCustomizations"] = {
        "enabled": True,
        "rules": {
            "comment": muted,
            "string": secondary,
            "keyword": accent,
            "function": c[5],
            "method": c[5],
            "variable": fg,
            "parameter": dim,
            "property": fg,
            "type": c[2],
            "class": c[2],
            "namespace": c[2],
            "number": c[3],
            "enumMember": secondary,
            "macro": c[5],
            "operator": dim,
        },
    }

    settings_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = settings_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(settings, indent=4) + "\n", encoding="utf-8")
    tmp.replace(settings_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
