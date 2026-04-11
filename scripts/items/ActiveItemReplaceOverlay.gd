extends CanvasLayer

signal replacement_confirmed(old_item: ItemData, new_item: ItemData)
signal replacement_cancelled(new_item: ItemData)

signal request_tooltip_show(item)
signal request_tooltip_hide

const SLOT_SCENE = preload("res://scenes/ActiveItemSlot.tscn")

var new_item: ItemData = null
var selected_slot: Node = null
var selected_item: ItemData = null
var slots: Array = []

@onready var slot_container = $Background/VBoxContainer/SlotContainer
@onready var new_item_slot = $Background/VBoxContainer/NewItemContainer/NewItemSlot
@onready var confirm_button = $Background/VBoxContainer/ButtonRow/ConfirmButton
@onready var cancel_button = $Background/VBoxContainer/ButtonRow/CancelButton
@onready var title_label = $Background/VBoxContainer/TitleLabel

var font: Font


func _ready():
	font = preload("res://assets/gomarice_goma_block.ttf")
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_style_labels()


func _style_labels():
	title_label.text = "CHOOSE ITEM TO REPLACE"
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var confirm_label = confirm_button.get_node_or_null("Label")
	if confirm_label:
		confirm_label.add_theme_font_override("font", font)
		confirm_label.add_theme_font_size_override("font_size", 20)

	var cancel_label = cancel_button.get_node_or_null("Label")
	if cancel_label:
		cancel_label.add_theme_font_override("font", font)
		cancel_label.add_theme_font_size_override("font_size", 20)


func show_overlay(p_new_item: ItemData):
	new_item = p_new_item
	visible = true
	selected_slot = null
	selected_item = null
	confirm_button.disabled = true

	_build_current_slots()
	_setup_new_item_slot()


func _build_current_slots():
	for child in slot_container.get_children():
		child.queue_free()
	slots.clear()

	var active_items = ItemManager.player_items.filter(func(i): return i.is_active)

	for item in active_items:
		var slot = SLOT_SCENE.instantiate()
		slot_container.add_child(slot)
		slot.setup(item)
		slots.append(slot)

		slot.connect("slot_clicked", _on_slot_clicked.bind(slot))
		slot.connect("mouse_entered", _on_slot_mouse_entered.bind(slot))
		slot.connect("mouse_exited", _on_slot_mouse_exited)


func _setup_new_item_slot():
	# Clear existing
	for child in new_item_slot.get_children():
		child.queue_free()

	var slot = SLOT_SCENE.instantiate()
	new_item_slot.add_child(slot)
	slot.setup(new_item)
	# New item slot is not clickable — just for display
	slot.set_process_input(false)


func _on_slot_clicked(item: ItemData, slot: Node):
	if selected_slot:
		selected_slot.set_selected(false)
	selected_slot = slot
	selected_item = item
	slot.set_selected(true)
	confirm_button.disabled = false



func _on_confirm_pressed():
	if not selected_slot or not selected_item:
		return

	confirm_button.disabled = true
	cancel_button.disabled = true

	await selected_slot.play_blink_animation(new_item)

	emit_signal("replacement_confirmed", selected_item, new_item)
	queue_free()


func _on_cancel_pressed():
	emit_signal("replacement_cancelled", new_item)
	queue_free()


func _on_slot_mouse_entered(slot):
	if slot.item == null:
		return
	emit_signal("request_tooltip_show", slot.item)

func _on_slot_mouse_exited():
	emit_signal("request_tooltip_hide")