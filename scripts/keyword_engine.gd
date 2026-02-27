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
                "[center][b][color=#ffaa00]REPLACE %d[/color][/b][/center]" % final_value
            )
            peg_manager_reference.start_replace_mode(final_value)

        "Clear":
            popup_reference.show_popup(
                "[center][b][color=#ff4444]CLEAR %d[/color][/b][/center]" % final_value
            )
            peg_manager_reference.start_clear(final_value)

        "Reveal":
            popup_reference.show_popup(
                "[center][b][color=#ffffff]REVEAL %d[/color][/b][/center]" % final_value
            )
            peg_manager_reference.start_reveal(final_value)

        "Multiply":
            multiplier += base_value

        "Disable":
            var cost = final_value * 3
            if board_reference.player_health >= cost:
                board_reference.apply_damage(cost)
                BoardModifierEngine.disable_modifiers(final_value)