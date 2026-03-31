# =========================
# SETUP NOTES
# =========================

# 1. ADD BackgroundGenerator as an AUTOLOAD named "BackgroundGenerator"

# 2. In BoardManager.gd, replace:
#       $"../BackgroundLayer".change_background(randi() % 5)
#    with:
#       $"../BackgroundLayer".change_background("Board")

# 3. In MapScreen.gd _ready(), call:
#       $BackgroundLayer.change_background_map()
#    (add a BackgroundLayer node to your MapScreen scene with the same structure)

# 4. SCENE STRUCTURE for BackgroundLayer.tscn:
#    Node2D (BackgroundLayer.gd)
#    └── TextureRect "BGTextureRect"
#        - Anchors: Full Rect
#        - Stretch Mode: Scale
#        - ShaderMaterial with your Earthbound shader attached
#        - Make the material unique per scene instance

# 5. The Earthbound shader's screen_height uniform should be set to 1080.0

# 6. PERFORMANCE NOTE:
#    BackgroundGenerator caches textures by seed, so returning to the same
#    board type in the same run reuses the cached texture instantly.
#    Call BackgroundGenerator.clear_cache() in RunProgressionManager.start_new_run()
#    to free memory between runs.

# 7. ADD TO RunProgressionManager.start_new_run():
#    BackgroundGenerator.clear_cache()

# 8. The DOWNSAMPLE constant in BackgroundGenerator controls performance vs quality:
#    4 = generates at 480x270 then scales up (fast, slightly soft)
#    2 = generates at 960x540 (moderate)
#    1 = full 1920x1080 (slow but sharp — not recommended at runtime)
