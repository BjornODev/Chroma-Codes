extends CanvasLayer

# CautionOverlay — full screen flashing CAUTION warning before boss
# Scene structure:
# CanvasLayer
# └── Control (full screen)
#     ├── ColorRect "BG" (dark red semi-transparent background)
#     ├── TextureRect "HazardStripes" (optional red/black stripes)
#     └── Label "CautionLabel" (the CAUTION text)

const FLASH_DURATION := 10.0
const FLASH_INTERVAL := 0.18

signal finished

@onready var caution_label = $Control/CautionLabel
@onready var bg = $Control/BG


func _ready():
	visible = false
	if caution_label:
		caution_label.text = "⚠ CAUTION ⚠"
		_apply_label_style()


func _apply_label_style():
	caution_label.add_theme_font_override("font", preload("res://assets/gomarice_goma_block.ttf"))
	caution_label.add_theme_font_size_override("font_size", 200)
	caution_label.add_theme_color_override("font_color", Color("#FF1111"))
	caution_label.add_theme_color_override("font_outline_color", Color("#000000"))
	caution_label.add_theme_constant_override("outline_size", 20)
	caution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caution_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caution_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_caution() -> void:
	visible = true
	bg.color = Color(0.1, 0.0, 0.0, 0.92)

	var elapsed := 0.0

	while elapsed < FLASH_DURATION:
		caution_label.visible = true
		await get_tree().create_timer(FLASH_INTERVAL).timeout
		caution_label.visible = false
		await get_tree().create_timer(FLASH_INTERVAL).timeout
		elapsed += FLASH_INTERVAL * 2.0

	caution_label.visible = true
	visible = false
	emit_signal("finished")


# Call this and await it from MapScreen
func finish() -> void:
	await show_caution()
