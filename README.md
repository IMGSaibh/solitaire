# Solitaire Klondike
```bash
res://
│
├── assets/
│   ├── cards/
│   │   ├── faces/
│   │   └── backs/
│   ├── backgrounds/
│   ├── ui/
│   ├── sounds/
│   └── fonts/
│
├── scenes/
│   ├── main/
│   │   └── game.tscn
│   │
│   ├── cards/
│   │   └── card_view.tscn
│   │
│   └── ui/
│       ├── top_bar.tscn
│       ├── win_overlay.tscn
│       └── settings.tscn
│
├── scripts/
│   ├── model/
│   │   ├── card.gd
│   │   ├── pile.gd
│   │   └── game_state.gd
│   │
│   ├── rules/
│   │   └── klondike_rules.gd
│   │
│   ├── controllers/
│   │   └── game_controller.gd
│   │
│   └── views/
│       ├── card_view.gd
│       ├── pile_view.gd
│       └── board_view.gd
│
└── data/
    └── card_theme.tres
```

# Settings json
```json
{
    "godotTools.editorPath.godot4": "c:\\Program Files (x86)\\Godot_v4.6.3-stable_win64.exe\\Godot_v4.6.3-stable_win64.exe",
    "[gdscript]": {
		"editor.defaultFormatter": "DoHe.godot-format",
		"editor.formatOnSave": true,
		"editor.insertSpaces": false,
		"editor.detectIndentation": false,
		"editor.tabSize": 4
	},

	"godotFormatter.enable": true,
	"godotFormatter.enableLinter": true,

	"godotFormatter.useSpaces": false,
	"godotFormatter.indentSize": 4,

	"godotFormatter.maxLineLength": 100,
	"godotFormatter.linterMaxLineLength": 100,

	"godotFormatter.verifyStructure": true,
	"godotFormatter.reorderCode": false,

	"godotFormatter.quoteStyle": "double"
}
```
