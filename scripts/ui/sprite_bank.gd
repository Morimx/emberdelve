class_name SpriteBank
extends RefCounted
## Pixel art generado desde mapas de caracteres: sin archivos de imagen ni licencias de terceros.
## Cada carácter es un color de la paleta; "." es transparente. Las texturas se cachean.
## Los mapas se dibujan a resolución base y se refinan al doble (Scale2x, contorno fino y
## sombreado con luz desde arriba a la izquierda), así todo comparte la misma densidad.

const PALETTE := {
	"k": Color("12121c"), "w": Color("ecebf3"), "s": Color("aab5cc"), "S": Color("6b7792"),
	"g": Color("f2c14e"), "G": Color("b8862b"), "r": Color("c8423b"), "R": Color("7d2622"),
	"b": Color("3f6fd1"), "B": Color("23408a"), "n": Color("7a4a2a"), "N": Color("4d2e1a"),
	"f": Color("e9b48a"), "h": Color("3d4556"), "H": Color("262b38"), "p": Color("8c4fd0"),
	"c": Color("5fd6e8"), "e": Color("5fbf4a"), "E": Color("2f7a2a"), "y": Color("e6dcc0"),
	"Y": Color("a89c7c"), "o": Color("f08a24"),
	"t": Color("3fa8a0"), "T": Color("1f5f63"), "a": Color("8a8f99"), "A": Color("4f5560"),
	"l": Color("d6f0ff"),
	"P": Color("5a2f8f"), "q": Color("c9a0ff"), "F": Color("c08560"),
}

const SPRITES := {
	&"warrior": ["........rrr.....", ".......rrr......", "......kkkkk.....", ".....ksssssk....", ".....kskkksk....", ".....ksssssk....", "......kgggk.....", "w...kssssssk....", "sw.kSssgssSkbb..", ".sw.kssgsskbgbb.", "..gkkSsssSkbggb.", "...G.krrrrk.bbb.", ".....kSkkSk..b..", ".....ks..sk.....", ".....ks..sk.....", "....kkk..kkk...."],
	&"cleric": ["..g.............", ".ggg..kkkk......", "..g..kwwwwk.....", "..n.kwffffwk....", "..n.kwfkfkwk....", "..n.kwffffwk....", "..n..kwwwwk.....", "..nkkwwwwwwk....", "..fwwwwggwwwk...", "..n.kwwggwwwk...", "..n.kwwwwwwwk...", "..n.kgwwwwwgk...", "..n.kwwwwwwwk...", "..n.kwwwwwwwk...", "..n.kgggggggk...", "....kkk..kkk...."],
	&"assassin": ["................", "......kkkk......", ".....khhhhk.....", "....khhhhhhk....", "....khfkfkhk....", "....khrrrrhk....", "....kHrrrrHk....", "...kHhhhhhhHk...", "s.kfhhnnnhhhfk.s", ".s.khhhnhhhhk.s.", "..fkkHhhhhHkkf..", "....knnnnnnk....", "....kHH.kHHk....", "....kHH..HHk....", "....knn..nnk....", "...kkkk..kkkk..."],
	&"skeleton": ["................", ".....kkkkk......", "....kyyyyyk.....", "....kkykkyk.....", "....kyyyyyk.....", ".....kykyk......", "......kyk.......", "....kyyyyyk.....", "...kykyyykyk....", "...ky.kyk.yk....", "..Y..kyyyk..Y...", "......kyk.......", ".....kyky.......", ".....ky.yk......", ".....ky..yk.....", "....kkk..kkk...."],
	&"bat": ["................", "................", "................", "................", "pk..........kp..", "ppk...kk...kpp..", "pppk.kppk.kppp..", "ppppkpwpwkpppp..", ".pppkppppkppp...", "..ppkkrrkkpp....", "...p..kk..p.....", "................", "................", "................", "................", "................"],
	&"slime": ["................", "................", "................", "................", "................", "......kkkk......", "....kkeeeekk....", "...keeeeeeeek...", "..keewkeewkeek..", "..keekkeekkeek..", "..keeeeeeeeeek..", "..kEeeeeeeeeEk..", "...kEEEEEEEEk...", "....kkkkkkkk....", "................", "................"],
	&"lich": ["....g.g.g.......", "....ggggg.......", "...kyyyyyk......", "...kckykck......", "...kyyyyyk......", "....kykyk.......", "..kpppppppk...c.", ".kppppkppppk.ccc", "kpppyypppppkk.n.", "kpp.yy.ppppk..n.", ".kppppppppk...n.", ".kpppgppppk...n.", ".kppppppppk...n.", "kpppppppppk..n..", "kppppppppppkn...", "kkkkkkkkkkkk...."],
	&"ghoul": ["................", ".....kkkk.......", "....kEeeEk......", "....kekkek......", "....keeeek......", ".....kEEk.......", "...kkhhhhkk.....", "..kehhhhhhek....", ".ke.khhhhk.ek...", "ke..khhhhk..ek..", "....kHhhHk......", "....kh..hk......", "....kh..hk......", "...kEk..kEk.....", "..kkk....kkk....", "................"],
	&"drowned": ["................", "....kkkkk.......", "...kTTTTTk......", "...ktktktk......", "...kTTTTTk......", "....kTkTk.......", "..kkbbbbbkk.....", ".kTbbBbbbbTk....", "kT.kbbBbbk.Tk...", "T..kbbbbbk..T...", "...kBBBBBk......", "...kb...bk......", "...kb...bk......", "...kT...Tk......", "..kkk...kkk.....", "................"],
	&"serpent": ["................", "................", "................", "..........kkk...", ".........ktttkk..", "........ktwtktk.", "...kkk..ktttk...", "..ktttk.ktttk...", ".ktTTttktk......", ".ktT.kttk.......", "..kk..kk........", "................", "................", "................", "................", "................"],
	&"crab": ["................", "................", "................", "................", ".kk..........kk.", "krrk........krrk", ".krk..kkkk..krk.", "..kk.krrrrk.kk..", "...kkrwrrwrkk...", "..krrrrrrrrrrk..", ".krRrrrrrrrrRrk.", "..kRRRRRRRRRRk..", "..k.k.k..k.k.k..", "................", "................", "................"],
	&"wisp": ["................", "................", "......kkkk......", ".....kcccck.....", "....kcllllck....", "....kclkklck....", "....kcllllck....", "....kcllllck....", ".....kcccck.....", "......kcck......", ".......kck......", "......kc.k......", ".......k........", "................", "................", "................"],
	&"tide_wraith": ["....kkkkkkk.....", "...kTTTTTTTk....", "..kTllTTTllTk...", "..kTlkTTTklTk...", "..kTTTTTTTTTk...", "..kTTkkkkkTTk...", ".kTTTTTTTTTTTk..", "kTtTTTTTTTTTtTk.", "kTt.kTTTTTk.tTk.", ".kk.kTTTTTk.kk..", "....kTTtTTk.....", "....kTtTTtTk....", "...kTTTtTTTk....", "..kTtTTTTTtTk...", "..kk.kk.kk.kk...", "................"],
	&"imp": ["................", "...k......k.....", "...rk....kr.....", "...krkkkkrk.....", "....krrrrk......", "....krykyk......", "....krrrrk......", ".....kRRk.......", "...kkrrrrkk.....", "..krkrrrrkrk....", "..k.krrrrk.k....", "....kRRRRk...o..", "....kr..rk..oo..", "....kr..rkkk....", "...kkk..kkk.....", "................"],
	&"golem": ["................", ".....kkkkkk.....", "....kaaaaaak....", "....kaokkoak....", "....kaaaaaak....", "..kkkAaaaaAkkk..", ".kaaakaaaakaaak.", ".kaaakaooakaaak.", ".kaAAkaaaakAAak.", "..kkkkaaaakkkk..", ".....kAaaAk.....", "....kaak.kaak...", "....kaak.kaak...", "...kAAAk.kAAAk..", "...kkkkk.kkkkk..", "................"],
	&"magma": ["................", "................", "................", "................", "................", "......kkkk......", "....kkooook.....", "...kooyyoook....", "..kooykooykok...", "..kookkookkok...", "..koooooooook...", "..krooooooork...", "...krrrrrrrk....", "....kkkkkkkk....", "................", "................"],
	&"cultist": ["................", "......kkkk......", ".....kRRRRk.....", "....kRRRRRRk....", "....kRkyykRk....", "....kRyyyyRk....", "....kRRRRRRk....", "...kRRRRRRRRk...", "..kRRrRRRRrRRk..", "..kfkRRRRRRkfk..", "....kRRRRRRk....", "....kRRrrRRk....", "...kRRRRRRRRk...", "...kRRRRRRRRk...", "...kkkkkkkkkk...", "................"],
	&"iron_colossus": ["....kkkkkkkk....", "...kSSSSSSSSk...", "...kSokSSkoSk...", "...kSSSSSSSSk...", ".kkkkSSSSSSkkkk.", "kSSSkSSSSSSkSSSk", "kSssksSooSskssSk", "kSssksSooSskssSk", "kSSSkSSSSSSkSSSk", ".kkkkSSSSSSkkkk.", "....kSSkkSSk....", "...kSSk..kSSk...", "...kSSk..kSSk...", "..kSSSk..kSSSk..", "..kkkkk..kkkkk..", "................"],
	&"chest_open": ["..kkkkkkkk..", ".knnnnnnnnk.", ".kNNNNNNNNk.", "kssssssssssk", "k.gggggggg.k", "kggyggyggggk", "knnnnggnnnnk", "knnnnkknnnnk", "knnnnnnnnnnk", "kNNNNNNNNNNk", "kssssssssssk", ".kkkkkkkkkk."],
	&"spikes": ["................", "..k.....k.....k.", ".ksk...ksk...ksk", ".ksk...ksk...ksk", "kssSk.kssSk.kssS", "kssSk.kssSk.kssS", "kSSSSkSSSSSkSSSS", "kkkkkkkkkkkkkkkk"],
	&"keeper": ["................", "......kkkk......", ".....knnnnk.....", "....knnnnnnk....", "....knfkfknk....", "....knffffnk....", "....kwwwwwwk....", "...knwwwwwwnk...", "..knnnnnnnnnnk..", "..kfknnnnnnkoo..", "....knnnnnnkoyo.", "....knnnnnnk.o..", "....kNNNNNNk....", "....kNNNNNNk....", "....knnkknnk....", "...kkkk..kkkk..."],
	&"spirit": ["................", ".....kkkkk......", "....kcllllk.....", "...kclklkllk....", "...kclllllck....", "...kcllcllck....", "...kclllllck....", "....kcllllck....", "....kcclllck....", ".....kccllk.....", ".....kcllck.....", "......kclk......", ".......kck......", "........k.......", "................", "................"],
	&"weapon": ["..........ww", ".........wsw", "........wsw.", ".......wsw..", "......wsw...", "..g..wsw....", "..ggwsw.....", "...gGw......", "..nkgg......", ".nk..g......", "nn..........", "n..........."],
	&"armor": ["............", ".kkk....kkk.", "kSssk..kssSk", "kSsssggsssSk", ".kssssssssk.", ".kssgssgssk.", ".kssssssssk.", ".kSssggssSk.", "..kssssssk..", "..kSSSSSSk..", "...kkkkkk...", "............"],
	&"charm": ["..k......k..", "...k....k...", "....k..k....", ".....kk.....", "....kggk....", "...kgrrgk...", "...kgrRgk...", "....kggk....", ".....kk.....", "............"],
	&"axe": ["............", "...kkkk.....", "..ksssSk....", ".ksssssSk...", ".ksssSknnk..", "..kSSk.nnk..", "...kk..knnk.", "........knnk", ".........knk", "..........k.", "............", "............"],
	&"mace": ["........kk..", ".......ksSk.", "......ksgsSk", ".......kSSk.", "......knnk..", ".....knnk...", "....knnk....", "...knnk.....", "..kggk......", "..kGk.......", "...k........", "............"],
	&"mail": ["............", ".kkk....kkk.", "kSaak..kaaSk", "kSaaaaaaaaSk", ".kaAaAaAaak.", ".kaaAaAaAak.", ".kaAaAaAaak.", ".kaaAaAaAak.", "..kaAaAaAk..", "..kSSSSSSk..", "...kkkkkk...", "............"],
	&"staff": ["....kkk.....", "...kcclk....", "...kclck....", "....kck.....", "....knk.....", "....knk.....", "....knk.....", "....knk.....", "....knk.....", "....kNk.....", "....kNk.....", ".....k......"],
	&"scepter": [".....kk.....", "....kgwk....", "...kgrrgk...", "....kggk....", ".....gk.....", ".....kgk....", ".....kGk....", ".....kgk....", ".....kGk....", ".....kgk....", "....kGGGk...", ".....kkk...."],
	&"robe": ["....kkkk....", "...kwwwwk...", "..kwwggwwk..", ".kwwwggwwwk.", ".kfkwggwkfk.", "..kwwggwwk..", "..kwwggwwk..", "..kwwwwwwk..", ".kwwwwwwwwk.", ".kwwwwwwwwk.", ".kggggggggk.", "..kkkkkkkk.."],
	&"vestments": ["....kkkk....", "...kbbbbk...", "..kbbggbbk..", ".kbbbggbbbk.", ".kfkbggbkfk.", "..kbbggbbk..", "..kbwggwbk..", "..kbbggbbk..", ".kbbbggbbbk.", ".kbBBggBBbk.", ".kggggggggk.", "..kkkkkkkk.."],
	&"dagger": ["............", "..........k.", ".........ksk", "........kswk", ".......kswk.", "......kswk..", "..k..kswk...", "..kgkswk....", "...kgGk.....", "..knkgk.....", ".knk..k.....", "..k........."],
	&"twin_daggers": ["k..........k", "ksk......ksk", ".ksk....ksk.", "..ksk..ksk..", "...kskksk...", "....kssk....", "...kgkkgk...", "..kgk..kgk..", ".knk....knk.", "knk......knk", ".k........k.", "............"],
	&"crossbow": ["............", ".kk......kk.", "knnk....knnk", ".kNnk..knNk.", "..kNnkknNk..", "...kkssSkk..", "....ksSk....", "....knnk....", "....knnk....", "....knNk....", "....kNNk....", ".....kk....."],
	&"leather": ["............", ".kkk....kkk.", "knnnk..knnnk", "knnnnNNnnnnk", ".knnnNNnnnk.", ".knnkgkknnk.", ".knnnNNnnnk.", ".knnnNNnnnk.", "..knnnnnnk..", "..kNNNNNNk..", "...kkkkkk...", "............"],
	&"cloak": ["....kkkk....", "...khhhhk...", "..khhHHhhk..", "..khHkkHhk..", ".khhhkkhhhk.", ".khhhhhhhhk.", ".khhhhhhhhk.", "khhhhhhhhhhk", "khhhhhhhhhhk", "khHhhhhhhHhk", "kHHhHHHHhHHk", "kkkkkkkkkkkk"],
	&"ring": ["............", "....kkk.....", "...kcwck....", "....kck.....", "...kgggk....", "..kgk.kgk...", "..kg...gk...", "..kg...gk...", "..kgk.kgk...", "...kGGGk....", "....kkk.....", "............"],
	&"talisman": ["....k..k....", "....k..k....", ".....kk.....", "....kppk....", "...kpwppk...", "..kppppppk..", "..kpppcppk..", "..kppcccpk..", "...kppcpk...", "....kppk....", ".....kk.....", "............"],
	&"relic": ["............", "....kkkk....", "...kyyyyk...", "..kyykkyyk..", "..kykyykyk..", "..kyyyyyyk..", "...kykkyk...", "...kyyyyk...", "..kgggggggk.", "..kGgggggGk.", "..kkkkkkkkk.", "............"],
	&"sword": ["..........ww", ".........wsw", "........wsw.", ".......wsw..", "......wsw...", "..g..wsw....", "..ggwsw.....", "...gGw......", "..nkgg......", ".nk..g......", "nn..........", "n..........."],
	&"plate": ["............", ".kkk....kkk.", "kSssk..kssSk", "kSsssggsssSk", ".kssssssssk.", ".kssgssgssk.", ".kssssssssk.", ".kSssggssSk.", "..kssssssk..", "..kSSSSSSk..", "...kkkkkk...", "............"],
	&"amulet": ["..k......k..", "...k....k...", "....k..k....", ".....kk.....", "....kggk....", "...kgrrgk...", "...kgrRgk...", "....kggk....", ".....kk.....", "............"],
	&"torch": ["...o....", "..oyo...", "..oyyo..", ".ooggoo.", "..oggo..", "...nn...", "...nn...", "...nn...", "...NN...", "...NN..."],
	&"coin": ["..kkkk..", ".kggggk.", "kgwgggGk", "kggggGGk", "kgggGGGk", ".kGGGGk.", "..kkkk.."],
	&"gem": ["...k....", "..kck...", ".kcwck..", ".kccck..", ".kcBck..", "..kck...", "...k...."],
	&"fire": ["....o....", "...oo....", "..ooyo...", "..oyyoo..", ".ooyyyo..", ".oyywyo..", "..oyyo...", ".nNnnNn..", "nNnnnnNn."],
	&"skull": ["..kkkkk..", ".kyyyyyk.", "kyyyyyyyk", "kykkykkyk", "kykkykkyk", "kyyykyyyk", ".kyyyyyk.", "..kykyk..", "..kkkkk.."],
	&"chest": ["............", "..kkkkkkkk..", ".knnnnnnnnk.", ".kNNNNNNNNk.", "kssssssssssk", "knnnnggnnnnk", "knnnnkknnnnk", "knnnnnnnnnnk", "kNNNNNNNNNNk", "kssssssssssk", ".kkkkkkkkkk."],
	&"shield": ["kkkkkkkkk", "kbbbgbbbk", "kbbbgbbbk", "kgggggggk", "kbbbgbbbk", ".kbbgbbk.", "..kbgbk..", "...kgk...", "....k...."],
	&"cross": ["...kkk...", "...kwk...", "...kwk...", "kkkkwkkkk", "kwwwwwwwk", "kkkkwkkkk", "...kwk...", "...kwk...", "...kkk..."],
	&"target": ["kkkkkkkkkkk", "kgggggggggk", ".kgggggggk.", "..kgggggk..", "...kgggk...", "....kgk....", ".....k....."],
	&"door": ["..kkkkkk..", ".knnnnnnk.", "knNnnnnNnk", "knNnnnnNnk", "knNnnnnNnk", "knNnngnNnk", "knNnnnnNnk", "knNnnnnNnk", "knNnnnnNnk", "kkkkkkkkkk"],
}

## Icono de cada tipo de puerta en el mapa.
const DOOR_ICONS := {&"combat": &"weapon", &"elite": &"skull", &"event": &"chest", &"camp": &"fire", &"boss": &"lich"}

## Factor de refinado: cada píxel del mapa pasa a ser 2x2 en la textura.
const DETAIL := 2
const OUTLINE := Color("12121c")
const HIGHLIGHT := 0.22
const SHADE := 0.28

static var _cache := {}


static func has_sprite(id: StringName) -> bool:
	return SPRITES.has(id) or SpriteHD.SPRITES.has(id)


## Versión ampliada sin suavizado, para iconos de botones (que no escalan su textura).
## factor se mide sobre el mapa base: factor 2 = el doble del mapa (la textura refinada).
static func icon(id: StringName, factor: int = 2) -> Texture2D:
	var key := StringName("%s@%d" % [id, factor])
	if _cache.has(key):
		return _cache[key]
	var image := texture(id).get_image()
	var base := image.get_size() / DETAIL
	image.resize(base.x * factor, base.y * factor, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var hd: bool = SpriteHD.SPRITES.has(id)
	var rows: Array = SpriteHD.SPRITES[id] if hd else SPRITES.get(id, SPRITES[&"skull"])
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			if PALETTE.has(key):
				image.set_pixel(x, y, PALETTE[key])
	# Los sprites HD ya están a la resolución refinada: solo se sombrean.
	if hd:
		_shade(image)
	var tex := ImageTexture.create_from_image(image if hd else refine(image))
	_cache[id] = tex
	return tex


## Duplica la resolución suavizando diagonales, adelgaza el contorno exterior y sombrea.
static func refine(src: Image) -> Image:
	var image := _scale2x(src)
	_thin_outline(image)
	_shade(image)
	return image


static func _px(img: Image, x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)


## EPX/Scale2x: cada píxel se vuelve 2x2 y toma el color de los vecinos en las diagonales.
static func _scale2x(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create_empty(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := _px(src, x, y)
			var a := _px(src, x, y - 1)
			var b := _px(src, x + 1, y)
			var c := _px(src, x - 1, y)
			var d := _px(src, x, y + 1)
			var e1 := p
			var e2 := p
			var e3 := p
			var e4 := p
			if c == a and c != d and a != b:
				e1 = a
			if a == b and a != c and b != d:
				e2 = b
			if d == c and d != b and c != a:
				e3 = c
			if b == d and b != a and d != c:
				e4 = d
			out.set_pixel(x * 2, y * 2, e1)
			out.set_pixel(x * 2 + 1, y * 2, e2)
			out.set_pixel(x * 2, y * 2 + 1, e3)
			out.set_pixel(x * 2 + 1, y * 2 + 1, e4)
	return out


static func _is_clear(img: Image, x: int, y: int) -> bool:
	return _px(img, x, y).a < 0.5


static func _is_outline(img: Image, x: int, y: int) -> bool:
	return _px(img, x, y).is_equal_approx(OUTLINE)


## El contorno exterior queda de 2 píxeles al duplicar: la capa interior toma el color
## del relleno vecino. Las líneas internas (ojos, costuras) no tocan el borde y se conservan.
static func _thin_outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var changes := {}
	for y in h:
		for x in w:
			if not _is_outline(img, x, y):
				continue
			var touches_clear := false
			var touches_rim := false
			var fill := Color(0, 0, 0, 0)
			for o: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var nx := x + o.x
				var ny := y + o.y
				if _is_clear(img, nx, ny):
					touches_clear = true
				elif _is_outline(img, nx, ny):
					if _rim(img, nx, ny):
						touches_rim = true
				elif fill.a == 0.0:
					fill = _px(img, nx, ny)
			if not touches_clear and touches_rim and fill.a > 0.0:
				changes[Vector2i(x, y)] = fill
	for pos: Vector2i in changes:
		img.set_pixelv(pos, changes[pos])


static func _rim(img: Image, x: int, y: int) -> bool:
	return _is_clear(img, x, y - 1) or _is_clear(img, x + 1, y) or _is_clear(img, x, y + 1) or _is_clear(img, x - 1, y)


## Luz desde arriba a la izquierda: borde superior/izquierdo más claro, inferior/derecho
## más oscuro, y un leve oscurecido hacia los pies.
static func _shade(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			var p := src.get_pixel(x, y)
			if p.a < 0.5 or p.is_equal_approx(OUTLINE):
				continue
			var lit := _edge(src, x, y - 1, p) or _edge(src, x - 1, y, p)
			var dark := _edge(src, x, y + 1, p) or _edge(src, x + 1, y, p)
			var c := p
			if lit and not dark:
				c = p.lightened(HIGHLIGHT)
			elif dark and not lit:
				c = p.darkened(SHADE)
			c = c.darkened(0.12 * float(y) / h)
			img.set_pixel(x, y, c)


## El vecino es borde de la forma o de otra región de color (no la misma superficie).
static func _edge(img: Image, x: int, y: int, _base: Color) -> bool:
	var n := _px(img, x, y)
	return n.a < 0.5 or n.is_equal_approx(OUTLINE)


## Ladrillo de mazmorra para el fondo de la arena (se repite como mosaico).
static func brick_texture() -> Texture2D:
	if _cache.has(&"_brick"):
		return _cache[&"_brick"]
	var image := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("1b2252"))
	var mortar := Color("0c1030")
	var light := Color("283273")
	for x in 32:
		image.set_pixel(x, 0, mortar)
		image.set_pixel(x, 8, mortar)
		if x % 16 != 0:
			image.set_pixel(x, 1, light)
			image.set_pixel(x, 9, light)
	for y in 8:
		image.set_pixel(0, y, mortar)
		image.set_pixel(16, y + 8, mortar)
	var tex := ImageTexture.create_from_image(image)
	_cache[&"_brick"] = tex
	return tex
