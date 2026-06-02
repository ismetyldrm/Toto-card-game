extends PanelContainer

# Arayüz Katmanlarının Referansları
@onready var isim_giris_ekrani: VBoxContainer = $"IsimGirisEkranı"
@onready var bekleme_ekrani: VBoxContainer = $BeklemeEkrani
@onready var room_name_field: LineEdit = $"IsimGirisEkranı/LineEdit"
@onready var username_field: LineEdit = $"IsimGirisEkranı/LineEdit2"
@onready var nokta1: Label = $"BeklemeEkrani/Noktalar Kutusu/Nokta1"
@onready var nokta2: Label = $"BeklemeEkrani/Noktalar Kutusu/Nokta2"
@onready var nokta3: Label = $"BeklemeEkrani/Noktalar Kutusu/Nokta3"
@onready var iptal_button: Button = $BeklemeEkrani/Button

var animasyon_tween : Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	isim_giris_ekrani.show()
	bekleme_ekrani.hide()
	if not iptal_button.is_connected("pressed", _on_oda_iptal_button_pressed):
		iptal_button.connect("pressed", _on_oda_iptal_button_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# OdaAcPopup.gd içindeki onay buton fonksiyonu:
func _on_kur_confirm_button_pressed() -> void:
	var oda_adi = room_name_field.text
	if oda_adi == "":
		oda_adi = "Gardaşlar"
		
	
	var kullanici_adi = username_field.text.strip_edges()
	if kullanici_adi == "":
		kullanici_adi = "Ev Sahibi"
	NetworkManager.local_player_name = kullanici_adi
	var basarili = NetworkManager.create_room(oda_adi)

	if basarili:
		isim_giris_ekrani.hide()
		bekleme_ekrani.show()
		
		# --- İLK AÇILIŞ DEĞERİNİ YAZIYORUZ ---
		if bekleme_ekrani.has_node("OyuncuSayisiLabel"):
			bekleme_ekrani.get_node("OyuncuSayisiLabel").text = "Oyuncu Sayısı: 1 / 4"
		elif bekleme_ekrani.has_node("PanelContainer/BeklemeEkrani/OyuncuSayisiLabel"):
			bekleme_ekrani.get_node("PanelContainer/BeklemeEkrani/OyuncuSayisiLabel").text = "Oyuncu Sayısı: 1 / 4"
			
		start_dots_animation()

func _on_oda_iptal_button_pressed() -> void:
	if animasyon_tween:
		animasyon_tween.kill()

	if multiplayer.multiplayer_peer and multiplayer.is_server():
		NetworkManager.host_close_room()   # client'lara haber ver + kapat
	else:
		NetworkManager.return_to_main_menu()
	
# --- Sonsuz Döngü Dalga Animasyonu ---
func start_dots_animation():
	nokta1.modulate.a = 0.0
	nokta2.modulate.a = 0.0
	nokta3.modulate.a = 0.0
	
	animasyon_tween = create_tween()
	animasyon_tween.set_loops() # Sonsuz döngü emri
	
	animasyon_tween.tween_property(nokta1, "modulate:a", 1.0, 0.3)
	animasyon_tween.tween_property(nokta1, "modulate:a", 0.0, 0.3).set_delay(0.5)
	
	# 2. Nokta Giriş/Çıkış (Parallel akış ile iç içe geçme)
	animasyon_tween.parallel().tween_property(nokta2, "modulate:a", 1.0, 0.3).set_delay(0.2)
	animasyon_tween.parallel().tween_property(nokta2, "modulate:a", 0.0, 0.3).set_delay(0.7)
	
	# 3. Nokta Giriş/Çıkış
	animasyon_tween.parallel().tween_property(nokta3, "modulate:a", 1.0, 0.3).set_delay(0.4)
	animasyon_tween.parallel().tween_property(nokta3, "modulate:a", 0.0, 0.3).set_delay(0.9)
	
	# Döngü sonu pürüzsüz bekleme aralığı
	animasyon_tween.tween_interval(0.3)
	
	
	
	
