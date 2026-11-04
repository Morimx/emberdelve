class_name Locale
extends RefCounted
## Idioma del juego: inglés (los textos fuente) o español (LocaleEs.TEXT).
## "" en el guardado significa usar el idioma del navegador o del sistema.

const SUPPORTED: PackedStringArray = ["en", "es"]

static var _registered := false


## Aplica el idioma pedido; si no es válido, usa el que informa la plataforma (SDK)
## y, si tampoco, el del sistema. Todo lo que no sea español cae en inglés.
static func apply(language: String, platform_language := "") -> void:
	_register()
	if not language in SUPPORTED:
		var system := platform_language if platform_language != "" else OS.get_locale_language()
		language = "es" if system == "es" else "en"
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
