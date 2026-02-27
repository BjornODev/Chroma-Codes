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
			popup_reference.show_popup(
				"[center][b][color=#39FF14]REPLACE %d[/color][/b][/center]" % final_value
			)
			peg_manager_reference.start_replace_mode(final_value)

		"Clear":
			popup_reference.show_popup(
				"[center][b][color=#ffff33]CLEAR %d[/color][/b][/center]" % final_value
			)
			peg_manager_reference.start_clear(final_value * multiplier)

		"Reveal":
			popup_reference.show_popup(
				"[center][b][color=#fbffff]REVEAL %d[/color][/b][/center]" % final_value
			)
			peg_manager_reference.start_reveal(final_value * multiplier)

		"Multiply":
			popup_reference.show_popup(
				"[center][b][color=#BC13FE]MULTIPLY %d[/color][/b][/center]" % base_value
			)
			multiplier += base_value
			popup_reference.mult_increase(multiplier)

		"Bleed":
			popup_reference.show_popup(
				"[center][b][color=#FF073A]BLEED %d[/color][/b][/center]" % final_value
			)
			var cost = base_value
#			if board_reference.player_health >= cost:
			board_reference.apply_damage(cost)
#				BoardModifierEngine.start_disable_mode(final_value * multiplier)

		"Create Healing":
			popup_reference.show_popup(
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