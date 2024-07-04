@tool
extends EditorPlugin


var plugin_control: Control = null
var undo_redo: UndoRedo = null


func _enter_tree():
	undo_redo = UndoRedo.new()
	plugin_control = preload('dock.tscn').instantiate()
	plugin_control.plugin_script = self
	plugin_control.undo_redo = undo_redo
	get_editor_interface().get_editor_main_screen().add_child(plugin_control)
	plugin_control.hide()


# Built-in functions just for plugin appearance
func _has_main_screen() -> bool:
	return true
func _make_visible(visible: bool) -> void:
	plugin_control.visible = visible
func _get_plugin_name() -> String:
	return 'POT Word'
func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon('Translation', 'EditorIcons')



func _exit_tree() -> void:
	if plugin_control != null:
		EditorInterface.get_editor_main_screen().remove_child(plugin_control)
		plugin_control.queue_free()
