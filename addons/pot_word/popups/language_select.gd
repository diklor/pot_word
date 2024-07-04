@tool
extends ColorRect
const F := preload('res://addons/pot_word/functions.gd')


@onready var language_select_vbox: VBoxContainer = %language_select_vbox
@onready var languages_vbox: VBoxContainer = language_select_vbox.get_node('hbox/languages')
@onready var countries_vbox: VBoxContainer = language_select_vbox.get_node('hbox/countries')

@onready var DOCK: Control = $'..'


var _line_edit: LineEdit = null
var _lists_loaded := false



func _ready() -> void:
	$close_button.pressed.connect(hide)
	
	%language_select_vbox.get_node('title/refresh').pressed.connect(await load_lists)
	%operations_hbox/original_select_lang.pressed.connect(await show_popup.bind(%operations_hbox/original_lang_line_edit))
	%operations_hbox/target_select_lang.pressed.connect(await show_popup.bind(%operations_hbox/target_lang_line_edit, true))
	language_select_vbox.get_node('select').pressed.connect(func() -> void:
		if _is_target_lang:
			DOCK.current_pot_file.export_description['Language'] = (_selected_language + _selected_country)
		else:
			DOCK.original_lang = (_selected_language + _selected_country)
		if _line_edit != null:
			_line_edit.text = (_selected_language + _selected_country)
		hide()
	)
	
	#SEARCH LINE EDITS
	for cont_name: String in (['languages', 'countries'] as Array[String]):
		var cont_hbox := language_select_vbox.get_node('hbox/' + cont_name) as Container
		var cont_line_edit := cont_hbox.get_node('line_edit') as LineEdit
		
		
		cont_line_edit.text_changed.connect(func(new_text: String) -> void:
			F.cont_func(cont_hbox.get_node('scroll/list'), func(v: Button):
				v.visible = DOCK.is_search_text(v.name, new_text)
			)
		)




var _selected_language := ''
var _selected_country := ''
var _is_target_lang := false

#used only in this script
func show_popup(line_edit: LineEdit, is_target_lang_state := false) -> void: #async
	show()
	_selected_language = ''
	_selected_country = ''
	_is_target_lang = is_target_lang_state
	_line_edit = line_edit
	languages_vbox.get_node('line_edit').clear()
	countries_vbox.get_node('line_edit').clear()
	
	
	
	if _lists_loaded:
		return
	
	
	await load_lists()
	
	_lists_loaded = true



func load_lists() -> void:
	F.clear_cont(languages_vbox.get_node('scroll/list'))
	F.clear_cont(countries_vbox.get_node('scroll/list'))
	
	if 1:
		var i := 0
		for v: String in TranslationServer.get_all_languages():
			F.add_tmp(languages_vbox.get_node('scroll/list'), '_button_tmp', func(new_button: Button) -> void:
				var lang_name := TranslationServer.get_language_name(v)
				new_button.text = '[' + v + '] ' + lang_name
				new_button.name = v + '_' + lang_name
				new_button.pressed.connect(func() -> void:
					languages_vbox.get_node('line_edit').text = v
					_selected_language = v
				)
			)
			if (i % 100) == 0:
				await Engine.get_main_loop().process_frame
			i += 1
		
		i = 0
		for lang_code: String in (['en', 'es', 'ru', 'hi', 'zh'] as Array[String]):
			languages_vbox.get_node('scroll/list').move_child(
				languages_vbox.get_node('scroll/list/' + (lang_code + '_' + TranslationServer.get_language_name(lang_code))),
				i 
			)
			i += 1
	
	
	if 1:
		var i := 0
		for v: String in TranslationServer.get_all_countries():
			F.add_tmp(countries_vbox.get_node('scroll/list'), '_button_tmp', func(new_button: Button) -> void:
				var country_name := TranslationServer.get_country_name(v)
				new_button.text = '[' + v + '] ' + country_name
				new_button.name = v + '_' + country_name
				new_button.pressed.connect(func() -> void:
					countries_vbox.get_node('line_edit').text = v
					_selected_country = v
				)
			)
			if (i % 100) == 0:
				await Engine.get_main_loop().process_frame
			i += 1
