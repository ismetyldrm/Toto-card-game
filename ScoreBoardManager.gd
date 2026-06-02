extends Node
class_name ScoreboardManager

const RAUNT_SUTUN_GENISLIGI := 60     
const OYUNCU_SUTUN_GENISLIGI := 100   

@export var score_grid: GridContainer
@export var scroll_container: ScrollContainer
@export var header_labels: Array[Label] = []
var ui_order = [1, 2, 3, 0]   # Tek kişilikte: Bot1, Bot2, Bot3, Siz (değişmez)

# Raunt sayısını takip etmek için
var current_round_num: int = 1
# Toplam puanları takip etmek için
var total_scores = [0, 0, 0, 0]

func _get_round_display_name(num: int) -> String:
	if num <= 12:
		return str(num)
	elif num == 13:
		return "Sinek"
	elif num == 14:
		return "Kupa"
	elif num == 15:
		return "Maça"
	elif num == 16:
		return "Karo"
	elif num >= 17 and num <= 19:
		return "S"
	return str(num) # Güvenlik için varsayılan

func add_new_round_results(tricks_won: Array, player_bids: Array, is_sanzoti: bool = false):
	# 1. Raunt ismini belirle (Sayı, koz veya S)
	var round_name = _get_round_display_name(current_round_num)
	_create_round_label(round_name)
	
	for i in ui_order:
		# KRİTİK DOKUNUŞ: is_sanzoti parametresini de fonksiyona yolluyoruz
		var round_score = _calculate_round_score(tricks_won[i], player_bids[i], is_sanzoti)
		
		total_scores[i] += round_score
		
		# ARTIK width PARAMETRESİ YOK: Tek grid olduğu için otomatik hizalanıyor
		_create_score_label(round_score)
	
	# Raunt sayısını 1 artır ve aşağı kaydır
	current_round_num += 1
	_scroll_to_bottom()

func _calculate_round_score(won: int, bid: int, is_sanzoti: bool = false) -> int:
	if is_sanzoti and bid == 0:
		if won == 0:
			return 35 
		else:
			return 0 
	if won == bid:
		return (won * won) + 10
		
	# Batar veya tutturamazsa 0 puan
	return 0

func _create_round_label(round_text: String):
	var label = Label.new()
	label.text = round_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size.x = RAUNT_SUTUN_GENISLIGI
	label.size_flags_horizontal = Control.SIZE_FILL   # EXPAND değil
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("#b22222"))
	score_grid.add_child(label)

func _create_score_label(score: int):
	var label = Label.new()
	label.text = str(score)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size.x = OYUNCU_SUTUN_GENISLIGI
	label.size_flags_horizontal = Control.SIZE_FILL
	label.add_theme_font_size_override("font_size", 32)
	if score == 0:
		label.add_theme_color_override("font_color", Color("#a0aec0"))
	else:
		label.add_theme_color_override("font_color", Color("#1a365d"))
	score_grid.add_child(label)

func _scroll_to_bottom():
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func set_player_names(isimler: Array):
	for i in range(min(header_labels.size(), isimler.size())):
		if header_labels[i]:
			header_labels[i].text = str(isimler[i])
			header_labels[i].clip_text = true
			header_labels[i].custom_minimum_size.x = OYUNCU_SUTUN_GENISLIGI
			header_labels[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header_labels[i].size_flags_horizontal = Control.SIZE_FILL
