extends Node
## Autoload "Platform": puente con el SDK v3 de CrazyGames (https://docs.crazygames.com/sdk/).
## Fuera de web, o en un dominio donde el SDK está deshabilitado, todo es no-op y
## rewarded_available() devuelve false: el juego nunca depende de un anuncio.
##
## El script del SDK lo carga index.html (preset Web, html/head_include). Todas las
## llamadas pasan por window.tbSdk, que atrapa los errores del lado JavaScript
## (en dominios "disabled" cada llamada al SDK lanza una excepción).

signal ad_started()
signal ad_finished(ok: bool)
## Se emite una vez, cuando ya se sabe si el SDK está disponible (o fuera de web).
signal sdk_checked()

## En Basic Launch CrazyGames desactiva los anuncios y prohíbe botones de recompensa sin
## efecto: queda en false hasta el paso a Full Launch.
const ADS_ENABLED := false

const BOOTSTRAP := """
window.tbSdk = window.tbSdk || {
  ready: false, env: 'none', muted: false, locale: '',
  init: function () {
    try {
      if (!window.CrazyGames || !window.CrazyGames.SDK) { this.env = 'missing'; return; }
      var sdk = window.CrazyGames.SDK, self = this;
      sdk.init().then(function () {
        self.env = sdk.environment;
        self.ready = sdk.environment !== 'disabled';
        try { self.muted = !!(sdk.game.settings && sdk.game.settings.muteAudio); } catch (e) {}
        try { self.locale = String((sdk.user.systemInfo && sdk.user.systemInfo.locale) || ''); } catch (e) {}
      }).catch(function () { self.env = 'disabled'; });
    } catch (e) { this.env = 'disabled'; }
  },
  game: function (name) {
    if (!this.ready) return;
    try { window.CrazyGames.SDK.game[name](); } catch (e) {}
  },
  dataGet: function (key) {
    if (!this.ready) return '';
    try { var v = window.CrazyGames.SDK.data.getItem(key); return v === null || v === undefined ? '' : String(v); } catch (e) { return ''; }
  },
  dataSet: function (key, value) {
    if (!this.ready) return;
    try { window.CrazyGames.SDK.data.setItem(key, value); } catch (e) {}
  },
  dataRemove: function (key) {
    if (!this.ready) return;
    try { window.CrazyGames.SDK.data.removeItem(key); } catch (e) {}
  },
  ad: function (type, started, finished, failed) {
    if (!this.ready) { failed('notReady'); return; }
    try {
      window.CrazyGames.SDK.ad.requestAd(type, {
        adStarted: function () { started(); },
        adFinished: function () { finished(); },
        adError: function (e) { failed(e && e.code ? e.code : 'other'); }
      });
    } catch (e) { failed('other'); }
  }
};
window.tbSdk.init();
"""

var environment := "none"
## Idioma que informa el SDK (p. ej. "es-ES"); "" sin SDK.
var locale := ""
var checked := false
var _ready_sdk := false
var _ad_busy := false
var _bridge: JavaScriptObject
## Las callbacks de JavaScript deben seguir vivas mientras el anuncio corre.
var _callbacks: Array = []
var _on_ad_done: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		_mark_checked()
		return
	JavaScriptBridge.eval(BOOTSTRAP, true)
	_bridge = JavaScriptBridge.get_interface("tbSdk")
	# init() es asíncrono: se consulta unos segundos hasta que responda.
	for i in 40:
		await get_tree().create_timer(0.25, true, false, true).timeout
		environment = str(_bridge.env)
		if environment in ["crazygames", "local", "disabled", "missing"]:
			break
	_ready_sdk = bool(_bridge.ready)
	locale = str(_bridge.locale) if _ready_sdk else ""
	if _ready_sdk and bool(_bridge.muted):
		Audio.set_muted(true)
	_mark_checked()


func _mark_checked() -> void:
	checked = true
	sdk_checked.emit()


## Espera a que se sepa si el SDK está disponible. Sin web, vuelve enseguida.
func wait_checked() -> void:
	if not checked:
		await sdk_checked


# --- Data Module: copia del guardado en CrazyGames (sigue al jugador si inicia sesión) ---

func data_get(key: String) -> String:
	return str(_bridge.dataGet(key)) if _ready_sdk else ""


func data_set(key: String, value: String) -> void:
	if _ready_sdk:
		_bridge.dataSet(key, value)


func data_remove(key: String) -> void:
	if _ready_sdk:
		_bridge.dataRemove(key)


## Código de idioma del jugador según CrazyGames ("es", "en"...), o "" si no se sabe.
func system_language() -> String:
	return locale.get_slice("-", 0).to_lower()


func is_active() -> bool:
	return _ready_sdk


func gameplay_start() -> void:
	_game_call("gameplayStart")


func gameplay_stop() -> void:
	_game_call("gameplayStop")


func happy_time() -> void:
	_game_call("happytime")


func rewarded_available() -> bool:
	return ADS_ENABLED and _ready_sdk and not _ad_busy


## Pide un anuncio ("rewarded" o "midgame"). on_done(ok) se llama siempre, una vez:
## ok es true solo si el anuncio terminó (en un rewarded, solo entonces se premia).
func request_ad(type: String, on_done: Callable = Callable()) -> void:
	if not ADS_ENABLED or not _ready_sdk or _ad_busy:
		if on_done.is_valid():
			on_done.call(false)
		return
	_ad_busy = true
	_on_ad_done = on_done
	var started := JavaScriptBridge.create_callback(_js_started)
	var finished := JavaScriptBridge.create_callback(_js_finished)
	var failed := JavaScriptBridge.create_callback(_js_failed)
	_callbacks = [started, finished, failed]
	_bridge.ad(type, started, finished, failed)


func _game_call(name: String) -> void:
	if _ready_sdk:
		_bridge.game(name)


func _js_started(_args: Array) -> void:
	# Durante el anuncio: sin sonido y con el juego en pausa (requisito de CrazyGames).
	Audio.set_ad_mute(true)
	get_tree().paused = true
	ad_started.emit()


func _js_finished(_args: Array) -> void:
	_end_ad(true)


func _js_failed(_args: Array) -> void:
	_end_ad(false)


func _end_ad(ok: bool) -> void:
	Audio.set_ad_mute(false)
	get_tree().paused = false
	_ad_busy = false
	_callbacks.clear()
	ad_finished.emit(ok)
	if _on_ad_done.is_valid():
		var done := _on_ad_done
		_on_ad_done = Callable()
		done.call(ok)
