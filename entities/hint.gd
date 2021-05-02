extends Spatial

export(String) var hint_text
export(Texture) var journal_page

func activate():
	$AnimationPlayer.play("activated")

func on_body_entered(body):
	if body is Sonic:
		if hint_text:
			print("Hint: "+hint_text)
			body.read_hint_text(hint_text)
		if journal_page:
			body.get_journal_page(journal_page)
	activate()
