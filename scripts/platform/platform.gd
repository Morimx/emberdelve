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

const BOOTSTRAP := """
window.tbSdk = window.tbSdk || {
  ready: false, env: 'none', muted: false,
  init: function () {
    try {
      if (!window.CrazyGames || !window.CrazyGames.SDK) { this.env = 'missing'; return; }
      var sdk = window.CrazyGames.SDK, self = this;
      sdk.init().then(function () {
        self.env = sdk.environment;
        self.ready = sdk.environment !== 'disabled';
        try { self.muted = !!(sdk.game.settings && sdk.game.settings.muteAudio); } catch (e) {}
      }).catch(function () { self.env = 'disabled'; });
    } catch (e) { this.env = 'disabled'; }
  },
  game: function (name) {
    if (!this.ready) return;
    try { window.CrazyGames.SDK.game[name](); } catch (e) {}
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
var _ready_sdk := false
var _ad_busy := false
var _bridge: JavaScriptObject
## Las callbacks de JavaScript deben seguir vivas mientras el anuncio corre.
var _callbacks: Array = []
var _on_ad_done: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
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
	if _ready_sdk and bool(_bridge.muted):
		Audio.set_muted(true)


func is_active() -> bool:
	return _ready_sdk


func gameplay_start() -> void:
	_game_call("gameplayStart")


func gameplay_stop() -> void:
	_game_call("gameplayStop")


func happy_time() -> void:
	_game_call("happytime")


func rewarded_available() -> bool:
	return _ready_sdk and not _ad_busy


## Pide un anuncio ("rewarded" o "midgame"). on_done(ok) se llama siempre, una vez:
## ok es true solo si el anuncio terminó (en un rewarded, solo entonces se premia).
func request_ad(type: String, on_done: Callable = Callable()) -> void:
	if not _ready_sdk or _ad_busy:
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
