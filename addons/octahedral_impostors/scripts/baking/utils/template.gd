class_name Template

var template: String


func load_file(filename: String) -> String:
	var f = FileAccess

	if not f.file_exists(filename):
		print('Template [%s] does not exist' % filename)
		return ""

	var result = {}

	f = f.open(filename, f.READ)
	result = f.get_as_text()
	f.close()
	return result


func _init(template_name: String) -> void:
	var template_path = "res://addons/octahedral_impostors/templates/" + template_name + ".template"
	template = load_file(template_path)


func fill(parameter: String, value: String) -> void:
	template = template.replace("%" + parameter + "%", value)


func save(save_path: String) -> void:
	var f = FileAccess
	f = f.open(save_path, f.WRITE)
	f.store_string(template)
	f.close()
