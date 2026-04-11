extends PanelContainer

# ActiveItemPanel.gd
# Add ActiveItemPanel.tscn to any scene that needs active items
# It self-populates from ItemManager.player_items

const SLOT_SCENE = preload("res://scenes/ActiveItemSlot.tscn")
const MAX_SLOTS = 5

var slots: Array = []
var can_click := true

var _previous_active_count := 0

@onready var slot_container = $VBoxContainer/SlotContainer

signal request_tooltip_show(item)
signal request_tooltip_hide

func _ready():
	_build_slots()
	ItemManager.connect("items_changed", _rebuild_slots)
	ActiveItemManager.connect("active_items_changed", _rebuild_slots)


func _build_slots():
	for child in slot_container.get_children():
		child.queue_free()
	slots.clear()

	var active_items = ItemManager.player_items.filter(func(i): return i.is_active)

	for i in range(MAX_SLOTS):
		var slot = SLOT_SCENE.instantiate()
		slot_container.add_child(slot)
		slots.append(slot)

		if i < active_items.size():
			slot.setup(active_items[i])
		else:
			slot.set_empty()

		slot.connect("slot_clicked", _on_slot_clicked)
		slot.connect("mouse_entered", _on_slot_hovered.bind(slot))
		slot.connect("mouse_exited", _on_slot_unhovered)

	var new_count = active_items.size()
	if new_count > _previous_active_count and new_count > 0:
		var newest_index = new_count - 1
		await get_tree().process_frame
		if newest_index < slots.size() and is_instance_valid(slots[newest_index]):
			await slots[newest_index].play_blink_animation(active_items[newest_index])

	_previous_active_count = new_count



func _rebuild_slots():
	_build_slots()


func _on_slot_clicked(item: ItemData):
	if can_click:
		if ActiveItemManager.try_activate(item) :
			AudioLoader.play_sound("select")


func _on_slot_hovered(slot):
	if slot.is_empty or not slot.item:
		return
	emit_signal("request_tooltip_show", slot.item)

func _on_slot_unhovered():
	emit_signal("request_tooltip_hide")