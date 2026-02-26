class_name PatternData
extends Resource

@export var pattern_name : String
@export var type : String = "grid"

@export var width : int
@export var height : int
@export var grid : Array

# Optional behavior controls
@export var allowed_rows : Array[int] = []
@export var duplicate_type : String = ""   # "", "any", "fixed"
@export var duplicate_rows : Array[int] = []