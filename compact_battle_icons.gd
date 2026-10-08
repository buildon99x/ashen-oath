extends RefCounted
## Code-native, font-independent symbols. One stroke language at every HUD size.
static var _textures: Dictionary = {}
const PATHS: Dictionary = {
	"hp": '<path d="M12 20 3 11C-2 3 8-1 12 6 16-1 26 3 21 11Z"/>',
	"focus": '<path d="m12 2 8 10-8 10-8-10Z"/><path d="M12 6v12"/>',
	"shield": '<path d="m12 2 8 3v7c0 5-8 10-8 10S4 17 4 12V5Z"/>',
	"damage": '<path d="m7 17 12-14 2 6L10 20M4 14l7 7M7 18l-4 4"/>',
	"slash": '<path d="m4 20 16-16c0 8-5 12-12 14M3 15l6 6"/>',
	"blunt": '<path d="m3 7 5-5 10 10-5 5ZM11 14l-7 7"/>',
	"pierce": '<path d="M3 21 18 6m-8-1 11-2-2 11M3 15l6 6"/>',
	"arcane": '<path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5Z"/>',
	"guard": '<path d="m12 2 8 3v7c0 5-8 10-8 10S4 17 4 12V5Z"/><path d="m7 11 4 4 6-7"/>',
	"target": '<circle cx="12" cy="12" r="7"/><path d="M12 0v7m0 10v7M0 12h7m10 0h7"/>',
	"break": '<path d="M10 2 4 5v7c0 5 5 8 5 8l4-7-5-2 6-8m3 2 3 1v7c0 5-7 9-7 9"/>',
	"sever": '<path d="m4 21 6-7m-7 0 7 7m3-13 6-6 2 6-5 5M4 6l5 3m7 8 5 3"/>',
	"ready": '<circle cx="12" cy="12" r="8"/><path d="m10 7 6 5-6 5Z"/>',
	"acted": '<path d="m4 12 5 6L21 5"/>',
	"fallen": '<path d="m5 5 14 14M5 19 19 5"/>',
	"next": '<path d="M3 12h17m-7-7 7 7-7 7"/>',
	"danger": '<path d="m12 2 10 19H2Z"/><path d="M12 8v6m0 3v1"/>',
	"source": '<path d="m3 4 5 4 4-5 4 5 5-4-3 15H6Z"/>',
	"info": '<circle cx="12" cy="12" r="9"/><path d="M12 10v8m0-12v1"/>',
}

static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="-1 -1 26 26"><g fill="none" stroke="white" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % PATHS.get(kind, PATHS.info)
		var image: Image = Image.new()
		if image.load_svg_from_string(svg) != OK: return null
		_textures[kind] = ImageTexture.create_from_image(image)
	return _textures[kind]
