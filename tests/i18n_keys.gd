class_name I18nKeys
extends RefCounted
## Junta todos los textos visibles que pasan por tr(): literales en scripts, datos .tres,
## constantes de nombres y frases de diálogo. Lo usan las pruebas para exigir traducción.

const SCRIPT_DIRS: PackedStringArray = ["res://scripts"]
const DATA_DIRS: PackedStringArray = ["res://data"]
const RESOURCE_FIELDS: PackedStringArray = ["display_name", "description", "skill_name", "skill_description"]


static func collect() -> PackedStringArray:
	var keys := {}
	var literal := RegEx.create_from_string(r'tr\("([^"]*)"\)')
	# Textos que la UI traduce de otros lugares: nombres de puertas, resultados, etiquetas.
	var quoted := RegEx.create_from_string(r'"(?:name|desc|label|text)": "([^"]*)"')
	var result_text := RegEx.create_from_string(r'\["text"\] = "([^"]*)"')
	for path in _files(SCRIPT_DIRS, ".gd"):
		var src := FileAccess.get_file_as_string(path)
		for m in literal.search_all(src):
			keys[m.get_string(1).c_unescape()] = true
		for m in quoted.search_all(src):
			keys[m.get_string(1).c_unescape()] = true
		for m in result_text.search_all(src):
			keys[m.get_string(1).c_unescape()] = true
	for path in _files(DATA_DIRS, ".tres"):
		var res := load(path)
		for field in RESOURCE_FIELDS:
			var value = res.get(field)
			if value is String and value != "":
				keys[value] = true
	for v in Loot.RARITY_NAMES:
		keys[v] = true
	for v in Loot.SLOT_NAMES.values():
		keys[v] = true
	for names in Loot.BASE_NAMES.values():
		for v in names:
			keys[v] = true
	for v in load("res://scripts/ui/main.gd").OUTCOME_TEXT.values():
		keys[v] = true
	for v in TalentScreen.BRANCH_NAMES.values():
		keys[v] = true
	for v in ["Attack", "Defense", "Health"]:
		keys[v] = true
	for speaker in Dialogue.LINES:
		for context in Dialogue.LINES[speaker]:
			for v in Dialogue.LINES[speaker][context]:
				keys[v] = true
	keys.erase("")
	var out := PackedStringArray(keys.keys())
	out.sort()
	return out


static func _files(dirs: PackedStringArray, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var pending := Array(dirs)
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(ext):
				out.append(dir.path_join(f))
	return out
