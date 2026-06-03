extends Node
class_name ScoreboardManager

const RAUNT_SUTUN_GENISLIGI := 60   
const OYUNCU_SUTUN_GENISLIGI := 130

@export var score_grid: GridContainer
@export var scroll_container: ScrollContainer
@export var header_labels: Array[Label] = []
var ui_order = [1, 2, 3, 0]   # Tek kişilikte: Bot1, Bot2, Bot3, Siz (değişmez)

# Raunt sayısını takip etmek için
var current_round_num: int = 1
# Toplam puanları takip etmek için
var total_scores = [0, 0, 0, 0]

func _ready():
	_hazirla_basliklar()
	# Scrollbar her zaman aynı yeri kaplasın → sütun genişlikleri sabit kalır
	if scroll_container:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS

func _get_round_display_name(num: int) -> String:
	if num <= 12:
		return str(num)
	elif num == 13:
		return "♣️"
	elif num == 14:
		return "♥️"
	elif num == 15:
		return "♠️"
	elif num == 16:
		return "♦️"
	elif num >= 17 and num <= 20:
		return "S"
	return str(num) # Güvenlik için varsayılan

func add_new_round_results(tricks_won: Array, player_bids: Array, is_sanzoti: bool = false):
	# 1. Raunt ismini belirle (Sayı, koz veya S)
	var round_name = _get_round_display_name(current_round_num)
	_create_round_label(round_name)
	
	for idx in range(ui_order.size()):
		var i = ui_order[idx]
		var round_score = _calculate_round_score(tricks_won[i], player_bids[i], is_sanzoti)
		total_scores[i] += round_score
		# Son sütunda (en sağ) çizgi olmasın
		_create_score_label(round_score, idx < ui_order.size() - 1)
	
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
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size.x = RAUNT_SUTUN_GENISLIGI # 60
	
	# KRİTİK NOKTA: Tablonun büzüşmesini engeller
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("#b22222"))
	label.add_theme_stylebox_override("normal", _hucre_stili(true))   # R sütunu hep çizgili
	score_grid.add_child(label)

func _create_score_label(score: int, sag_cizgi: bool = true):
	var label = Label.new()
	label.text = str(score)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size.x = OYUNCU_SUTUN_GENISLIGI
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 32)
	if score == 0:
		label.add_theme_color_override("font_color", Color("#a0aec0"))
	else:
		label.add_theme_color_override("font_color", Color("#1a365d"))
	label.add_theme_stylebox_override("normal", _hucre_stili(sag_cizgi))
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
			
			# BURAYI DEĞİŞTİRİYORUZ: CENTER yerine LEFT yapıyoruz
			header_labels[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT 
			
			header_labels[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
func _hazirla_basliklar():
	if score_grid == null:
		return
	var hucreler = score_grid.get_children()
	for i in range(min(5, hucreler.size())):
		var lbl = hucreler[i]
		if lbl is Label:
			lbl.clip_text = true
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.custom_minimum_size.x = RAUNT_SUTUN_GENISLIGI if i == 0 else OYUNCU_SUTUN_GENISLIGI
			lbl.add_theme_stylebox_override("normal", _hucre_stili(i < 4))   # son sütun (Siz) çizgisiz
# Hücre için şeffaf arka plan + (istenirse) sağ kenarlık çizgisi
func _hucre_stili(sag_cizgi: bool) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.draw_center = false
	sb.content_margin_left = 0    # yazıyı soldan biraz içeri al (sol çizgiden ayrılsın)
	sb.content_margin_right = 14   # uzun yazı sağ çizgiye değmeden kırpılsın
	return sb
