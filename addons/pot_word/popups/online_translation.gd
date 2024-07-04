@tool
extends ColorRect
const F := preload('res://addons/pot_word/functions.gd')
const DOCK_SCRIPT := preload('res://addons/pot_word/dock.gd')

const MAX_ONLINE_TRANSLATION_LINES_ONCE := 200

@onready var online_translation_texts_list: VBoxContainer = %online_translation_texts_list

@onready var DOCK: Control = $'..'


var translations_separator := '\n\\\n'



func _ready() -> void:
	$close_button.pressed.connect(func() -> void:
		hide()
		translating_slot_conts.clear()
	)
	%online_translation_hbox/separator.text_submitted.connect(show_popup.unbind(1))
	%online_translation_scroll_buttons.get_node('up').pressed.connect(%translations_scroll.set_v_scroll.bind(0))
	%online_translation_scroll_buttons.get_node('down').pressed.connect(%translations_scroll.set_v_scroll.bind(999_999_999))
	%online_translation_done.pressed.connect(func() -> void:
		var translated_texts_string := ''
		
		var text_edits_index := 0
		for text_edits: Container in %online_translation_texts_list.get_children():
			if text_edits.visible:
				if text_edits.get_node('translated/vbox/text_edit').text.is_empty():
					continue
				
				var slot_index_start := (MAX_ONLINE_TRANSLATION_LINES_ONCE * text_edits_index)
				var not_translate_prefix_line_edit := %online_translation_hbox/not_translate_prefix as LineEdit
				
				var i := 0
				for v: String in text_edits.get_node('translated/vbox/text_edit').text.split(translations_separator):
					if not_translate_prefix_line_edit.text.is_empty() or (!not_translate_prefix_line_edit.text.is_empty() and v.begins_with(not_translate_prefix_line_edit.text)):
						var slot_index := slot_index_start + i
						var slot_cont := %slots_scroll_vbox.get_node_or_null('slot_' + str(slot_index)) as Container
						if slot_cont != null:
							slot_cont.get_node('text_edits/translated').text = v
					i += 1
				
				text_edits_index += 1
			
			hide()
			translating_slot_conts.clear()
	)




var translating_slot_conts: Array[Container] = []
#var translating_plural: Dictionary = {} #Dictionary[int, PotSlot] later


func show_popup() -> void:
	if !DOCK.current_pot_file:
		return
	
	show()
	translations_separator = %online_translation_hbox/separator.text.replace('\\s', ' ').c_unescape()
	translating_slot_conts.clear()
	
	
	var texts_string := ''
	for v: Container in %slots_scroll_vbox.get_children():
		if v.visible:
			translating_slot_conts.append(v)
			texts_string += DOCK.current_pot_file.slots[v.get_meta('slot_index', 0) as int].message_id + translations_separator
	
	
	var texts_array: Array[String] = [texts_string]
	var link_string := 'https://translate.google.com/?sl=%s&tl=%s' % [
		#original_lang_line_edit,
		'',
		DOCK.current_pot_file.export_description['Language']
	]
	
	
	if (texts_string.count('\n') > MAX_ONLINE_TRANSLATION_LINES_ONCE):
		var new_texts_array: Array[String] = []
		var current_texts := ''
		var i := 0
		for line: String in texts_string.split(translations_separator):
			current_texts += line + translations_separator
			if i >= MAX_ONLINE_TRANSLATION_LINES_ONCE:
				new_texts_array.append(current_texts)
				current_texts = ''
				i = 0
			
			i += 1
		
		texts_array = new_texts_array
	
	
	F.clear_cont(online_translation_texts_list)
	
	var i := 0
	for text: String in texts_array:
		F.add_tmp(online_translation_texts_list, '_text_edits_tmp', func(new_text_edits: Container) -> void:
			new_text_edits.name = 'texts_' + str(i) #just for naming
			
			(new_text_edits.get_node('original/vbox/text_edit') as TextEdit).text = text
			(new_text_edits.get_node('original/vbox/text_edit/open_link') as Button).pressed.connect(func() -> void:
				OS.shell_open(link_string + '&text=' + text.uri_encode() + '&op=translate')
			)
			
			new_text_edits.show()
			i += 1
		)

