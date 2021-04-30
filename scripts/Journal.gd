extends Spatial

export(bool) var enabled: bool = true
export(Array, Texture) var pages = [
	
]
export(int) var current_page = 0

var open: bool = false setget set_open


func _input(event):
	if enabled and event.is_action_pressed("journal"):
		if !open and !get_tree().paused:
			open()
		elif open and get_tree().paused:
			close()
	if enabled and open:
		if event.is_action_pressed("ui_right"):
			if current_page + 1 < pages.size():
				current_page += 1
				$journal.show_page(pages[current_page])
		elif event.is_action_pressed("ui_left"):
			if current_page > 0:
				current_page -= 1
				$journal.show_page(pages[current_page])

func set_open(o):
	if pages.size() > 0:
		$journal.show_page(pages[current_page])
	open = o
	visible = o
	$journalUI.visible = o
	get_tree().paused = o
	
func open():
	set_open(true)
	$AnimationPlayer.play("open")

func close():
	$AnimationPlayer.play("close")

func complete_close():
	set_open(false)
