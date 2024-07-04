@tool
extends Control
const F := preload('res://addons/pot_word/functions.gd')


enum ReadState { COMMENT, DESCRIPTION, SLOT}

const NO_THEME := preload('res://addons/pot_word/no_theme.tres')
const DOCK_THEME := preload('res://addons/pot_word/dock_theme.tres')

@onready var save_button: Button = %top_bar_hbox/save
@onready var search_hbox: HBoxContainer = %search_hbox
@onready var search_translation_check: CheckButton = %search_hbox/search_translation
@onready var scene_option: OptionButton = %search_hbox/scene_option

@onready var main_scroll: ScrollContainer = %main_scroll
@onready var slots_scroll_vbox: VBoxContainer =  %slots_scroll_vbox


@onready var online_translation_popup: ColorRect = $online_translation_popup
@onready var save_popup: ColorRect = $save_popup
@onready var language_select_popup: ColorRect = $language_select_popup
@onready var information_popup: ColorRect = $information_popup
@onready var clear_popup: ColorRect = $clear_popup
@onready var rename_scene_names_popup: ColorRect = $rename_scene_names_popup

@onready var popup_menu: PopupMenu = $popup_menu
@onready var loading: ColorRect = $loading



signal on_slots_loaded


var original_lang := 'en'


var current_file_path := ''
var current_file_content := ''
var current_pot_file: PotFile = null
var selected_slot_indexes: Array[int] = []

var is_in_pot_editor := false
var plugin_script: EditorPlugin = null
var undo_redo: UndoRedo = null
var undo_redo_history: Array[int] = [0, 0]
var undo_redo_history_descriptions: Array[String] = []



class PotFile:
	var comments: String
	var description: Dictionary = {} #Dictionary[String, String]
	var export_description: Dictionary = { #Dictionary[String, String]
		'Content-Transfer-Encoding': '8bit',
		'Plural-Forms': 'nplurals=1; plural=0',
		#'Plural-Forms2': 'nplurals=2; plural=(n!=1)', #Dutch
		'Language-Team': '',
		'Language': '',
		'X-Generator': 'POTWord',
	}
	var slots: Array[PotSlot] = []
	
	
	func _init(plugin_script: EditorPlugin) -> void:
		export_description['X-Generator'] += ' ' + plugin_script.get_plugin_version()
	
	func get_description_string() -> String:
		var description_string := ''
		for v: String in description:
			description_string += v + ': ' + description[v] + '\n'
		description_string = description_string.trim_suffix('\n')
		return description_string


class PotSlot:
	var index := 0
	
	var message_scene_name: String
	var message_id: String
	var message_translated: String #(message_string)
	var message_id_previous := ''
	var message_id_plural := ''
	var message_translated_plurals: Dictionary = {} #Dictionary[int, String]
	var message_description := ''
	var message_flag := ''




func _on_filed_dropped(files: PackedStringArray) -> void:
	#res://folder/file.pot
	if files.size() == 0:		return
	var file_path := ProjectSettings.localize_path(files[0])
	
	if !(file_path.ends_with('.po') or file_path.ends_with('.pot')):
		return
	
	var file_content := FileAccess.open(file_path, FileAccess.READ)
	if file_content == null:		return
	current_file_path = file_path
	current_file_content = file_content.get_as_text()
	await load_file()





func update_files_drop() -> void:
	var is_connected: bool = get_viewport().files_dropped.is_connected(_on_filed_dropped)
	if is_in_pot_editor:
		if !is_connected:
			get_viewport().files_dropped.connect(await _on_filed_dropped)
	else:
		if is_connected:
			get_viewport().files_dropped.disconnect(_on_filed_dropped)



func _hide_popups() -> void:
	save_popup.hide()
	language_select_popup.hide()
	online_translation_popup.hide()
	information_popup.hide()
	clear_popup.hide()
	rename_scene_names_popup.hide()
	popup_menu.hide()




func update_theme() -> void:
	if theme != NO_THEME:
		var accent_color: Color = plugin_script.get_editor_interface().get_editor_settings().get_setting('interface/theme/accent_color')
		
		for stylebox_type: String in (['focus', 'normal', 'read_only'] as Array[String]):
			(theme.get_stylebox(stylebox_type, &'LineEdit') as StyleBoxFlat).border_color = accent_color
		
		theme.set_color('font_pressed_color', &'Button', accent_color)
		theme.set_color('font_hover_color', &'Button', accent_color)
		theme.set_color('font_hover_pressed_color', &'Button', accent_color)
		theme.set_color('icon_pressed_color', &'Button', accent_color)
		theme.set_color('icon_hover_pressed_color', &'Button', accent_color)
		(theme.get_stylebox('focus', 'Button') as StyleBoxFlat).border_color = accent_color
		(theme.get_stylebox('focus', &'TextEdit') as StyleBoxFlat).border_color = accent_color
		(theme.get_stylebox('focus', &'CheckButton') as StyleBoxFlat).border_color = accent_color
		(theme.get_stylebox('focus', &'CheckBox') as StyleBoxFlat).border_color = accent_color
		theme.set_color('font_hover_pressed_color', &'OptionButton', accent_color)
		theme.set_color('icon_pressed_color', &'OptionButton', accent_color)
		theme.set_color('icon_pressed_color', &'CheckButton', accent_color)
		theme.set_color('icon_hover_color', &'CheckButton', accent_color)
		theme.set_color('icon_hover_pressed_color', &'CheckButton', accent_color)
		(theme.get_stylebox('focus', &'OptionButton') as StyleBoxFlat).border_color = accent_color
		(theme.get_stylebox('grabber_pressed', &'VScrollBar') as StyleBoxFlat).bg_color = accent_color



func _update_undoredo_history_counter() -> void:
	%undoredo_history_counter.text = str(undo_redo_history[0]) + '/' + str(undo_redo_history[1])
	if undo_redo_history[0] != 0:
		%undoredo_history_description.text = undo_redo_history_descriptions[undo_redo_history[0] - 1] if (undo_redo_history_descriptions.size() >= undo_redo_history[0] - 1) else ''
	else:
		%undoredo_history_description.text = ''



func _slots_method(erase: bool, pot_slots: Array[PotSlot]) -> void:
	for pot_slot: PotSlot in pot_slots:
		if erase:
			current_pot_file.slots.erase(pot_slot)
		else:
			current_pot_file.slots.append(pot_slot)
	
	
	current_pot_file.slots.sort_custom(func(a: PotSlot, b: PotSlot) -> bool:
		return a.index < b.index
	)
	
	var i := 0
	for pot_slot: PotSlot in current_pot_file.slots:
		pot_slot.index = i
		i += 1
	
	await load_slots(true)



func _clear_translated_slots_method(erase: bool, prev_message_ids: Dictionary, is_duplicate := false) -> void: # #Dictionary[int, String]
	F.cont_func(slots_scroll_vbox, func(v: Container) -> void:
		if erase:
			if is_duplicate:
				v.get_node('text_edits/translated').text = current_pot_file.slots[v.get_meta('slot_index', 0)].message_id
			else:
				v.get_node('text_edits/translated').clear()
		else:
			v.get_node('text_edits/translated').text = prev_message_ids[v.get_meta('slot_index', 0)]
	)


func _description_method(erase: bool, key: String, value := '') -> void:
	if erase:
		current_pot_file.description.erase(key)
	else:
		current_pot_file.description[key] = value
	
	information_popup.show_popup()





func _ready() -> void:
	_hide_popups()
	popup_menu.size = Vector2.ONE
	save_button.disabled = true
	show()
	
	
	
	if plugin_script != null:
		%dock_title.text = plugin_script._get_plugin_name() + ' ' + plugin_script.get_plugin_version()
		%file_info_hbox.show()
		F.clear_cont(slots_scroll_vbox)
		update_files_drop()
		anchors_preset = PRESET_FULL_RECT
		is_in_pot_editor = (plugin_script.get_editor_interface().get_editor_main_screen().name == plugin_script._get_plugin_name())
		plugin_script.main_screen_changed.connect(func(screen_name: String) -> void:
			is_in_pot_editor = (screen_name == plugin_script._get_plugin_name())
			update_files_drop()
		)
	
	scene_option.item_selected.connect(func(_index: int) -> void: update_slots())
	%top_bar_hbox/undo.pressed.connect(func() -> void:
		undo_redo.undo()
		undo_redo_history[0] = maxi(undo_redo_history[0] - 1, 0)
		_update_undoredo_history_counter()
	)
	%top_bar_hbox/redo.pressed.connect(func() -> void:
		undo_redo.redo()
		undo_redo_history[0] = mini(undo_redo_history[0] + 1, undo_redo_history[1])
		_update_undoredo_history_counter()
	)
	%top_bar_hbox/reload.pressed.connect(await load_file) #wow
	%top_bar_hbox/refresh.pressed.connect(await load_slots)
	%top_bar_hbox/online_translation.pressed.connect(online_translation_popup.show_popup)
	%dock_title/theme_button.toggled.connect(func(state: bool) -> void:
		theme = (DOCK_THEME if state else NO_THEME)
		update_theme()
	)
	
	
	save_button.pressed.connect(save_popup.show_popup)
	%top_bar_hbox/clear.pressed.connect(clear_popup.show)
	
	
	%select_file_button.pressed.connect(func() -> void:
		var filters := PackedStringArray()
		filters.append('*.pot')
		filters.append('*.po')
		
		DisplayServer.file_dialog_show('Select translations file', 'res://', '', 
			true, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			func(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int) -> void:
				if status:
					_on_filed_dropped(selected_paths)
		)
	)
	if 1:
		%operations_hbox/select_all.toggled.connect(func(state: bool) -> void:
			selected_slot_indexes.clear()
			
			F.cont_func(slots_scroll_vbox, func(v: Container) -> void:
				if v.visible:
					(v.get_node('text_edits/index_check') as Button).set_pressed_no_signal(state)
					if state:
						selected_slot_indexes.append(v.get_meta('slot_index', 0))
			)
		)
		for operation_name: String in (['clear_translated', 'duplicate_original'] as Array[String]):
			%operations_hbox.get_node(operation_name).pressed.connect(func() -> void:
				selected_slot_indexes.clear()
				
				var prev_message_ids: Dictionary = {} #Dictionary[int, String]   #slot index, slot message_id
				F.cont_func(slots_scroll_vbox, func(v: Container) -> void:
					if v.visible:
						var slot_index: int = v.get_meta('slot_index', 0)
						prev_message_ids[slot_index] = current_pot_file.slots[slot_index].message_translated
				)
				if prev_message_ids.is_empty():
					prev_message_ids[0] = ''
				
				
				var action_name := 'Clear all translated slots'
				if (operation_name == 'duplicate_original'):
					action_name = 'Duplicate original'
				action_name += ' (' + str(prev_message_ids.size()) + ' slots)'
				
				undo_redo.create_action(action_name)
				undo_redo.add_do_method(_clear_translated_slots_method.bind(true, prev_message_ids, (operation_name == 'duplicate_original')))
				undo_redo.add_undo_method(_clear_translated_slots_method.bind(false, prev_message_ids))
				selected_slot_indexes.clear()
				undo_redo_history[1] += 1
				undo_redo_history[0] = undo_redo_history[1]
				undo_redo_history_descriptions.append(action_name)
				undo_redo.commit_action(true)
				
				_update_undoredo_history_counter()
			)
	
	loading.get_node('hide_timer').timeout.connect(loading.hide)
	
	
	search_hbox.get_node('line_edit').text_changed.connect(update_slots.unbind(1))
	search_hbox.get_node('search_translation').pressed.connect(update_slots)
	search_hbox.get_node('only_numbers').pressed.connect(update_slots)
	search_hbox.get_node('one_symbol').pressed.connect(update_slots)
	
	popup_menu.id_pressed.connect(func(id: int) -> void:
		if selected_slot_indexes.is_empty():
			return
		
		var pot_slots: Array[PotSlot] = []
		for i: int in selected_slot_indexes:
			pot_slots.append(current_pot_file.slots[i])
		
		
		var slot_conts: Array[Container] = []
		for i: int in selected_slot_indexes:
			var slot_cont := slots_scroll_vbox.get_node_or_null('slot_' + str(i)) as Container
			if slot_cont != null:
				slot_conts.append(slot_cont)
		
		
		
		var action_name := ('slot%s: %s' % [
			('s' if selected_slot_indexes.size() > 1 else ''),
			', '.join(PackedStringArray(selected_slot_indexes)) if selected_slot_indexes.size() <= 6 else str(selected_slot_indexes.size()) + ' slots total',
		]).left(30)
		
		match id:
			1:
				action_name = 'Delete ' + action_name
				undo_redo.create_action(action_name)
				undo_redo.add_do_method(_slots_method.bind(true, pot_slots))
				undo_redo.add_undo_method(_slots_method.bind(false, pot_slots))
				selected_slot_indexes.clear()
				undo_redo_history[1] += 1
				undo_redo_history[0] = undo_redo_history[1]
				undo_redo_history_descriptions.append(action_name)
				undo_redo.commit_action(true)
			2, 3:
				action_name = ('Add' if (id == 2) else 'Delete') + ' description to ' + action_name
				
				for slot_cont: Container in slot_conts:
					(slot_cont.get_node('description') as Container).visible = (id == 2)
					if (id == 3):
						(slot_cont.get_node('description/text_edit') as TextEdit).text = ''
						#text_changed automatically clears description from slot
			4:
				_deselect_slots()
			5, 6:
				action_name = ('Add' if (id == 2) else 'Delete') + ' plural form' + ('s' if (id == 3) else '') + ' to ' + action_name
				
				for slot_cont: Container in slot_conts:
					var pot_slot: PotSlot = current_pot_file.slots[slot_cont.get_meta('slot_index', 0)]
					if (id == 6):
						F.cont_func(slot_cont.get_node('text_edits_plural'), func(plural_cont: Container) -> void:
							_remove_plural_cont(slot_cont, plural_cont.name.to_int(), pot_slot)
						)
					else:
						_add_plural_cont(slot_cont, pot_slot, pot_slot.message_translated_plurals.size() + 1)
				
				if (id == 6):
					for v: PotSlot in pot_slots:
						v.message_id_plural = ''
						v.message_translated_plurals.clear()
			7:
				for slot_cont: Container in slot_conts:
					slot_cont.get_node('id_previous').show()
			8:
				for slot_cont: Container in slot_conts:
					slot_cont.get_node('flag').show()
			9:
				for slot_cont: Container in slot_conts:
					slot_cont.get_node('scene_name_hbox').show()
			
	)
	
	%file_info_hbox/more.pressed.connect(information_popup.show_popup)
	%file_info_hbox/open_path.pressed.connect(func() -> void:
		OS.shell_open(ProjectSettings.globalize_path(current_file_path.rsplit('/', true, 1)[0]))
	)




func _deselect_slots() -> void:
	selected_slot_indexes.clear()
	F.cont_func(slots_scroll_vbox, func(v: Container) -> void:
		(v.get_node('text_edits/index_check') as Button).set_pressed_no_signal(false)
	)
	%operations_hbox/select_all.button_pressed = false




func _unhandled_input(event: InputEvent) -> void:
	if event.is_action('ui_cancel'):
		if selected_slot_indexes.size() > 0:
			_deselect_slots()
		_hide_popups()



var currently_reading_pot_slot: PotSlot = null
var _slots_count := 0

func check_slot_callable() -> void:
	if currently_reading_pot_slot == null:
		currently_reading_pot_slot = PotSlot.new()
		currently_reading_pot_slot.index = _slots_count
		_slots_count += 1

func _clean_text(text: String) -> String:
	return text.trim_prefix('"').trim_suffix('"').c_unescape()

func load_file() -> void:
	loading.get_node('label').text = 'Loading file...'
	loading.show()
	
	original_lang = 'en'
	%original_lang_line_edit.text = original_lang
	%target_lang_line_edit.text = ''
	
	loading.get_node('hide_timer').start()
	undo_redo_history = [0, 0]
	undo_redo_history_descriptions.clear()
	undo_redo.clear_history()
	
	
	var current_read_state := ReadState.COMMENT
	_slots_count = 0
	currently_reading_pot_slot = null
	current_pot_file = null #just
	
	
	if !current_file_content.is_empty():
		current_pot_file = PotFile.new(plugin_script)
		
		var comments_has_flag := false
		var previous_key := ''
		
		for line: String in current_file_content.split('\n', true):
			if line.is_empty() or (line == 'white-space'):
				if current_read_state == ReadState.DESCRIPTION or current_read_state == ReadState.SLOT:
					# > > > Step 3 New slot
					if currently_reading_pot_slot != null:
						current_pot_file.slots.append(currently_reading_pot_slot)
						currently_reading_pot_slot = null
					
					previous_key = ''
					current_read_state = ReadState.SLOT
				continue
			
			
			
			
			
			if (current_read_state == ReadState.COMMENT):
				# > Step 1 Comments
				if (line.begins_with('# ') or line.begins_with('#, ') or (line == '#')):
					if !comments_has_flag:
						current_pot_file.comments += line + '\n'
						if line.begins_with('#, '):
							comments_has_flag = true
					continue
				else:
					if line.is_empty() or line.begins_with('msg') or line.begins_with('"'):
						current_read_state = ReadState.DESCRIPTION
			
			
			if (current_read_state == ReadState.DESCRIPTION):
				# > > Step 2 Description
				if line.is_empty() or line.begins_with('msg'):
					continue
				
				var colon_split := line.trim_suffix('"').trim_suffix('"').split(':', true, 1)
				var key := colon_split[0].trim_prefix('"')
				
				var description_dict := current_pot_file.description
				if current_pot_file.export_description.has(key):
					description_dict = current_pot_file.export_description
				
				current_pot_file.description[key] = colon_split[1].trim_prefix(' ').trim_suffix('\n').trim_suffix('\\n')
				
			elif (current_read_state == ReadState.SLOT):
				# > > > > Step 4 New slot variables
				
				if line.begins_with('msgid '):
					check_slot_callable()
					currently_reading_pot_slot.message_id = _clean_text(line.trim_prefix('msgid '))
					previous_key = 'message_id'
				
				elif line.begins_with('msgstr '):
					check_slot_callable()
					currently_reading_pot_slot.message_translated = _clean_text(line.trim_prefix('msgstr '))
					previous_key = 'message_translated'
				
				elif line.begins_with('"') and line.ends_with('"'):
					check_slot_callable()
					if !previous_key.is_empty():
						currently_reading_pot_slot[previous_key] += _clean_text(line) + '\n'
				
				elif line.begins_with('msgid_plural '):
					check_slot_callable()
					currently_reading_pot_slot.message_id_plural = _clean_text(line.trim_prefix('msgid_plural '))
				
				elif line.begins_with('msgstr['):
					check_slot_callable()
					var plural_index := line.trim_prefix('msgstr[').get_slice(']', 0)
					if !plural_index.is_valid_int():
						continue
					var message_string := _clean_text(line.trim_prefix('msgstr[').get_slice(']', 1))
					if plural_index.to_int() == 0:
						currently_reading_pot_slot.message_translated = message_string
					else:
						currently_reading_pot_slot.message_translated_plurals[plural_index.to_int()] = message_string
				
				elif line.begins_with('# '):
					check_slot_callable()
					currently_reading_pot_slot = PotSlot.new()
					currently_reading_pot_slot.message_description += _clean_text(line.trim_prefix('# ').trim_prefix('#')) + '\n'
				
				elif line.begins_with('#:'): #single line
					check_slot_callable()
					currently_reading_pot_slot.message_scene_name = line.trim_prefix('#: ').trim_prefix('#:')
				
				elif line.begins_with('#|'): #single line
					check_slot_callable()
					currently_reading_pot_slot.message_id_previous = line.trim_prefix('#| ').trim_prefix('#|')
				
				elif line.begins_with('#,'): #single line
					check_slot_callable()
					currently_reading_pot_slot.message_flag = line.trim_prefix('#, ').trim_prefix('#,')
	
	currently_reading_pot_slot = null
	_slots_count = 0
	loading.hide()
	loading.get_node('hide_timer').stop()
	await load_slots()







func load_slots(save_scroll := false) -> void:
	var previous_scroll_value := main_scroll.scroll_vertical
	main_scroll.hide()
	loading.get_node('label').text = 'Loading slots...'
	_hide_popups()
	loading.show()
	loading.get_node('hide_timer').start()
	
	_update_undoredo_history_counter()
	F.clear_cont(slots_scroll_vbox)
	selected_slot_indexes.clear()
	
	
	var scene_names: Array[String] = []
	
	if current_pot_file != null:
		var wait_state := (%dock_title/wait_button as CheckButton).button_pressed 
		
		var i := 0
		for slot: PotSlot in current_pot_file.slots:
			if scene_names != null and !scene_names.has(slot.message_scene_name):
				scene_names.append(slot.message_scene_name)
			
			F.add_tmp(slots_scroll_vbox, '_slot_tmp', func(new_slot_cont: Container) -> void:
				new_slot_cont.name = 'slot_' + str(slot.index)
				(new_slot_cont.get_node('scene_name') as Label).text = ('   ' + slot.message_scene_name)
				new_slot_cont.set_meta('slot_index', slot.index)
				
				
				new_slot_cont.get_node('text_edits_plural').hide()
				new_slot_cont.get_node('original_plural').hide()
				new_slot_cont.get_node('scene_name_hbox').hide()
				
				
				
				for text_edit_type: String in (['original', 'translated'] as Array[String]):
					var text_edit := new_slot_cont.get_node('text_edits/' + text_edit_type) as TextEdit
					var message_variable_name: String = ('id' if (text_edit_type == 'original') else 'translated')
					_setup_buttons_hbox(text_edit, slot, message_variable_name)
				
				
				if 1:
					_setup_buttons_hbox(new_slot_cont.get_node('scene_name_hbox/text_edit'), slot, 'scene_name')
					new_slot_cont.get_node('scene_name_hbox/text_edit').text_changed.connect(func() -> void:
						new_slot_cont.get_node('scene_name').text = '   ' + new_slot_cont.get_node('scene_name_hbox/text_edit').text
					)
					new_slot_cont.get_node('scene_name_hbox/hide').pressed.connect(new_slot_cont.get_node('scene_name_hbox').hide)
				
				if 1:
					_setup_buttons_hbox(new_slot_cont.get_node('original_plural/text_edit'), slot, 'id_plural')
					F.clear_cont(new_slot_cont.get_node('text_edits_plural'))
					if !slot.message_translated_plurals.is_empty():
						for plural_index: int in slot.message_translated_plurals:
							_add_plural_cont(new_slot_cont, slot, plural_index)
				if 1:
					for v: String in ['id_previous', 'flag', 'description']:
						new_slot_cont.get_node(v).visible = !slot['message_' + v].is_empty()
						_setup_buttons_hbox(new_slot_cont.get_node(v + '/text_edit'), slot, v)
				if 1:
					var index_check := new_slot_cont.get_node('text_edits/index_check') as CheckBox
					index_check.text = str(slot.index)
					index_check.toggled.connect(func(state: bool) -> void:
						if state:
							if !selected_slot_indexes.has(slot.index):
								selected_slot_indexes.append(slot.index)
						else:
							selected_slot_indexes.erase(slot.index)
					)
					index_check.gui_input.connect(func(input: InputEvent) -> void:
						if (input is InputEventMouseButton) and input.is_pressed() and (input.button_index == MOUSE_BUTTON_RIGHT):
							if !selected_slot_indexes.has(slot.index):
								selected_slot_indexes.append(slot.index)
							index_check.set_pressed_no_signal(true)
							
							if selected_slot_indexes.is_empty():
								popup_menu.set_item_text(0, 'No selection')
							else:
								var array_concat := ', '.join(PackedStringArray(selected_slot_indexes))
								popup_menu.set_item_text(0, array_concat.left(100) + ('...' if array_concat.length() > 100 else ''))
							
							popup_menu.size = Vector2.ONE
							await get_tree().process_frame
							popup_menu.position = get_global_mouse_position()
							popup_menu.position.x -= 10
							popup_menu.position.y -= 14
							popup_menu.show()
					)
			)
			i += 1
			if wait_state:
				if (i % 15) == 0:
					await Engine.get_main_loop().process_frame
		
		if 1:
			var new_comments_text := ''
			for comment_line: String in current_pot_file.comments.split('\n'):
				new_comments_text += comment_line.trim_prefix('# ').trim_prefix('#') + '\n'
				#for multilines
			current_pot_file.comments = new_comments_text.trim_suffix('\n\n')
	
	
	%file_info_hbox/file_path.text = current_file_path
	search_hbox.get_node('line_edit').text = ''
	search_hbox.get_node('only_numbers').button_pressed = false
	search_hbox.get_node('one_symbol').button_pressed = false
	search_translation_check.button_pressed = false
	%operations_hbox/select_all.button_pressed = false
	
	main_scroll.scroll_vertical = previous_scroll_value
	save_button.disabled = false
	scene_option.clear()
	scene_option.add_item('All')
	scene_option.selected = 2
	for scene_name: String in scene_names:
		scene_option.add_item(scene_name)
	
	update_slots()
	
	main_scroll.show()
	loading.hide()
	loading.get_node('hide_timer').stop()
	on_slots_loaded.emit()





func update_slots() -> void:
	var hide_only_numbers_state := (search_hbox.get_node('only_numbers') as CheckBox).button_pressed
	var hide_one_symbol_state := (search_hbox.get_node('one_symbol') as CheckBox).button_pressed
	var scene_option_string: String = scene_option.get_item_text(scene_option.selected) if (scene_option.selected > 0) else ''
	var search_text: String = search_hbox.get_node('line_edit').text
	
	var search_instate_string := ('translated' if search_translation_check.button_pressed else 'original')
	
	F.cont_func(slots_scroll_vbox, func(v: Container) -> void:
		var pot_slot := current_pot_file.slots[v.get_meta('slot_index', 0) as int]
		if !scene_option_string.is_empty():
			if (pot_slot.message_scene_name != scene_option_string):
				v.hide()
				return
		
		var original_text := (v.get_node('text_edits/' + search_instate_string) as TextEdit).text
		if hide_only_numbers_state and original_text.is_valid_float():
			v.hide()
			return
		if hide_one_symbol_state and original_text.strip_edges().length() <= 1:
			v.hide()
			return
		if !is_search_text(original_text, search_text):
			v.hide()
			return
		
		v.show()
	)





#-##### STATIC FUNCS




func load_properties_cont(cont: Container, properties_dict: Dictionary, darken_export_properties := false) -> void:
	F.clear_cont(cont)
	
	for v: String in properties_dict:
		F.add_tmp(cont, '_property_tmp', func(new_property: Container) -> void:
			new_property.name = v
			
			var original_value: String = properties_dict[v]
			(new_property.get_node('reset') as Button).pressed.connect(new_property.get_node('value').set_text.bind(original_value))
			(new_property.get_node('remove') as Button).pressed.connect(func() -> void:
				if properties_dict.has(new_property.get_node('key').text):
					properties_dict.erase(new_property.get_node('key').text)
					cont.remove_child(new_property)
					new_property.queue_free()
			)
			new_property.get_node('key').text = v
			new_property.set_meta('previous_text', v)
			
			
			new_property.get_node('key').modulate.v = (0.6 if current_pot_file.export_description.has(v) else 1.0)
			
			(new_property.get_node('key') as LineEdit).text_changed.connect(func(new_text: String) -> void:
				if properties_dict.has(v):
					properties_dict.erase(v)
				if properties_dict.has(new_property.get_meta('previous_text')):
					properties_dict.erase(new_property.get_meta('previous_text'))
				
				new_property.get_node('key').modulate.v = (0.6 if current_pot_file.export_description.has(new_text) else 1.0)
				new_text = new_text.replace(' ', '-')
				new_property.set_meta('previous_text', new_text)
				properties_dict[new_text] = new_property.get_node('value').text
			)
			new_property.get_node('value').text = properties_dict[v]
			(new_property.get_node('value') as LineEdit).text_changed.connect(func(new_text: String) -> void:
				properties_dict[new_property.get_node('key').text] = new_text
			)
		)
	
	
	cont.move_child(cont.get_node('__add'), cont.get_child_count())
	if !cont.get_node('__add').has_meta('connected'):
		cont.get_node('__add').set_meta('connected', true)
		cont.get_node('__add').pressed.connect(func() -> void:
			properties_dict['New-Property' + str(properties_dict.size())] = ''
			load_properties_cont(cont, properties_dict)
		)



static func _setup_buttons_hbox(new_text_edit: TextEdit, slot: PotSlot, message_variable_name: String, slot_value_key: Variant = null) -> void:
	var reset_button := new_text_edit.get_node('buttons_hbox/reset') as Button
	var clear_button := new_text_edit.get_node_or_null('buttons_hbox/clear') as Button
	
	var original_value: Variant = slot['message_' + message_variable_name] #String | Dictionary
	if slot_value_key != null:
		match typeof(slot_value_key):
			TYPE_STRING:			original_value = slot[slot_value_key]
			_:						original_value = slot['message_' + message_variable_name][slot_value_key]
	
	
	new_text_edit.set_meta('original_value', original_value)
	new_text_edit.text = original_value
	
	if clear_button != null:
		clear_button.visible = !original_value.is_empty()
		clear_button.pressed.connect(func() -> void:
			new_text_edit.clear();	clear_button.hide()
			reset_button.visible = !original_value.is_empty()
		)
	
	reset_button.hide()
	reset_button.pressed.connect(func() -> void:
		new_text_edit.text = original_value;	reset_button.hide()
		if clear_button != null:
			clear_button.visible = !original_value.is_empty()
	)
	new_text_edit.text_changed.connect(func() -> void:
		var new_value: String = new_text_edit.text
		reset_button.visible = (new_value != original_value)
		if clear_button != null:
			clear_button.visible = !new_value.is_empty()
		
		if slot_value_key == null:
			slot['message_' + message_variable_name] = new_value
		else:
			match typeof(slot_value_key):
				TYPE_STRING:			slot[slot_value_key] = new_value
				_:						slot['message_' + message_variable_name][slot_value_key] = new_value
	)
	if 1:
		var text_edit_parent := new_text_edit.get_parent()
		if text_edit_parent.has_node('remove'):
			text_edit_parent.get_node('remove').pressed.connect(func() -> void:
				slot['message_' + message_variable_name] = ''
				text_edit_parent.hide()
			)




static func _add_plural_cont(new_slot_cont: Container, pot_slot: PotSlot, plural_index: int) -> void:
	if !pot_slot.message_translated_plurals.has(plural_index):
		if pot_slot.message_translated_plurals.size() == 0:
			plural_index = 1
			pot_slot.message_id_plural = new_slot_cont.get_node('text_edits/original').text
			new_slot_cont.get_node('original_plural/text_edit').text = pot_slot.message_id_plural
		
		pot_slot.message_translated_plurals[plural_index] = ''
	
	
	F.add_tmp(new_slot_cont.get_node('text_edits_plural') as Container, '_plural_tmp', func(new_plural_cont: Container) -> void:
		var slot_value: String = pot_slot.message_translated_plurals[plural_index]
		new_plural_cont.name = str(plural_index)
		(new_plural_cont.get_node('plural_index') as SpinBox).value = plural_index
		new_slot_cont.get_node('original_plural').show()
		new_slot_cont.get_node('text_edits_plural').show()
		(new_plural_cont.get_node('_label') as Label).tooltip_text = '(msgstr[' + str(plural_index) + '])'
		
		
		var plural_translated_text_edit := new_plural_cont.get_node('translated') as TextEdit
		plural_translated_text_edit.text = (pot_slot.message_translated_plurals[plural_index] if pot_slot.message_translated_plurals.has(plural_index) else pot_slot.message_id_plural)
		_setup_buttons_hbox(plural_translated_text_edit, pot_slot, 'translated_plurals', plural_index)
		
		
		
		(new_plural_cont.get_node('plural_index') as SpinBox).value_changed.connect(func(_new_value: float) -> void:
			var prev_index := plural_index
			plural_index = int((new_plural_cont.get_node('plural_index') as SpinBox).value)
			
			if pot_slot.message_translated_plurals.has(prev_index):
				var prev_index_value: String = pot_slot.message_translated_plurals[prev_index]
				pot_slot.message_translated_plurals.erase(prev_index)
			
				_remove_plural_cont(new_slot_cont, prev_index, pot_slot)
				pot_slot.message_translated_plurals[plural_index] = prev_index_value
				_add_plural_cont(new_slot_cont, pot_slot, plural_index)
		)
		plural_translated_text_edit.text_changed.connect(func() -> void:
			pot_slot.message_translated_plurals[plural_index] = plural_translated_text_edit.text
		)
		(new_plural_cont.get_node('_remove') as Button).pressed.connect(func() -> void: #not bind to get new plural_index
			_remove_plural_cont(new_slot_cont, plural_index, pot_slot) 
		)
		(new_plural_cont.get_node('add') as Button).pressed.connect(func() -> void:
			var new_plural_index := (pot_slot.message_translated_plurals.keys().back() as int) + 1
			_add_plural_cont(new_slot_cont, pot_slot, new_plural_index) #no + 1 because size()
		)
	, plural_index)



static func _remove_plural_cont(new_slot_cont: Container, plural_index: int, pot_slot: PotSlot) -> void:
	var plural_cont := new_slot_cont.get_node('text_edits_plural/' + str(plural_index)) as Container
	new_slot_cont.get_node('text_edits_plural').remove_child(plural_cont)
	plural_cont.queue_free()
	if pot_slot.message_translated_plurals.size() == 1:
		new_slot_cont.get_node('original_plural').hide()
		new_slot_cont.get_node('original_plural/text_edit').clear()
		new_slot_cont.get_node('text_edits_plural').hide()
		pot_slot.message_id_plural = ''
		pot_slot.message_translated_plurals.clear()
	else:
		pot_slot.message_translated_plurals.erase(plural_index)



static func is_search_text(full_text: String, search_text: String) -> bool:
	if search_text.is_empty() or (full_text.to_lower().contains(search_text.to_lower()) or full_text.similarity(search_text) >= 0.3):
		return true
	return false






#-##### POPUPS



