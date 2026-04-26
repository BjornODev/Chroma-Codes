extends Node

var board_reference
var peg_manager_reference
var popup_reference
var multiplier := 1

func set_context(board, peg_manager, popup):
	board_reference = board
	peg_manager_reference = peg_manager
	popup_reference = popup

func apply_keyword(keyword : String, base_value : int, payload = {}):
	var final_value = base_value * multiplier

	match keyword:

		"Replace":
			PopUpText.show_popup(
				"[center][b][color=#39FF14]REPLACE %d[/color][/b][/center]" % final_value
			)
			peg_manager_reference.start_replace_mode(final_value)
			ActiveItemManager.on_replace_used(final_value)

		"Clear":
			PopUpText.show_popup(
				"[center][b][color=#ffff33]CLEAR %d[/color][/b][/center]" % final_value
			)
			peg_manager_reference.start_clear(final_value)

		"Reveal":
			PopUpText.show_popup(
				"[center][b][color=#FBFFFF]REVEAL %d[/color][/b][/center]" % final_value
			)
			peg_manager_reference.start_reveal(final_value)

		"Multiply":
			PopUpText.show_popup(
				"[center][b][color=#BC13FE]MULTIPLY %d[/color][/b][/center]" % base_value
			)
			multiplier += base_value
			PopUpText.mult_increase(multiplier)

		"Bleed":
			PopUpText.show_popup(
				"[center][b][color=#FF073A]BLEED %d[/color][/b][/center]" % final_value
			)
			var cost = base_value
#			if board_reference.player_health >= cost:
			board_reference.apply_damage(cost)

		"Create Healing":
			PopUpText.show_popup(
				"[center][b][color=#ED7117]+%d HEAL PEGS[/color][/b][/center]" % final_value
			)
		
			for i in range(final_value):
				var heal_peg = preload("res://scenes/Phys_Peg.tscn").instantiate()
				
				heal_peg.is_special = true
				heal_peg.special_type = "heal"
				heal_peg.is_copy = true
				heal_peg.peg_id = 7  # does not map to real color
				heal_peg.setup_visuals()
				
				peg_manager_reference.player_hand_reference.add_special_peg(heal_peg)
		
		"Disable":
			PopUpText.show_popup(
				"[center][b][color=#00FF44]DISABLE %d[/color][/b][/center]" % final_value
			)
			BoardModifierEngine.start_disable_mode(final_value)
		
		"Cleanse":
			PopUpText.show_popup(
				"[center][b][color=#00FF44]CLEANSE %d[/color][/b][/center]" % final_value
			)
			DollarManager.relight_multiple(final_value)
		
		"Heal":
			PopUpText.show_popup(
				"[center][b][color=#B0FC38]HEAL %d[/color][/b][/center]" % final_value
			)
			RunProgressionManager.add_health(final_value)
		
		"Unlock Any":
			PopUpText.show_popup(
				"[center][b][color=#FFD700]UNLOCK ANY PANEL[/color][/b][/center]"
			)
			MapManager.activate_unlock_any()
		
		"Charge Active":
			PopUpText.show_popup(
				"[center][b][color=#FFD700]CHARGE ACTIVE +%d[/color][/b][/center]" % final_value
			)
			for item in ItemManager.player_items:
				if item.is_active:
					ActiveItemManager.add_charge_direct(item, float(final_value))
		
		"AddPegsColor":
			# payload must include "color_id"
			var color_id = payload.get("color_id", 1)
			PegInventoryManager.add_pegs_to_color(color_id, final_value)
		
		"AddPegsAll":
			PegInventoryManager.add_pegs_to_all(final_value)
		
		"RemovePegsColor":
			var color_id = payload.get("color_id", 1)
			PegInventoryManager.remove_pegs_from_color(color_id, base_value)
		
		"RemovePegsAll":
			PegInventoryManager.remove_pegs_from_all(base_value)
