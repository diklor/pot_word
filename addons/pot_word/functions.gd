static func cont_func(cont: Container, callable: Callable, hidden_callable: Variant = null) -> void: #hidden_callable: Callable?
	for v: Control in cont.get_children():
		if v.name.begins_with('__'):
			continue
		
		if !v.name.begins_with('_'):
			callable.call(v)
		else:
			if hidden_callable != null:
				hidden_callable.call(v)


static func clear_cont(cont: Container) -> void:
	cont_func(cont, func(v: Control) -> void:
		cont.remove_child(v)
		v.queue_free()
	,
	func(v: Control) -> void:
		v.hide()
	)


static func add_tmp(cont: Container, tmp_name: String, callable: Callable, child_index := -1) -> void:
	var new_tmp := cont.get_node(tmp_name).duplicate() as Control
	callable.call(new_tmp)
	new_tmp.show()
	cont.add_child(new_tmp)
	if child_index != -1:
		cont.move_child(new_tmp, mini(child_index, cont.get_child_count() - 1))
