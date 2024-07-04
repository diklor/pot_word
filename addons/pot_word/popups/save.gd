@tool
extends ColorRect
const F := preload('res://addons/pot_word/functions.gd')
const DOCK_SCRIPT := preload('res://addons/pot_word/dock.gd')

@onready var scene_path_option: OptionButton = %save_popup_vbox.get_node('scene_path_hbox/scene_path_option')

@onready var DOCK: Control = $'..'


signal language_chosen(language_string: String)




static func _clean_text(text: String, add_quotes := false) -> String:
	text = text.trim_prefix('"').trim_suffix('"').replace('\n', '\\n').trim_suffix('\n').c_escape()
	if add_quotes:
		text = '"' + text + '"'
	return text

static func get_multiline_string(text: String, add_quotes := false) -> String:
	if text.contains('\n'):
		var multiline_text := '""\n'
		for line: String in text:
			multiline_text += '"' + _clean_text(line, add_quotes) + '"\n'
		return multiline_text
	else:
		return _clean_text(text, add_quotes) + '\n'


func _ready() -> void:
	$close_button.pressed.connect(hide)
	
	DOCK.on_slots_loaded.connect(func() -> void:
		if !DOCK.current_pot_file:
			return
		DOCK.current_pot_file.export_description['X-Generator'] = DOCK.plugin_script._get_plugin_name().replace(' ', '')  + ' ' + DOCK.plugin_script.get_plugin_version()
	)
	
	%save_properties_hbox.get_node('clear_description').toggled.connect(func(state: bool) -> void:
		%save_popup_vbox.get_node('export_description').modulate.v = (0.6 if state else 1.0)
	)
	%all_plural_forms_label.meta_clicked.connect(func(_meta: Variant) -> void: OS.shell_open('https://docs.translatehouse.org/projects/localization-guide/en/latest/l10n/pluralforms.html'))
	%save_popup_buttons_hbox.get_node('back').pressed.connect(hide)
	%save_popup_buttons_hbox.get_node('save').pressed.connect(func() -> void:
		if !DOCK.current_pot_file or DOCK.current_pot_file.slots.is_empty():
			return
		
		var file_content := ''
		
		
		if !%save_properties_hbox.get_node('clear_comments').button_pressed:
			var saving_comments_text := ''
			for comment_line: String in DOCK.current_pot_file.comments.split('\n'):
				if comment_line.begins_with(','):
					saving_comments_text += '#' + comment_line + '\n'
					continue
				elif comment_line.is_empty():
					saving_comments_text += '#\n'
					continue
				saving_comments_text += '# ' + comment_line + '\n'
			
			file_content += saving_comments_text.trim_suffix('\n').trim_suffix('\n#\n#')
		
		
		file_content += 'msgid ""\nmsgstr ""\n'
		
		if !%save_properties_hbox.get_node('clear_description').button_pressed:
			var saving_description_text := ''
			for description_dict: Dictionary in [DOCK.current_pot_file.description, DOCK.current_pot_file.export_description]:
				for key: String in description_dict:
					#if description_dict[key].is_empty():
						#continue
					saving_description_text += '"' + key + ': ' + description_dict[key] + '\\n"\n'
			
			file_content += saving_description_text + '\n\n'
		else:
			file_content += '\n'
		
		
		for slot: DOCK_SCRIPT.PotSlot in DOCK.current_pot_file.slots:
			if !slot.message_description.is_empty():
				var saving_slot_description := ''
				for line: String in slot.message_description.trim_suffix('\n').split('\n'):
					if line.is_empty():
						continue
					saving_slot_description += '# ' + get_multiline_string(line.strip_edges())
				file_content += saving_slot_description.trim_suffix('\n') + '\n'
			if !slot.message_flag.is_empty():
				file_content += '#, ' + get_multiline_string(slot.message_flag)
			
			if !slot.message_scene_name.is_empty():
				var total_scene_name := slot.message_scene_name
				match scene_path_option.selected:
					0:
						total_scene_name = ('res://' if !total_scene_name.begins_with('res://') else '')  + total_scene_name.trim_prefix('/')
					1:
						total_scene_name =  '/' + total_scene_name.trim_prefix(total_scene_name.rsplit('/')[0])
					2:
						pass
					3:
						var path_split := total_scene_name.rsplit('/', true, 2) # folder, other folders or '', scene.tscn
						total_scene_name = ((path_split[1] + '/') if !path_split[1].is_empty() else '') + path_split[2]
					4:
						total_scene_name = total_scene_name.rsplit('/', true, 1)[1]
					5:
						total_scene_name = total_scene_name.rsplit('/', true, 1)[1].rsplit('.', true, 1)[0]
				
				if scene_path_option.selected != 6:
					file_content += '#: ' + total_scene_name + '\n'
			
			file_content += 'msgid ' + get_multiline_string(slot.message_id, true)
			if slot.message_translated_plurals.is_empty():
				file_content += 'msgstr ' + get_multiline_string(slot.message_translated, true)
			else:
				file_content += 'msgid_plural ' + get_multiline_string(slot.message_id_plural, true)
				file_content += 'msgstr[0] ' + get_multiline_string(slot.message_translated, true)
				for plural_index: int in slot.message_translated_plurals:
					file_content += 'msgstr[%d] %s' % [plural_index, get_multiline_string(slot.message_translated_plurals[plural_index], true)]
			file_content += '\n'
		
		
		
		var current_file_path_parent_split := (DOCK.current_file_path as String).rsplit('/', true, 1)
		var current_file_extension_no_dot := (DOCK.current_file_path as String).rsplit('.', true, 1)[1]
		
		var filters := PackedStringArray()
		filters.append('*.po')
		filters.append('*.pot')
		
		DisplayServer.file_dialog_show(
			'Save translations file',
			current_file_path_parent_split[0],  current_file_path_parent_split[1].replace(current_file_extension_no_dot, 'po'),
			true,  DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, filters,
			
			func(status: bool, selected_paths: PackedStringArray, selected_filter_index: int) -> void:
				if status:
					var path := selected_paths[0]
					var file_name = path.rsplit('\\', true, 1)[1]
					var file_parent_path = path.trim_suffix(file_name)
					
					
					var file := FileAccess.open(
						file_parent_path + '\\'  +  file_name.rsplit('.', true, 1)[0]  +  filters[selected_filter_index - 1].trim_prefix('*'),
						FileAccess.WRITE
					)
					if file == null:
						printerr('POT Word: File save error: ' + error_string(FileAccess.get_open_error()))
						return
					
					file.store_string(file_content)
					file = null
		)
	)


func show_popup() -> void:
	show()
	DOCK.load_properties_cont(%export_information_description_vbox, DOCK.current_pot_file.export_description)
