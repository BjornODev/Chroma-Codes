extends Node

var board_reference
var peg_manager_reference
var popup_reference
var multiplier := 1


func set_context(board, peg_manager, popup):
	board_reference = board
	peg_manager_reference = peg_manager
	popup_reference = popup


func apply_keyword(keyword: String, base_value, payload = {}):
	# Color keywords pass a Dictionary {"color": "red", "amount": 2}
	# All others pass an int
	var amount: int
	var color_id: int = 1

	if base_value is Dictionary:
		amount = int(base_value.get("amount", 1))
		color_id = _color_name_to_id(base_value.get("color", "red"))
	else:
		amount = int(base_value)

	var final_value = amount * multiplier

	match keyword:

		"Replace":
			PopUpText.show_popup(
				"[center][b][color=#39FF14]REPLACE %d[/color][/b][/center]" % final_value
			)
			if peg_manager_reference:
				peg_manager_reference.start_replace_mode(final_value)
				ActiveItemManager.on_replace_used(final_value)

		"Clear":
			PopUpText.show_popup(
				"[center][b][color=#ffff33]CLEAR %d[/color][/b][/center]" % final_value
			)
			if peg_manager_reference:
				peg_manager_reference.start_clear(final_value)

		"Reveal":
			PopUpText.show_popup(
				"[center][b][color=#FBFFFF]REVEAL %d[/color][/b][/center]" % final_value
			)
			if peg_manager_reference:
				peg_manager_reference.start_reveal(final_value)

		"Multiply":
			PopUpText.show_popup(
				"[center][b][color=#BC13FE]MULTIPLY %d[/color][/b][/center]" % amount
			)
			multiplier += amount
			PopUpText.mult_increase(multiplier)

		"Bleed":
			PopUpText.show_popup(
				"[center][b][color=#FF073A]BLEED %d[/color][/b][/center]" % final_value
			)
			if board_reference:
				board_reference.apply_damage(amount)

		"Create Healing":
			PopUpText.show_popup(
				"[center][b][color=#ED7117]+%d HEAL PEGS[/color][/b][/center]" % final_value
			)

			for i in range(final_value):
				var heal_peg = preload("res://scenes/Phys_Peg.tscn").instantiate()
				heal_peg.is_special = true
				heal_peg.special_type = "heal"
				heal_peg.is_copy = true
				heal_peg.peg_id = 7
				heal_peg.setup_visuals()
				peg_manager_reference.player_hand_reference.add_special_peg(heal_peg)

		"Create Wild":
			PopUpText.show_popup(
				"[center][b][color=#FF00FF]+%d WILD PEGS[/color][/b][/center]" % final_value
			)
			for i in range(final_value):
				PegInventoryManager.add_wild_pegs(1)
				if peg_manager_reference:
					var wild_peg = preload("res://scenes/Phys_Peg.tscn").instantiate()
					wild_peg.is_special = true
					wild_peg.special_type = "wild"
					wild_peg.is_copy = true
					wild_peg.peg_id = -2
					wild_peg.setup_visuals()
					peg_manager_reference.player_hand_reference.add_special_peg(wild_peg)
	
		"Disable":
			PopUpText.show_popup(
				"[center][b][color=#00FF44]DISABLE %d[/color][/b][/center]" % final_value
			)
			BoardModifierEngine.start_disable_mode(final_value)

		"Cleanse":
			PopUpText.show_popup(
				"[center][b][color=#00FF44]CLEANSE %d[/color][/b][/center]" % final_value
			)
			if board_reference:
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

		"Extra Dollar":
			PopUpText.show_popup(
				"[center][b][color=#FFD700]+%d DOLLAR[/color][/b][/center]" % final_value
			)
			RunProgressionManager.add_dollars(final_value)

		"Add Color":
			PegInventoryManager.add_pegs_to_color(color_id, final_value)

		"Add All Colors":
			PegInventoryManager.add_pegs_to_all(final_value)

		"Remove Color":
			PegInventoryManager.remove_pegs_from_color(color_id, amount)

		"Remove All Colors":
			PegInventoryManager.remove_pegs_from_all(amount)

		"Obscure":
			if board_reference:
				board_reference.obscurities += amount


func _color_name_to_id(color_name: String) -> int:
	match color_name:
		"red": return 1
		"yellow": return 2
		"green": return 3
		"white": return 4
		"purple": return 5
		"orange": return 6
	return 0