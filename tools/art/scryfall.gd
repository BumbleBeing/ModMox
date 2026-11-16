class_name Scryfall
extends Node
## A developer tool's way to ask Scryfall for cards and their art. It makes one request at a
## time, pausing before each, and waits and retries when Scryfall says to slow down. A tool
## adds one to its tree before asking.

const API: String = "https://api.scryfall.com"
## Scryfall asks for a User-Agent and Accept header, and about 10 requests a second at most.
const HEADERS: PackedStringArray = ["User-Agent: ModMoxArtFetcher/1.0", "Accept: application/json;q=0.9,*/*;q=0.8"]
const PAUSE_SECONDS: float = 0.5

var _http: HTTPRequest


func _init() -> void:
	_http = HTTPRequest.new()
	add_child(_http)


## The card object named exactly [param card_name], or an empty Dictionary when Scryfall
## has none.
func card_named(card_name: String) -> Dictionary:
	var card: Variant = await json_at(API + "/cards/named?exact=" + card_name.uri_encode())
	# Variant: parsed JSON is open-ended until checked.
	if not card is Dictionary or not (card as Dictionary).has("prints_search_uri"):
		return {}
	return card


## Every printing of [param card], a card object, oldest first; empty if none came back.
func printings_of(card: Dictionary) -> Array:
	var printings: Variant = await json_at(str(card["prints_search_uri"]) + "&dir=asc")
	if not printings is Dictionary:
		return []
	return (printings as Dictionary).get("data", []) as Array


## The parsed JSON at [param url], or null.
func json_at(url: String) -> Variant:
	var body: PackedByteArray = await bytes_at(url)
	return JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null


## The body at [param url], or nothing if it could not be had.
func bytes_at(url: String) -> PackedByteArray:
	for attempt: int in 6:
		await get_tree().create_timer(PAUSE_SECONDS).timeout
		if _http.request(url, HEADERS) != OK:
			return PackedByteArray()
		var result: Array = await _http.request_completed
		var code: int = result[1]
		if code == 200:
			return result[3]
		if code != 429:
			return PackedByteArray()
		await get_tree().create_timer(30.0 * (attempt + 1)).timeout
	return PackedByteArray()
