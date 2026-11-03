class_name SpriteBank
extends RefCounted
## Pixel art generado desde mapas de caracteres: sin archivos de imagen ni licencias de terceros.
## Cada carácter es un color de la paleta; "." es transparente. Las texturas se cachean.

const PALETTE := {
	"k": Color("12121c"), "w": Color("ecebf3"), "s": Color("aab5cc"), "S": Color("6b7792"),
	"g": Color("f2c14e"), "G": Color("b8862b"), "r": Color("c8423b"), "R": Color("7d2622"),
	"b": Color("3f6fd1"), "B": Color("23408a"), "n": Color("7a4a2a"), "N": Color("4d2e1a"),
	"f": Color("e9b48a"), "h": Color("3d4556"), "H": Color("262b38"), "p": Color("8c4fd0"),
	"c": Color("5fd6e8"), "e": Color("5fbf4a"), "E": Color("2f7a2a"), "y": Color("e6dcc0"),
	"Y": Color("a89c7c"), "o": Color("f08a24"),
	"t": Color("3fa8a0"), "T": Color("1f5f63"), "a": Color("8a8f99"), "A": Color("4f5560"),
	"l": Color("d6f0ff"),
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
	&"door": ["..kkkkkk..", ".knnnnnnk.", "knNnnnnNnk", "knNnnnnNnk", "knNnnnnNnk", "knNnngnNnk", "knNnnnnNnk", "knNnnnnNnk", "knNnnnnNnk", "kkkkkkkkkk"],
}

## Icono de cada tipo de puerta en el mapa.
const DOOR_ICONS := {&"combat": &"weapon", &"elite": &"skull", &"event": &"chest", &"camp": &"fire", &"boss": &"lich"}

static var _cache := {}


static func has_sprite(id: StringName) -> bool:
	return SPRITES.has(id)


## Versión ampliada sin suavizado, para iconos de botones (que no escalan su textura).
static func icon(id: StringName, factor: int = 2) -> Texture2D:
	var key := StringName("%s@%d" % [id, factor])
	if _cache.has(key):
		return _cache[key]
	var image := texture(id).get_image()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var rows: Array = SPRITES.get(id, SPRITES[&"skull"])
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
	var tex := ImageTexture.create_from_image(image)
	_cache[id] = tex
	return tex


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
