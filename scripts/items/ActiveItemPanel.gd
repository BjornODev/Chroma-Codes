extends PanelContainer

# ActiveItemPanel.gd
# Add ActiveItemPanel.tscn to any scene that needs active items
# It self-populates from ItemManager.player_items

const SLOT_SCENE = preload("res://scenes/ActiveItemSlot.tscn")
const MAX_SLOTS = 5

var slots: Array = []

@onready var slot_container = $VBoxContainer/SlotContainer
@onready var tooltip = get_node_or_null("/root/Main/HUDLayer/Tooltip")


func _ready():
	_build_slots()
	ItemManager.connect("items_changed", _rebuild_slots)
	ActiveItemManager.connect("active_items_changed", _rebuild_slots)


func _build_slots():
	for child in slot_container.get_children():
		child.queue_free()
	slots.clear()

	# Get active items
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


func _rebuild_slots():
	_build_slots()


func _on_slot_clicked(item: ItemData):
	if ActiveItemManager.try_activate(item):
		AudioLoader.play_sound("select")


func _on_slot_hovered(slot: PanelContainer):
	if slot.is_empty or not slot.item:
		return

	var t = tooltip
	if not t:
		t = get_node_or_null("/root/Main/HUDLayer/Tooltip")
	if not t:
		return

	t.visible = true
	t.display_active_item(slot.item)


func _on_slot_unhovered():
	var t = tooltip
	if not t:
		t = get_node_or_null("/root/Main/HUDLayer/Tooltip")
	if t:
		t.visible = false
