extends Node
class_name ScoreboardManager

@export var score_grid: GridContainer
@export var scroll_container: ScrollContainer

# Toplam puanları takip etmek için (Opsiyonel)
var total_scores = [0, 0, 0, 0]

func add_new_round_results(tricks_won: Array, player_bids: Array):
	# UI Sıralaması: Bot 1, Bot 2, Bot 3, Siz
	var ui_order = [1, 2, 3, 0] 
	
	for i in ui_order:
		var round_score = _calculate_round_score(tricks_won[i], player_bids[i])
		total_scores[i] += round_score
		
		# Hücreyi oluştur ve tabloya ekle
		_create_score_label(round_score)
	
	# Yeni satır eklenince otomatik en aşağı kaydır
	_scroll_to_bottom()

func _calculate_round_score(won: int, bid: int) -> int:
	# Senin n^2 + 10 kuralın
	if won == bid:
		return (won * won) + 10
	return 0

func _create_score_label(score: int):
	var label = Label.new()
	label.text = str(score)
	label.custom_minimum_size.x = 100 # Üsttekiyle aynı değeri ver
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	label.add_theme_font_size_override("font_size", 32)
	
	if score == 0:
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
	
	score_grid.add_child(label)

func _scroll_to_bottom():
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
