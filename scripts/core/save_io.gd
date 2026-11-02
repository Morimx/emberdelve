class_name SaveIO
extends RefCounted
## JSON a prueba de cortes: escribe a .tmp, conserva la versión anterior como .bak y renombra.
## Al leer, si el archivo principal falta o está roto, prueba con el .bak.


static func save_json(path: String, data: Dictionary) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	if not file.store_string(JSON.stringify(data)):
		return ERR_FILE_CANT_WRITE
	file.close()
	if FileAccess.file_exists(path):
		var err := DirAccess.rename_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp, path)


## Devuelve {} si no hay nada legible. "version" vuelve como int (JSON lo trae como float).
static func load_json(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(p))
		if data is Dictionary and data.has("version"):
			data["version"] = int(data["version"])
			return data
		push_warning("Guardado ilegible en %s." % p)
	return {}


static func remove(path: String) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
