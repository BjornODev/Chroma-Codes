# =========================
# ADD TO KeywordEngine.gd
# Inside apply_keyword match block:
# =========================

#		"ExtraDollar":
#			popup_reference.show_popup(
#				"[center][b][color=#FFD700]+%d DOLLAR[/color][/b][/center]" % final_value
#			)
#			# payload must contain the dollar display reference
#			var display = payload.get("display")
#			if display:
#				for i in range(final_value):
#					# Queue activation on the same dollar index that triggered this
#					var trigger_index = payload.get("index", 0)
#					display.queue_extra_activation(trigger_index)


# =========================
# ITEM DATA SETUP FOR DOLLAR TRIGGERS
# =========================
# To create an item that triggers on dollar 3 (index 2):
#
# triggers: [
#   { "event": "dollar_activated", "index": 2 }
# ]
# keywords: { "ExtraDollar": 1 }
#
# This fires when dollar index 2 animates and adds one extra activation


# =========================
# PROCESS_ITEM_EVENT UPDATE IN ItemManager.gd
# =========================
# The existing process_item_event checks trigger.has("pattern") for pattern events.
# Add a similar check for dollar index:
#
# func process_item_event(item, event_name, payload):
# 	for trigger in item.triggers:
# 		if trigger.event != event_name:
# 			continue
#
# 		if trigger.has("pattern"):
# 			if payload.get("pattern_name") != trigger.pattern:
# 				continue
#
# 		# NEW: dollar index check
# 		if trigger.has("index"):
# 			if payload.get("index") != trigger.index:
# 				continue
#
# 		apply_item_effects(item, payload)


# =========================
# SCENE STRUCTURE FOR RewardsSelectionUI.tscn
# =========================
# CanvasLayer (RewardsSelectionUI.gd)
# ├── ColorRect "bg" (full screen dark overlay)
# └── VBoxContainer
#     ├── DollarDisplay (DollarDisplay.tscn)  ← NEW: above reward columns
#     ├── HBoxContainer (reward columns)
#     ├── ConfirmButton
#     └── RunSummary (RunSummary.tscn)         ← NEW: below confirm button


# =========================
# SCENE STRUCTURE FOR DollarDisplay.tscn
# =========================
# Control (DollarDisplay.gd)
# └── HBoxContainer "DotsContainer"


# =========================
# SCENE STRUCTURE FOR RunSummary.tscn
# =========================
# PanelContainer (RunSummary.gd)
# └── MarginContainer
#     └── VBoxContainer "content"
