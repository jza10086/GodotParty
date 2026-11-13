## Client-local translations. Every package resolves the original preference independently.
## PO resources stay private to their package; nothing is added to the global translation domain.
extends RefCounted

signal changed()
const Data = preload("res://core/runtime/party_data.gd")
const DEFAULT_LOCALE: String = "zh_Hans"
const LOCALES: Array[String] = ["zh_Hans", "en"]
const DISPLAY_FIELDS: Array[String] = ["title", "description", "placeholder", "suffix", "disabled_reason"]
var content_catalog: WeakRef
var locale: String = DEFAULT_LOCALE
var last_error: String = ""
var _packages: Dictionary = {}

class Scope extends RefCounted:
	var _service: RefCounted
	var _package: String

	func _init(service: RefCounted, package_id: String) -> void:
		_service = service
		_package = package_id

	## Explicit package_id selects protocol/framework text instead of this activity's text.
	func text(key: StringName, parameters: Dictionary = {}, package_id: String = "") -> String:
		return _service.text(_package if package_id.is_empty() else package_id, key, parameters)

	func effective_locale() -> String:
		return _service.effective_locale(_package)

func scope(package_id: String) -> Scope:
	return Scope.new(self, package_id)

## Checks the manifest declaration without loading translation resources.
static func validate_declaration(value: Variant) -> String:
	if not value is Dictionary:
		return "Missing localization declaration"
	if not value.get("supported_locales") is Array or value.supported_locales.is_empty():
		return "localization.supported_locales must be a nonempty array"
	for language: Variant in value.supported_locales:
		if not language is String or language not in LOCALES or value.supported_locales.count(language) != 1:
			return "Invalid or duplicate supported locale"
	if value.get("fallback_locale") != DEFAULT_LOCALE or DEFAULT_LOCALE not in value.supported_locales:
		return "localization.fallback_locale must be supported zh_Hans"
	if not value.get("translations") is Dictionary or value.translations.size() != value.supported_locales.size():
		return "Translations must match supported_locales"
	for language: String in value.supported_locales:
		if not value.translations.get(language) is String or not Data.relative_path(value.translations[language]):
			return "Invalid translation resource path"
	return ""

## Discovery records paths only. Display loads the requested language on first use.
func declare_package(package_id: String, declaration: Dictionary, root: String) -> void:
	_packages[package_id] = {"id": package_id, "declaration": declaration, "root": root, "translations": {}}

func _translation(package: Dictionary, language: String) -> Translation:
	if not package.translations.has(language):
		var path: String = package.root.path_join(package.declaration.translations[language])
		var resource: Resource = content_catalog.get_ref().resource(package.id, package.declaration.translations[language]) if content_catalog != null else load(path)
		if not resource is Translation or resource.locale != language:
			push_error("Invalid translation/locale: " + path)
			return null
		package.translations[language] = resource
	return package.translations[language]

## Full translation checks are used by the core and package publishing tools.
func register_package(package_id: String, declaration: Dictionary, root: String) -> Error:
	last_error = validate_declaration(declaration)
	if not last_error.is_empty():
		return ERR_INVALID_DATA
	var translations: Dictionary = {}
	for language: String in declaration.supported_locales:
		var path: String = root.path_join(declaration.translations[language])
		if not ResourceLoader.exists(path):
			return _fail(package_id + ": missing translation " + path)
		var resource: Resource = load(path)
		if not resource is Translation or resource.locale != language:
			return _fail(package_id + ": invalid translation/locale " + path)
		translations[language] = resource
	var fallback: Translation = translations[declaration.fallback_locale]
	for language: String in translations:
		var translation: Translation = translations[language]
		for key: String in translation.get_message_list():
			var source: String = fallback.get_message(key)
			var target: String = translation.get_message(key)
			if source.is_empty():
				return _fail(package_id + ": missing fallback message " + key)
			if not target.is_empty() and _placeholders(source) != _placeholders(target):
				return _fail(package_id + ": placeholder mismatch " + language + "/" + key)
	_packages[package_id] = {"declaration": declaration.duplicate(true), "translations": translations}
	return OK

## Catalog metadata/schema keys are known before activation, so reject missing defaults there.
func validate_messages(package_id: String, manifest: Dictionary, schema: Dictionary) -> Error:
	var keys: Array[String] = []
	for key: String in ["name", "introduction"]:
		if manifest.has(key) and not manifest[key].is_empty():
			keys.append(manifest[key])
	for field: Dictionary in schema.fields.values():
		_spec_keys(field, keys)
	for group: Dictionary in schema.layout:
		_spec_keys(group, keys)
	for key: String in keys:
		if not has_message(package_id, key):
			return _fail(package_id + ": missing fallback message " + key)
	return OK

func _spec_keys(spec: Dictionary, keys: Array[String]) -> void:
	for property: String in DISPLAY_FIELDS:
		if spec.has(property) and not spec[property].is_empty():
			keys.append(spec[property])
	for label: String in spec.get("labels", []):
		if not label.is_empty():
			keys.append(label)
	if spec.has("items"):
		_spec_keys(spec.items, keys)
	for child: Dictionary in spec.get("children", []):
		_spec_keys(child, keys)

func _fail(message: String) -> Error:
	last_error = message
	return ERR_INVALID_DATA

static func _placeholders(message: String) -> Array[String]:
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\{[a-zA-Z_][a-zA-Z_0-9]*\\}")
	var result: Array[String] = []
	for match_value: RegExMatch in pattern.search_all(message):
		var key: String = match_value.get_string()
		if key not in result:
			result.append(key)
	result.sort()
	return result

func set_locale(language: String) -> Error:
	if language not in LOCALES:
		return ERR_INVALID_PARAMETER
	if locale != language:
		locale = language
		changed.emit()
	return OK

func effective_locale(package_id: String) -> String:
	var declaration: Dictionary = _packages[package_id].declaration
	return locale if locale in declaration.supported_locales else declaration.fallback_locale

func has_message(package_id: String, key: StringName) -> bool:
	var package: Dictionary = _packages[package_id]
	var fallback: Translation = _translation(package, package.declaration.fallback_locale)
	return fallback != null and not fallback.get_message(key).is_empty()

## Missing target messages use this package's declared fallback. Missing fallback is an author error.
func text(package_id: String, key: StringName, parameters: Dictionary = {}) -> String:
	var package: Dictionary = _packages[package_id]
	var translation: Translation = _translation(package, effective_locale(package_id))
	if translation == null:
		return "[MISSING " + package_id + "/" + str(key) + "]"
	var message: String = translation.get_message(key)
	if message.is_empty():
		var fallback: Translation = _translation(package, package.declaration.fallback_locale)
		if fallback != null:
			message = fallback.get_message(key)
	if message.is_empty():
		push_error("Missing localization message: " + package_id + "/" + str(key))
		return "[MISSING " + package_id + "/" + str(key) + "]"
	return message.format(parameters)

## Translate a copy's presentation only. Defaults, values, conditions and action IDs are untouched.
func localize_schema(package_id: String, schema: Dictionary) -> Dictionary:
	var result: Dictionary = schema.duplicate(true)
	for field: Dictionary in result.fields.values():
		_localize_spec(package_id, field)
	for group: Dictionary in result.layout:
		_localize_spec(package_id, group)
	return result

func _localize_spec(package_id: String, spec: Dictionary) -> void:
	for key: String in DISPLAY_FIELDS:
		if spec.has(key) and not spec[key].is_empty():
			spec[key] = text(package_id, spec[key])
	if spec.has("labels"):
		for index: int in spec.labels.size():
			if not spec.labels[index].is_empty():
				spec.labels[index] = text(package_id, spec.labels[index])
	if spec.has("items"):
		_localize_spec(package_id, spec.items)
	for child: Dictionary in spec.get("children", []):
		_localize_spec(package_id, child)
