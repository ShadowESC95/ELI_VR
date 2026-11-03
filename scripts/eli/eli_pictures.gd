class_name EliPictures
extends RefCounted

# Pictures ELI took or looked at for you, fetched from ELI v3 (GET /v1/world/picture/<row>) once
# each and kept while ELI VR runs. A thing showing one asks for it by the path the world feed gave;
# whoever fetches, a picture arrives once and every thing showing it gets the same texture.

static var link: Node                   # the EliLink, set when the app makes it
static var _textures := {}              # path -> ImageTexture
static var _waiting := {}               # path -> [Callable], while it is being fetched

## Calls `done` with the picture's texture, now if it is here, else once it has arrived.
static func want(path: String, done: Callable) -> void:
    if _textures.has(path):
        done.call(_textures[path])
        return
    if _waiting.has(path):
        _waiting[path].append(done)
        return
    if link == null or not link.can("pictures") or not path.begins_with("/v1/world/picture/"):
        return
    _waiting[path] = [done]
    _fetch(path)

static func _fetch(path: String) -> void:
    var got = await link.fetch(path)
    var callers: Array = _waiting.get(path, [])
    _waiting.erase(path)
    if not got.ok:
        return
    var image := Image.new()
    var bytes: PackedByteArray = got.payload
    var read := ERR_INVALID_DATA
    if bytes.slice(0, 4) == PackedByteArray([0x89, 0x50, 0x4E, 0x47]):
        read = image.load_png_from_buffer(bytes)
    elif bytes.slice(0, 3) == PackedByteArray([0xFF, 0xD8, 0xFF]):
        read = image.load_jpg_from_buffer(bytes)
    elif bytes.slice(0, 4) == PackedByteArray([0x52, 0x49, 0x46, 0x46]):
        read = image.load_webp_from_buffer(bytes)
    if read != OK:
        return
    image.generate_mipmaps()
    var texture := ImageTexture.create_from_image(image)
    _textures[path] = texture
    for done in callers:
        if done.is_valid():
            done.call(texture)
