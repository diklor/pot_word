@tool
extends ColorRect
const F := preload('res://addons/pot_word/functions.gd')
const DOCK_SCRIPT := preload('res://addons/pot_word/dock.gd')

@onready var rename_scene_names_vbox: VBoxContainer = %rename_scene_names_vbox

@onready var DOCK: Control = $'..'




func _ready() -> void:
	$close_button.pressed.connect(hide)
	%operations_hbox.get_node('rename_scene_names').pressed.connect(show_popup)
	rename_scene_names_vbox



#used only in this script
func show_popup() -> void:
	show()
	
	
	F.clear_cont(%rename_scene_names_vbox)
	
	var all_scene_names: Array[String] = []
	for i: int in %search_hbox/scene_option.item_count:
		if (i == 0):
			continue #no "All"
		all_scene_names.append(%search_hbox/scene_option.get_item_text(i))
	
	for scene_name: String in all_scene_names:
		F.add_tmp(%rename_scene_names_vbox as Container, '_scene_name_tmp', func(new_scene_name_line_edit: LineEdit) -> void:
			new_scene_name_line_edit.name = scene_name
			new_scene_name_line_edit.text = scene_name
			new_scene_name_line_edit.set_meta('previous_text', scene_name)
			new_scene_name_line_edit.text_submitted.connect(func(new_text: String) -> void:
				new_scene_name_line_edit.editable = false
				var previous_text: String = new_scene_name_line_edit.get_meta('previous_text', scene_name)
				new_scene_name_line_edit.set_meta('previous_text', new_text)
				
				for pot_slot: DOCK_SCRIPT.PotSlot in (DOCK.current_pot_file.slots as Array[DOCK_SCRIPT.PotSlot]):
					if pot_slot.message_scene_name == previous_text:
						pot_slot.message_scene_name = new_text
				
				await DOCK.load_slots(true) #keep scroll position
				new_scene_name_line_edit.editable = true
				show()
			)
		)

