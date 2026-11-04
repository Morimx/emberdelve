class_name Props
extends RefCounted
## Sprites de decorado del pack 16x16 DungeonTileset II de 0x72 (CC0, ver LICENSES.md),
## en assets/props/. Se usan solo para algunos detalles: estandartes, columnas, fuentes,
## el cofre y los pinchos. Los personajes y la interfaz siguen siendo de SpriteBank.

const DIR := "res://assets/props/"

static var _cache := {}


static func texture(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load(DIR + name + ".png")
	return _cache[name]


## Cuadros de una animación: <name>_anim_f0..f(count-1).
static func frames(name: String, count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in count:
		out.append(texture("%s_anim_f%d" % [name, i]))
	return out


## Copia ampliada sin suavizado (para mosaicos y botones, que no escalan la textura).
static func scaled(name: String, factor: int) -> Texture2D:
	var key := "%s@%d" % [name, factor]
	if not _cache.has(key):
		var image := texture(name).get_image()
		image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]
