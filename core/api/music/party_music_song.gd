## Shared song resource. Loading one chosen song loads its music and bound chart resources.
class_name PartyMusicSong
extends Resource
@export var music: AudioStream
@export var charts: Array[PartyMusicChart] = []
