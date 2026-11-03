class_name Locale
extends RefCounted
## Idioma del juego: inglés (los textos fuente) o español (LocaleEs.TEXT).
## "" en el guardado significa usar el idioma del navegador o del sistema.

const SUPPORTED: PackedStringArray = ["en", "es"]

static var _registered := false


## Aplica el idioma pedido; si no es válido, elige según el sistema.
static func apply(language: String) -> void:
	_register()
	if not language in SUPPORTED:
		language = "es" if OS.get_locale_language() == "es" else "en"
	TranslationServer.set_locale(language)


static func current() -> String:
	return "es" if TranslationServer.get_locale().begins_with("es") else "en"


static func _register() -> void:
	if _registered:
		return
	_registered = true
	var t := Translation.new()
	t.locale = "es"
	for key in LocaleEs.TEXT:
		t.add_message(key, LocaleEs.TEXT[key])
	TranslationServer.add_translation(t)
