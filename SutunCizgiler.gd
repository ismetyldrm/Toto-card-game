extends Control
# Tablo sütun çizgilerini tam yükseklikte çizer

@export var score_grid: GridContainer
@export var scroll_container: ScrollContainer
@export var cizgi_renk: Color = Color("#333333")
@export var cizgi_kalinlik: float = 2.0

func _process(_delta):
	queue_redraw()   # layout/scroll değişince çizgiler güncellensin

func _draw():
	if score_grid == null or scroll_container == null:
		return
	var hucreler = score_grid.get_children()
	if hucreler.size() < 5:
		return
	# Çizgiler tablo alanının tepesinden dibine kadar
	var ust = scroll_container.global_position.y - global_position.y
	var alt = ust + scroll_container.size.y
	# İlk 5 hücre = başlık satırı. R, P1, P2, P3'ün sağ sınırı (Siz hariç → 4 çizgi)
	for i in range(4):
		var hucre = hucreler[i]
		if hucre is Control:
			var sinir_x = score_grid.global_position.x + hucre.position.x + hucre.size.x
			var yerel_x = sinir_x - global_position.x
			draw_line(Vector2(yerel_x, ust), Vector2(yerel_x, alt), cizgi_renk, cizgi_kalinlik)
