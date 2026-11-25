extends RefCounted

static func party_definition() -> Dictionary:
	return {"dependencies": {}}

func check_request(request: Dictionary) -> Dictionary:
	if request.mode != "standard":
		return {"ok": false, "code": "unsupported_mode", "message": "仅支持标准回合"}
	return {"ok": true}

func make_config(request: Dictionary) -> Dictionary:
	return request.duplicate(true)

func map_result(result: Dictionary, _request: Dictionary) -> Dictionary:
	return result.duplicate(true)
