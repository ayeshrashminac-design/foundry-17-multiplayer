extends RefCounted

const OPERATORS := [
	{"name":"SWAT", "role":"Urban response", "path":"res://tactical/assets/operator_realistic.glb", "arms":""},
	{"name":"ELY", "role":"Field specialist", "path":"res://tactical/assets/operator_ely.glb", "arms":"res://tactical/assets/arms_ely.glb"},
	{"name":"VANGUARD", "role":"Heavy protection", "path":"res://tactical/assets/operator_vanguard.glb", "arms":"res://tactical/assets/arms_vanguard.glb"}
]

static func valid_id(value: int) -> int:
	return clampi(value,0,OPERATORS.size()-1)
