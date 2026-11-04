class_name DungeonBackdrop
extends Control
## Fondo de la arena. Cambia según el bioma de la mazmorra y el escenario de la sala:
##   biomas:     catacombs (ladrillo, nichos con calaveras), crypt (piedra con musgo, agua, goteo),
##               forge (ladrillo rojizo, grietas de lava, brasas, cadenas)
##   escenarios: corridor (combate), elite (estandartes), shrine (evento), camp (fogata), boss (trono)
## La viñeta se cierra cuando queda poca antorcha.

const FLOOR_RATIO := 0.7
const MAX_PARTICLES := 40
const BIOME_ACCENT := {&"catacombs": Color("6b3fa0"), &"crypt": Color("1f6f6a"), &"forge": Color("8a2a1e")}
## Estandarte de pared de cada bioma (pack de 0x72) y color de su fuente en el santuario.
const BIOME_BANNER := {&"catacombs": "wall_banner_red", &"crypt": "wall_banner_blue", &"forge": "wall_banner_yellow"}
const BIOME_FOUNTAIN := {&"catacombs": "blue", &"crypt": "blue", &"forge": "red"}
const PROP_SCALE := 3.0
const BOSS_GLOW := {&"catacombs": Color(0.6, 0.35, 1.0, 0.55), &"crypt": Color(0.3, 0.9, 0.9, 0.5), &"forge": Color(1.0, 0.45, 0.15, 0.6)}

var _light := 1.0
var _target_light := 1.0
var _time := 0.0
var _biome: StringName = &"catacombs"
var _scene: StringName = &"corridor"
var _vignette := TextureRect.new()
var _vignette_tex := GradientTexture2D.new()
var _glows: Array[TextureRect] = []
var _flames: Array[TextureRect] = []
var _campfire := TextureRect.new()
var _altar_flame := TextureRect.new()
var _arch_glow := TextureRect.new()
var _wall_tint := Color(0.8, 0.8, 0.95)
var _floor_color := Color("141a3d")
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_arch_glow.texture = _radial(Color.WHITE)
	_arch_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arch_glow.visible = false
	add_child(_arch_glow)
	for i in 2:
		var glow := TextureRect.new()
		glow.texture = _radial(Color(1.0, 0.6, 0.25, 0.55))
		glow.size = Vector2(220, 220)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow)
		_glows.append(glow)
		var flame := _pixel_rect(&"torch", Vector2(24, 30))
		add_child(flame)
		_flames.append(flame)
	_campfire = _pixel_rect(&"fire", Vector2(54, 54))
	_campfire.visible = false
	add_child(_campfire)
	_altar_flame = _pixel_rect(&"fire", Vector2(36, 36))
	_altar_flame.modulate = Color(0.55, 0.85, 1.6)  # llama azul del santuario
	_altar_flame.visible = false
	add_child(_altar_flame)
	_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	_vignette_tex.fill_from = Vector2(0.5, 0.62)
	_vignette_tex.fill_to = Vector2(1.05, 0.62)
	_vignette_tex.gradient = Gradient.new()
	_vignette.texture = _vignette_tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = 1
	add_child(_vignette)
	_rng.seed = 5
	_apply_light()
	resized.connect(_layout)
	_layout()


## ratio 0..1: cuánta luz queda. La viñeta se cierra con poca luz.
func set_light(ratio: float) -> void:
	_target_light = clampf(ratio, 0.0, 1.0)


## Bioma de la mazmorra y sus colores (tinte de pared y piso).
func set_biome(biome: StringName, wall_tint: Color, floor_color: Color) -> void:
	_biome = biome
	_wall_tint = wall_tint
	_floor_color = floor_color
	_particles.clear()
	_layout()


## Escenario de la sala actual: corridor, elite, shrine, camp o boss.
func set_scene(scene: StringName) -> void:
	_scene = scene
	_layout()


## Compatibilidad: mantiene el bioma actual y solo cambia colores.
func set_palette(wall_tint: Color, floor_color: Color) -> void:
	set_biome(_biome, wall_tint, floor_color)


func set_campfire(on: bool) -> void:
	set_scene(&"camp" if on else &"corridor")


func _process(delta: float) -> void:
	_time += delta
	if absf(_light - _target_light) > 0.001:
		_light = lerpf(_light, _target_light, minf(1.0, delta * 3.0))
		_apply_light()
	for i in _glows.size():
		var f := 0.85 + 0.15 * sin(_time * 7.0 + i * 2.1) * sin(_time * 3.3 + i)
		_glows[i].modulate.a = f
		_flames[i].scale = Vector2(1.0, 0.92 + 0.08 * f)
	if _campfire.visible:
		_campfire.scale = Vector2(1.0, 0.94 + 0.06 * sin(_time * 9.0))
	if _altar_flame.visible:
		_altar_flame.scale = Vector2(1.0, 0.92 + 0.08 * sin(_time * 8.0))
	if _arch_glow.visible:
		_arch_glow.modulate.a = 0.8 + 0.2 * sin(_time * 2.0)
	_update_particles(delta)
	queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var floor_y := size.y * FLOOR_RATIO
	if _biome == &"training":
		_draw_training(floor_y)
		return
	# Pared: textura del bioma a mitad de tamaño con transformación x2 (pixeles gruesos).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	draw_texture_rect(_wall_texture(_biome), Rect2(Vector2.ZERO, Vector2(size.x / 2.0, floor_y / 2.0)), true, _wall_tint)
	draw_set_transform(Vector2.ZERO)
	_draw_wall_props(floor_y)
	var boss := _scene == &"boss"
	# El ancho se limita por la altura: en una arena baja el arco igual entra.
	var arch_h := floor_y * (0.9 if boss else 0.78)
	_draw_arch(Vector2(size.x * 0.5, floor_y), minf(size.x * (0.19 if boss else 0.14), arch_h * (0.5 if boss else 0.42)), arch_h)
	if _scene == &"elite" or boss:
		_draw_banners(floor_y, boss)
	var half := minf(size.x * (0.19 if boss else 0.14), arch_h * (0.5 if boss else 0.42))
	if _scene == &"shrine":
		_draw_fountains(floor_y, half)
	else:
		if _scene != &"elite" and not boss:
			_draw_wall_banners(floor_y, half)
		if not boss:  # el jefe ya tiene estandartes y antorchas junto al arco
			_draw_columns(floor_y, arch_h, half)
	# Piso
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), _floor_color)
	draw_texture_rect(_cobble_texture(), Rect2(0, floor_y, size.x, size.y - floor_y), true, _floor_color.lightened(0.35))
	_draw_floor_details(floor_y)
	draw_rect(Rect2(0, floor_y - 3, size.x, 4), Color("0a0d26"))
	if _scene == &"shrine":
		_draw_altar(floor_y)
	for p in _particles:
		var c: Color = p.color
		c.a *= clampf(p.life, 0.0, 1.0)
		draw_rect(Rect2(p.pos, Vector2(p.size, p.size * (2.0 if _biome == &"crypt" else 1.0))), c)


# --- detalles de cada bioma -------------------------------------------------------

func _draw_wall_props(floor_y: float) -> void:
	match _biome:
		&"catacombs":
			# Nichos con calaveras a los costados.
			for x in [size.x * 0.07, size.x * 0.93]:
				var niche := Rect2(x - 22, floor_y * 0.52, 44, 34)
				draw_rect(niche, Color("06081a"))
				draw_rect(niche, Color("2a3470"), false, 2.0)
				draw_texture_rect(SpriteBank.texture(&"skull"), Rect2(x - 13, floor_y * 0.52 + 6, 26, 24), false, Color(0.85, 0.82, 0.75))
		&"crypt":
			# Musgo colgando del borde superior.
			for i in 14:
				var x := fmod(i * 73.0 + 11.0, size.x)
				var h := 10.0 + fmod(i * 37.0, 26.0)
				draw_rect(Rect2(x, 0, 4, h), Color(0.18, 0.42, 0.28, 0.9))
				draw_rect(Rect2(x + 4, 0, 2, h * 0.6), Color(0.12, 0.3, 0.2, 0.9))
		&"forge":
			# Cadenas colgando del techo.
			for x in [size.x * 0.07, size.x * 0.93, size.x * 0.32, size.x * 0.68]:
				var links := int(floor_y * 0.12 / 8.0) + 3
				for k in links:
					var r := Rect2(x - 3, k * 8.0, 6, 6)
					draw_rect(r, Color("5a5f6a"), false, 2.0)


func _draw_floor_details(floor_y: float) -> void:
	var depth := size.y - floor_y
	match _biome:
		&"catacombs":
			# Huesos sueltos.
			for i in 9:
				var x := fmod(i * 131.0 + 40.0, size.x)
				var y := floor_y + 8.0 + fmod(i * 23.0, depth - 14.0)
				draw_rect(Rect2(x, y, 10, 3), Color(0.82, 0.78, 0.66, 0.85))
				draw_rect(Rect2(x - 2, y - 1, 3, 5), Color(0.82, 0.78, 0.66, 0.85))
				draw_rect(Rect2(x + 9, y - 1, 3, 5), Color(0.82, 0.78, 0.66, 0.85))
		&"crypt":
			# Agua: capa translúcida con reflejos que se mueven.
			draw_rect(Rect2(0, floor_y + depth * 0.25, size.x, depth * 0.75), Color(0.1, 0.35, 0.45, 0.45))
			for row in 5:
				var y := floor_y + depth * (0.32 + row * 0.13)
				for k in 7:
					var x := fmod(k * 150.0 + row * 60.0 + sin(_time * 1.3 + row) * 24.0 + _time * 14.0 * (1 if row % 2 == 0 else -1), size.x + 60.0) - 30.0
					draw_rect(Rect2(x, y, 26, 2), Color(0.6, 0.9, 1.0, 0.35))
			# Algas en los bordes.
			for x in [size.x * 0.03, size.x * 0.15, size.x * 0.86, size.x * 0.97]:
				for k in 4:
					var sway := sin(_time * 2.0 + x) * 3.0 * k / 4.0
					draw_rect(Rect2(x + sway, floor_y - k * 7.0, 4, 8), Color(0.2, 0.55, 0.35))
		&"forge":
			# Grietas de lava que laten.
			var pulse := 0.55 + 0.45 * sin(_time * 2.4)
			var hot := Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.85, 0.3), pulse)
			for i in 6:
				var x0 := fmod(i * 173.0 + 30.0, size.x)
				var y0 := floor_y + 10.0 + fmod(i * 31.0, depth - 20.0)
				var pts := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + 22, y0 + 6), Vector2(x0 + 40, y0 + 2), Vector2(x0 + 64, y0 + 10)])
				draw_polyline(pts, Color(hot.r, hot.g, hot.b, 0.35), 7.0)
				draw_polyline(pts, hot, 3.0)


func _draw_banners(floor_y: float, boss: bool) -> void:
	var accent: Color = BIOME_ACCENT.get(_biome, Color("6b3fa0"))
	var offset := size.x * (0.27 if boss else 0.22)
	for side in [-1.0, 1.0]:
		var x: float = size.x * 0.5 + side * offset
		var w := 34.0
		var h := floor_y * 0.5
		draw_rect(Rect2(x - w / 2.0 - 4, 10, w + 8, 4), Color("5a5f6a"))
		draw_rect(Rect2(x - w / 2.0, 14, w, h), accent)
		draw_rect(Rect2(x - w / 2.0 + 4, 14, w - 8, h), accent.lightened(0.12))
		var tip := PackedVector2Array([Vector2(x - w / 2.0, 14 + h), Vector2(x + w / 2.0, 14 + h), Vector2(x, 14 + h + 14)])
		draw_colored_polygon(tip, accent)
		draw_rect(Rect2(x - 6, 14 + h * 0.35, 12, 12), Color("f2c14e"))


## Sala de entrenamiento (tutorial): toda de baldosas del pack de 0x72, con su puerta,
## estandartes verdes y cajas. Se distingue a propósito de las mazmorras del juego.
func _draw_training(floor_y: float) -> void:
	var t := 16.0 * PROP_SCALE
	var wall := Props.texture("wall_mid")
	var holes := [Props.texture("wall_hole_1"), Props.texture("wall_hole_2")]
	var rows := ceili(floor_y / t)
	var cols := ceili(size.x / t) + 1
	for r in rows:
		var y := floor_y - (r + 1) * t
		for c in cols:
			var tex: Texture2D = wall
			var h := (c * 7 + r * 13) % 23
			if h == 3:
				tex = holes[(c + r) % 2]
			draw_texture_rect(tex, Rect2(c * t, y, t, t), false)
	for c in cols:
		draw_texture_rect(Props.texture("wall_top_mid"), Rect2(c * t, floor_y - rows * t - t * 0.5, t, t), false)
	# Piso de baldosas variadas (siempre las mismas en cada lugar).
	var floor_rows := ceili((size.y - floor_y) / t)
	for r in floor_rows:
		for c in cols:
			var n := 1 + (c * 31 + r * 17 + c * r) % 8
			draw_texture_rect(Props.texture("floor_%d" % n), Rect2(c * t, floor_y + r * t, t, t), false)
	draw_rect(Rect2(0, floor_y - 3, size.x, 4), Color(0, 0, 0, 0.45))
	# Puerta al centro, con marco.
	var cx := size.x * 0.5
	var leaf := Rect2(cx - t, floor_y - t * 2.0, t * 2.0, t * 2.0)
	draw_rect(leaf.grow(-4.0), Color("0b0a12"))  # oscuridad detrás de la puerta abierta
	draw_texture_rect(Props.texture("doors_leaf_open"), leaf, false)
	draw_texture_rect(Props.texture("doors_frame_left"), Rect2(leaf.position.x - t, leaf.position.y, t, t * 2.0), false)
	draw_texture_rect(Props.texture("doors_frame_right"), Rect2(leaf.end.x, leaf.position.y, t, t * 2.0), false)
	draw_texture_rect(Props.texture("doors_frame_top"), Rect2(leaf.position.x, leaf.position.y - t, t * 2.0, t), false)
	# Estandartes, palanca y cajas.
	for x in [size.x * 0.3, size.x * 0.7]:
		draw_texture_rect(Props.texture("wall_banner_green"), Rect2(x - t / 2.0, maxf(4.0, floor_y - t * 3.2), t, t), false)
	draw_texture_rect(Props.texture("lever_left"), Rect2(cx + t * 2.4, floor_y - t * 1.6, t, t), false)
	var crate := Props.texture("crate")
	for x in [size.x * 0.05, size.x * 0.11, size.x * 0.92]:
		draw_texture_rect(crate, Rect2(x - t / 2.0, floor_y - t * 1.5 + 6.0, t, t * 1.5), false)


## Estandartes chicos a mitad de camino entre cada antorcha y su columna.
func _draw_wall_banners(floor_y: float, half: float) -> void:
	var tex := Props.texture(BIOME_BANNER.get(_biome, "wall_banner_red"))
	var side := 16.0 * PROP_SCALE
	var gap := (size.x * 0.5 - half - 16.0 * PROP_SCALE) - size.x * 0.22
	if gap < side + 8.0:
		return  # escena angosta: no entran sin tapar la antorcha
	for dir in [-1.0, 1.0]:
		var x: float = size.x * 0.5 + dir * (half + 16.0 * PROP_SCALE + gap * 0.5)
		draw_texture_rect(tex, Rect2(x - side / 2.0, floor_y * 0.2, side, side), false, _wall_tint.lerp(Color.WHITE, 0.55))


## Columnas de piedra a los lados del arco, apoyadas en el piso y teñidas como la pared.
func _draw_columns(floor_y: float, arch_h: float, half: float) -> void:
	var tex := Props.texture("column")
	var w := 16.0 * PROP_SCALE * 0.75
	var h := minf(48.0 * PROP_SCALE * 0.75, arch_h * 0.95)
	for side in [-1.0, 1.0]:
		var x: float = size.x * 0.5 + side * (half + w * 0.5 + 6.0)
		draw_texture_rect(tex, Rect2(x - w / 2.0, floor_y - h + 4.0, w, h), false, _wall_tint.darkened(0.05))


## Santuario: dos fuentes animadas en la pared, a los lados del altar.
func _draw_fountains(floor_y: float, half: float) -> void:
	var color: String = BIOME_FOUNTAIN.get(_biome, "blue")
	var frame := int(_time * 6.0) % 3
	var mid := Props.frames("wall_fountain_mid_" + color, 3)[frame]
	var basin := Props.frames("wall_fountain_basin_" + color, 3)[frame]
	var top := Props.texture("wall_fountain_top_1")
	var side := 16.0 * PROP_SCALE
	var tint := _wall_tint.lerp(Color.WHITE, 0.5)
	for dir in [-1.0, 1.0]:
		var left: float = size.x * 0.5 + dir * (half + side * 0.5 + 6.0) - side / 2.0
		draw_texture_rect(top, Rect2(left, floor_y - side * 3.0, side, side), false, tint)
		draw_texture_rect(mid, Rect2(left, floor_y - side * 2.0, side, side), false, tint)
		draw_texture_rect(basin, Rect2(left, floor_y - side, side, side), false, tint)


func _draw_altar(floor_y: float) -> void:
	var x := size.x * 0.5
	draw_rect(Rect2(x - 34, floor_y - 26, 68, 26), Color("3d4556"))
	draw_rect(Rect2(x - 40, floor_y - 30, 80, 6), Color("5a6275"))
	draw_rect(Rect2(x - 34, floor_y - 26, 68, 26), Color("1b2033"), false, 2.0)


func _draw_arch(base: Vector2, half_width: float, height: float) -> void:
	if half_width < 4.0 or height < half_width * 2.0:
		return  # todavía sin tamaño: un polígono degenerado no se puede triangular
	var points := PackedVector2Array()
	var spring := base.y - height + half_width
	points.append(Vector2(base.x - half_width, base.y))
	for i in 17:
		var a := PI + PI * i / 16.0
		points.append(Vector2(base.x + cos(a) * half_width, spring + sin(a) * half_width))
	points.append(Vector2(base.x + half_width, base.y))
	var rim := PackedVector2Array()
	for p in points:
		rim.append(base + (p - base) * Vector2(1.18, 1.08))
	var rim_color := Color("2a3470")
	match _biome:
		&"crypt":
			rim_color = Color("23504d")
		&"forge":
			rim_color = Color("4a2a24")
	draw_colored_polygon(rim, rim_color)
	draw_colored_polygon(points, Color("05071a"))


# --- partículas -------------------------------------------------------------------

func _update_particles(delta: float) -> void:
	var floor_y := size.y * FLOOR_RATIO
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p.pos += p.vel * delta
		p.life -= delta * p.decay
		if p.life <= 0.0 or p.pos.y > size.y or p.pos.y < -10.0:
			_particles.remove_at(i)
	if _particles.size() >= MAX_PARTICLES or size.x < 8.0:
		return
	match _biome:
		&"crypt":
			if _rng.randf() < delta * 6.0:  # gotas que caen del techo
				_particles.append({"pos": Vector2(_rng.randf_range(0, size.x), 0.0), "vel": Vector2(0, _rng.randf_range(110, 170)), "life": 1.0, "decay": 0.0, "size": 2.0, "color": Color(0.6, 0.85, 1.0, 0.8)})
		&"forge":
			if _rng.randf() < delta * 14.0:  # brasas que suben
				_particles.append({"pos": Vector2(_rng.randf_range(0, size.x), floor_y + _rng.randf_range(0, size.y - floor_y)), "vel": Vector2(_rng.randf_range(-12, 12), -_rng.randf_range(25, 60)), "life": 1.0, "decay": _rng.randf_range(0.35, 0.7), "size": 2.0 + float(_rng.randi() % 2), "color": Color(1.0, 0.6, 0.2)})
		&"catacombs":
			if _rng.randf() < delta * 3.0:  # polvo flotando
				_particles.append({"pos": Vector2(_rng.randf_range(0, size.x), _rng.randf_range(0, floor_y)), "vel": Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-4, 4)), "life": 1.0, "decay": 0.3, "size": 2.0, "color": Color(0.8, 0.8, 0.95, 0.35)})


# --- composición ------------------------------------------------------------------

func _layout() -> void:
	queue_redraw()
	if size.x < 8.0:
		return
	var floor_y := size.y * FLOOR_RATIO
	var boss := _scene == &"boss"
	var xs := [size.x * (0.3 if boss else 0.22), size.x * (0.7 if boss else 0.78)]
	for i in _flames.size():
		_flames[i].position = Vector2(xs[i] - 12, floor_y * 0.38)
		_glows[i].position = Vector2(xs[i] - 110, floor_y * 0.38 - 95)
	_campfire.visible = _scene == &"camp"
	_campfire.position = Vector2(size.x * 0.5 - 27, floor_y - 30)
	_altar_flame.visible = _scene == &"shrine"
	_altar_flame.position = Vector2(size.x * 0.5 - 18, floor_y - 62)
	_arch_glow.visible = boss or _scene == &"shrine"
	var glow_color: Color = BOSS_GLOW.get(_biome, Color(0.6, 0.35, 1.0, 0.55)) if boss else Color(0.4, 0.75, 1.0, 0.45)
	_arch_glow.self_modulate = glow_color
	var side := size.x * (0.42 if boss else 0.3)
	_arch_glow.size = Vector2(side, side)
	_arch_glow.position = Vector2(size.x * 0.5 - side / 2.0, floor_y - side * 0.75)


func _apply_light() -> void:
	var g := _vignette_tex.gradient
	var inner := lerpf(0.05, 0.5, _light)
	g.offsets = PackedFloat32Array([0.0, inner, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.01, 0.04, lerpf(0.95, 0.6, _light))])


static func _pixel_rect(id: StringName, px: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = SpriteBank.texture(id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = px
	r.pivot_offset = Vector2(px.x / 2.0, px.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _radial(color: Color) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = Gradient.new()
	tex.gradient.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	return tex


static var _cobble: Texture2D
static var _walls := {}


static func _cobble_texture() -> Texture2D:
	if _cobble:
		return _cobble
	var img := Image.create_empty(24, 12, false, Image.FORMAT_RGBA8)
	# Gris neutro: se tiñe con el color de piso de cada bioma al dibujarlo.
	img.fill(Color("3a3a3a"))
	for r in [Rect2i(1, 1, 9, 4), Rect2i(12, 1, 11, 4), Rect2i(0, 7, 5, 4), Rect2i(7, 7, 10, 4), Rect2i(19, 7, 5, 4)]:
		img.fill_rect(r, Color("6a6a6a") if r.position.x % 2 == 1 else Color("5a5a5a"))
	img.resize(48, 24, Image.INTERPOLATE_NEAREST)
	_cobble = ImageTexture.create_from_image(img)
	return _cobble


## Textura de pared de cada bioma (se tiñe con wall_tint al dibujarla).
static func _wall_texture(biome: StringName) -> Texture2D:
	if _walls.has(biome):
		return _walls[biome]
	var tex: Texture2D
	match biome:
		&"crypt":
			# Bloques grandes de piedra con musgo en las juntas.
			var img := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color("1e2a3a"))
			var mortar := Color("0b1018")
			for x in 32:
				img.set_pixel(x, 0, mortar)
				img.set_pixel(x, 8, mortar)
				img.set_pixel(x, 1, Color("2b3a4e"))
				img.set_pixel(x, 9, Color("2b3a4e"))
			for y in 8:
				img.set_pixel(0, y, mortar)
				img.set_pixel(20, y + 8, mortar)
			for p in [Vector2i(3, 7), Vector2i(4, 7), Vector2i(12, 7), Vector2i(25, 15), Vector2i(26, 15), Vector2i(9, 15)]:
				img.set_pixel(p.x, p.y, Color("3f7a52"))
			tex = ImageTexture.create_from_image(img)
		&"forge":
			# Ladrillo oscuro con juntas que brillan como brasas.
			var img := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color("3a1d18"))
			var mortar := Color("140806")
			for x in 32:
				img.set_pixel(x, 0, mortar)
				img.set_pixel(x, 8, mortar)
				if x % 16 != 0:
					img.set_pixel(x, 1, Color("552a22"))
					img.set_pixel(x, 9, Color("552a22"))
			for y in 8:
				img.set_pixel(0, y, mortar)
				img.set_pixel(16, y + 8, mortar)
			for p in [Vector2i(5, 0), Vector2i(6, 0), Vector2i(22, 8), Vector2i(23, 8), Vector2i(0, 4), Vector2i(16, 12)]:
				img.set_pixel(p.x, p.y, Color("c2541c"))
			tex = ImageTexture.create_from_image(img)
		_:
			tex = SpriteBank.brick_texture()
	_walls[biome] = tex
	return tex
