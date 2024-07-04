@tool
extends ColorRect
const F := preload('res://addons/pot_word/functions.gd')


@onready var information_description_vbox: VBoxContainer = %information_description_vbox
@onready var information_comments_text_edit: TextEdit = %information_popup_vbox.get_node('hbox/comments/vbox/text_edit')

@onready var DOCK: Control = $'..'




func _ready() -> void:
	$close_button.pressed.connect(hide)
	
	information_comments_text_edit.text_changed.connect(func() -> void:
		DOCK.current_pot_file.comments = information_comments_text_edit.text
	)
	information_comments_text_edit.get_node('buttons_hbox/reset').pressed.connect(
		information_comments_text_edit.set_text.bind(information_comments_text_edit.get_meta('original_text', ''))
	)
	DOCK.on_slots_loaded.connect(func() -> void:
		information_comments_text_edit.set_meta('original_text', DOCK.current_pot_file.comments)
		information_comments_text_edit.text = DOCK.current_pot_file.comments
	)
	


func show_popup() -> void:
	show()
	F.clear_cont(information_description_vbox)
	
	if DOCK.current_pot_file.description.size() == 0:
		information_description_vbox.get_node('_no_description').show()
	else:
		DOCK.load_properties_cont(information_description_vbox, DOCK.current_pot_file.description, true)
	
	
	information_comments_text_edit.text = DOCK.current_pot_file.comments

