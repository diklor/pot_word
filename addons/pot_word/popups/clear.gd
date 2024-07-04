@tool
extends ColorRect
const F := preload('res://addons/pot_word/functions.gd')


@onready var DOCK: Control = $'..'




func _ready() -> void:
	$close_button.pressed.connect(hide)
	
	%clear_popup_ok.pressed.connect(func() -> void:
		if !DOCK.current_pot_file:
			return
		DOCK.current_pot_file = null
		DOCK.current_file_path = ''
		DOCK.currently_reading_pot_slot = null
		DOCK.current_file_content = ''
		await DOCK.load_file()
		hide()
	)



func show_popup() -> void:
	show()
