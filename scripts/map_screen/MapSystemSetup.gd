# =========================
# MAP SYSTEM SETUP NOTES
# =========================


# =========================
# AUTOLOAD
# =========================
# Add MapManager.gd as autoload named "MapManager"
# Call MapManager.start_run(seed) when starting a new run
# The seed can come from RunProgressionManager or be generated fresh each run


# =========================
# MAPSCREEN SCENE STRUCTURE
# =========================
# Control (MapScreen.gd)
# ├── GridContainer (columns=6, separation=8)
# ├── IrisWipe (CanvasLayer, IrisWipe.gd)
# │   └── ShaderRect (ColorRect, full screen, IrisWipe.gdshader on ShaderMaterial)
# └── CautionOverlay (CanvasLayer, CautionOverlay.gd)
#     └── Control
#         ├── BG (ColorRect, full screen)
#         └── CautionLabel (Label)


# =========================
# MAPPANEL SCENE STRUCTURE
# =========================
# PanelContainer (MapPanel.gd, custom_minimum_size 90x90)
# ├── ColorRect (fills panel, shows color)
# ├── CenterContainer
# │   └── Icon (ColorRect, 24x24, placeholder shape)
# └── LockOverlay (ColorRect, full size, dark semi-transparent)


# =========================
# IRIS WIPE SHADER SETUP
# =========================
# 1. Create IrisWipe.gdshader in your shaders folder
# 2. Create a ShaderMaterial using that shader
# 3. Apply it to a full-screen ColorRect named ShaderRect
# 4. The ShaderRect should be inside a CanvasLayer so it draws over everything
# 5. Set the ColorRect color to black (the shader overrides this but needed as base)


# =========================
# RETURNING TO MAP
# =========================
# After a Board is completed and reward is confirmed, instead of calling
# start_next_board(), if in a run with a map:
#   get_tree().change_scene_to_file("res://scenes/MapScreen.tscn")
# The MapScreen will call iris_open_center() in its _ready()
# if coming back from a board, or iris_open from panel pos for others.
#
# To pass the panel position back, store it in MapManager before leaving:
#   MapManager.last_panel_world_pos = pending_global_pos
# Then in MapScreen._ready() read it and call iris_wipe.iris_open(pos)


# =========================
# BOSS MODIFIER USAGE
# =========================
# After boss is triggered, call:
#   var modifier_info = MapManager.get_boss_modifier_type()
#   # modifier_info = {"balanced": bool, "color": String, "severity": String}
# Use this to pick from your boss modifier pools:
#   if modifier_info.balanced:
#     # pick from balanced pool (20 modifiers)
#   else:
#     # pick from unbalanced pool filtered by color and severity


# =========================
# SEED INTEGRATION
# =========================
# In RunProgressionManager.start_new_run(), generate and store a seed:
#   var seed = randi()
#   MapManager.start_run(seed)
# This ensures the same map layout for the whole run


# =========================
# PANEL TYPE ICONS (PLACEHOLDER)
# =========================
# Currently each type is color-coded via TYPE_ICON_COLORS in MapPanel.gd
# and distinguished by label. When you have real assets:
# 1. Add an @export var icon_texture: Texture2D to MapPanel
# 2. Set icon_rect.texture = icon_texture in setup()
# 3. Pass the texture in from MapScreen based on panel_type
