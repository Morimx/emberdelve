class_name RunStore
extends RefCounted
## Autoguardado de la expedición en curso, en un archivo aparte del progreso permanente.
## Si el navegador se cierra a mitad de expedición, se reanuda desde la última sala.

const PATH := "user://run.json"


static func save_run(ex: Expedition, path: String = PATH) -> Error:
	if ex.finished:
		return OK
	return SaveIO.save_json(path, ex.to_dict())


## Devuelve la expedición guardada, o null si no hay, está rota o ya se cobró.
static func load_run(meta: MetaState, path: String = PATH) -> Expedition:
	var data := SaveIO.load_json(path)
	if data.is_empty():
		return null
	if str(data.get("run_id", "")) == meta.last_run_id:
		clear(path)
		return null
	var ex := GameData.restore_expedition(data)
	if ex == null:
		push_warning("Autoguardado de expedición incompatible; se descarta.")
		clear(path)
	return ex


static func clear(path: String = PATH) -> void:
	SaveIO.remove(path)
