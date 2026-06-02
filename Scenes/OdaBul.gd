extends PanelContainer

# 1. Adımda oluşturduğun oda satırı şablonunu koda tanıtıyoruz
const ODA_SATIRI_SCENE = preload("res://material/OdaSatiri.tscn")

# --- Arayüz Katmanlarının Referansları ---
@onready var ana_icerik_kutusu: VBoxContainer = $MarginContainer/VBoxContainer
@onready var katil_bekleme_ekrani: VBoxContainer = $MarginContainer/KatilBeklemeEkrani

# YENİ: İsim Giriş Katmanları ve VBox İÇİNDEKİ Butonun Referansı
@onready var isim_giris_ekrani: VBoxContainer = $MarginContainer/IsimGirisEkrani
@onready var oyuncu_isim_field: LineEdit = $MarginContainer/IsimGirisEkrani/OyuncuIsmiField
@onready var katil_onay_button: Button = $MarginContainer/IsimGirisEkrani/KatilOnayButton

# Noktaların Referansları (Animasyon için)
@onready var nokta1: Label = $MarginContainer/KatilBeklemeEkrani/NoktalarKutusu/nokta1
@onready var nokta2: Label = $MarginContainer/KatilBeklemeEkrani/NoktalarKutusu/nokta2
@onready var nokta3: Label = $MarginContainer/KatilBeklemeEkrani/NoktalarKutusu/nokta3

@onready var oda_listesi_kutusu: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var iptal_button: Button = $MarginContainer/VBoxContainer/OdaBulIptalButton
@onready var katil_bekleme_iptal_button: Button = $MarginContainer/KatilBeklemeEkrani/KatilBeklemeIptalButton

var animasyon_tween: Tween
var yenileme_timer: Timer
var secilen_oda_ip: String = "" # Tıklanan odanın IP adresini tutacak güvenli hafıza alanı

func _ready() -> void:
	ana_icerik_kutusu.show()
	katil_bekleme_ekrani.hide()
	isim_giris_ekrani.hide()   # İlk açılışta isim sorma ekranını gizliyoruz
	
	# Sinyal bağlantılarını kod güvencesine alıyoruz
	if iptal_button and not iptal_button.is_connected("pressed", _on_oda_bul_iptal_button_pressed):
		iptal_button.connect("pressed", _on_oda_bul_iptal_button_pressed)
	if katil_bekleme_iptal_button and not katil_bekleme_iptal_button.is_connected("pressed", _on_oda_bul_iptal_button_pressed):
		katil_bekleme_iptal_button.connect("pressed", _on_oda_bul_iptal_button_pressed)
	
	# YENİ: VBox içindeki onay butonunun tıklama sinyalini bağlıyoruz
	if katil_onay_button and not katil_onay_button.is_connected("pressed", _on_katil_onay_button_pressed):
		katil_onay_button.connect("pressed", _on_katil_onay_button_pressed)
		
	# UDP dinlemesini başlat
	NetworkManager.start_searching_rooms()
	
	# Arayüzü yarım saniyede bir güncelleyecek bir Timer kuruyoruz
	yenileme_timer = Timer.new()
	yenileme_timer.wait_time = 0.5
	yenileme_timer.autostart = true
	yenileme_timer.timeout.connect(listeyi_guncelle)
	add_child(yenileme_timer)

func listeyi_guncelle():
	if NetworkManager.has_method("_listen_for_rooms"):
		NetworkManager._listen_for_rooms()

	var bulunan_odalar = NetworkManager.active_rooms
	
	if oda_listesi_kutusu.get_child_count() == bulunan_odalar.size() and bulunan_odalar.size() > 0:
		var index = 0
		for ip in bulunan_odalar.keys():
			var satir = oda_listesi_kutusu.get_child(index)
			var oda_verisi = bulunan_odalar[ip]
			if satir.has_node("OdaAdiLabel"):
				satir.get_node("OdaAdiLabel").text = oda_verisi["room_name"]
			if satir.has_node("OyuncuSayisiLabel"):
				satir.get_node("OyuncuSayisiLabel").text = "Oyuncu Sayısı: " + oda_verisi["players"]
			index += 1
		return

	for child in oda_listesi_kutusu.get_children():
		child.queue_free()
	
	for ip in bulunan_odalar.keys():
		var oda_verisi = bulunan_odalar[ip]
		var yeni_satir = ODA_SATIRI_SCENE.instantiate()
		
		if yeni_satir.has_node("OdaAdiLabel"):
			yeni_satir.get_node("OdaAdiLabel").text = oda_verisi["room_name"]
			
		if yeni_satir.has_node("OyuncuSayisiLabel"):
			yeni_satir.get_node("OyuncuSayisiLabel").text = "Oyuncu Sayısı: " + oda_verisi["players"]
			
		var katil_btn = yeni_satir.get_node("KatilButton") if yeni_satir.has_node("KatilButton") else yeni_satir.get_child(2)
		if katil_btn and not katil_btn.is_connected("pressed",  _on_katil_pressed):
			katil_btn.connect("pressed", func(): _on_katil_pressed(ip))
			
		oda_listesi_kutusu.add_child(yeni_satir)

func _on_katil_pressed(oda_ip: String):
	secilen_oda_ip = oda_ip          # sadece IP'yi hafızaya al
	ana_icerik_kutusu.hide()
	isim_giris_ekrani.show()
	oyuncu_isim_field.grab_focus()   # opsiyonel: imleç direkt isim kutusuna gelsin

# --- 2. ADIM: VBOX İÇİNDEKİ "BAĞLAN" BUTONUNA BASILDIĞINDA ---
func _on_katil_onay_button_pressed():
	var nick_name = oyuncu_isim_field.text
	if nick_name == "":
		nick_name = "Misafir Oyuncu" # Boş bırakılırsa default isim
	
	# İleride kullanmak üzere ismi NetworkManager'a kaydediyoruz
	if "local_player_name" in NetworkManager:
		NetworkManager.local_player_name = nick_name
		
	# Gerçek bağlantıyı tetikliyoruz
	var basarili = NetworkManager.join_room(secilen_oda_ip)
	
	if basarili:
		print(nick_name, " ismiyle odaya bağlantı isteği gönderildi...")
		isim_giris_ekrani.hide()
		katil_bekleme_ekrani.show()
		start_dots_animation()

func _on_oda_bul_iptal_button_pressed() -> void:
	if is_instance_valid(animasyon_tween):
		animasyon_tween.kill()
	NetworkManager.return_to_main_menu()
	
func start_dots_animation():
	nokta1.modulate.a = 0.0
	nokta2.modulate.a = 0.0
	nokta3.modulate.a = 0.0
	
	animasyon_tween = create_tween()
	animasyon_tween.set_loops()
	
	animasyon_tween.tween_property(nokta1, "modulate:a", 1.0, 0.3)
	animasyon_tween.tween_property(nokta1, "modulate:a", 0.0, 0.3).set_delay(0.5)
	
	animasyon_tween.parallel().tween_property(nokta2, "modulate:a", 1.0, 0.3).set_delay(0.2)
	animasyon_tween.parallel().tween_property(nokta2, "modulate:a", 0.0, 0.3).set_delay(0.7)
	
	animasyon_tween.parallel().tween_property(nokta3, "modulate:a", 1.0, 0.3).set_delay(0.4)
	animasyon_tween.parallel().tween_property(nokta3, "modulate:a", 0.0, 0.3).set_delay(0.9)
	
	animasyon_tween.tween_interval(0.3)
