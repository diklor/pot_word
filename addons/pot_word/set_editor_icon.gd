@tool
extends Button


@export var icon_name := ''
@export var update := false:
	set(value):
		_enter_tree()


func _enter_tree():
	icon = get_theme_icon(icon_name, 'EditorIcons')
	set_button_icon(icon)
	if is_class('OptionButton'):
		for i: int in self.item_count:
			self['set_item_icon'].call(i, icon)
			#If there is error just comment all conditional lines starting from 14


