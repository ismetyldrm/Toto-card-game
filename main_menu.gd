extends Control

const GAME_SCENE_PATH = "res://main.tscn" 

const ODA_AC_POPUP_SCENE = preload("res://material/OdaAc.tscn")
const ODA_BUL_POPUP_SCENE = preload("res://Scenes/OdaBul.tscn")

var active_oda_ac_popup = null
var active_oda_bul_popup = null

@onready var tutorial_panel = $TutorialPanel
@onready var rules_text = $TutorialPanel/RulesText
@onready var page_label = $TutorialPanel/RulesText/PageLabel
@onready var btn_ileri = $TutorialPanel/RulesText/BtnIleri
@onready var btn_geri = $TutorialPanel/RulesText/BtnGeri

var current_page = 0
var tutorial_pages = [
	"[center][b]1. TOTO NEDİR ve KART DAĞITIMI[/b]\n\nToto, her koyunun kendi bacağından asıldığı stratejik bir ihale (batak) oyunudur. Oyun toplam 20 raunt sürer.\n\nİlk 12 raunt boyunca oyunculara raunt sayısı kadar kart dağıtılır (1. rauntta 1 kart, 12. rauntta 12 kart). 13-16. rauntlar 13'er kartla oynanan sabit koz (Sinek, Kupa, Maça, Karo) rauntlarıdır. Son 4 raunt (17-20) ise 'Sanzoti' yani kozsuz oynanır.[/center]",
	
	"[center][b]2. İHALE (TAHMİN) AŞAMASI[/b]\n\nKartlar dağıtıldıktan sonra her oyuncu eline bakar ve o raunt 'tam olarak kaç el alacağını' tahmin eder. Bu tahminler skor tablosuna yazılır.\n\nOyunun temel amacı: Ne eksik ne de fazla, tam olarak tahmin ettiğin sayı kadar el almaktır![/center]",
	
	"[center][b]3. OYNANIŞ VE RENK TAKİBİ[/b]\n\nSırası gelen oyuncu yere bir kart atar. Diğer oyuncular yerdeki rengi (Lead Suit) takip etmek ZORUNDADIR. \n\nEğer elinde o renkten yoksa ve oyun Sanzoti değilse, KOZ çakmak zorundadır. Koz da yoksa istediği kartı atabilir. Yerdeki en büyük kartı atan o eli kazanır.[/center]",
	
	"[center][b]4. PUANLAMA (YAZBOZ) SİSTEMİ[/b]\n\nRaunt sonunda:\n- Tahminini tam tutturan (ÇIKAN) oyuncu: (Tahmin x Tahmin) + 10 Puan kazanır.\n- Tahmininden eksik veya fazla el alan (BATAN) oyuncu: 0 Puan alır.\n\n*ÖZEL KURAL: Sanzoti rauntlarında '0' diyen oyuncu batmazsa 35 puan kazanır![/center]",
	
	"[center][b]5. OYUN SONU VE KAZANMA ŞARTI[/b]\n\n20. Raunt bittikten sonra tüm oyuncuların puanları toplanır ve 4'e bölünerek oyunun 'Ortalama Puanı' bulunur.\n\nKlasik oyunların aksine Toto'da tek bir birinci yoktur. Ortalama puana EŞİT veya ondan DAHA YÜKSEK puan alan tüm oyuncular oyunu kazanmış (ÇIKMIŞ) sayılır![/center]"
]

func _ready() -> void:
	$VBoxContainer/Button.grab_focus()
	# Oyun başlarken paneli gizle
	if tutorial_panel:
		tutorial_panel.hide()

func _on_hizli_oyun_pressed() -> void:
	print("Hızlı Oyun başlatılıyor...")
	NetworkManager.game_mode = NetworkManager.GameMode.SINGLEPLAYER
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		print("HATA: Sahne dosyası bulunamadı! GAME_SCENE_PATH değişkenini kontrol et.")
		
func _on_oda_ara_pressed() -> void:
	print("Oda Ara penceresi açılıyor...")
	_clear_popups()
	
	# Oda Bul sahnesini canlandırıp (instantiate) ekrana ekliyoruz
	active_oda_bul_popup = ODA_BUL_POPUP_SCENE.instantiate()
	add_child(active_oda_bul_popup)
	active_oda_bul_popup.show()

# main_menu.gd dosyanın içindeki ilgili kısım:


func _on_oda_aç_pressed() -> void:
	print("Oda Aç penceresi açılıyor...")
	
	if is_instance_valid(active_oda_ac_popup):
		active_oda_ac_popup.queue_free()
	
	active_oda_ac_popup = ODA_AC_POPUP_SCENE.instantiate()
	add_child(active_oda_ac_popup)
	
	active_oda_ac_popup.set_anchors_preset(Control.PRESET_CENTER)

func _on_cikis_pressed() -> void:
	print("Oyundan çıkılıyor. Görüşmek üzere!")
	get_tree().quit()

# Pencerelerin üst üste binmesini engelleyen temizlik fonksiyonu
func _clear_popups():
	if is_instance_valid(active_oda_ac_popup):
		active_oda_ac_popup.queue_free()
	if is_instance_valid(active_oda_bul_popup):
		active_oda_bul_popup.queue_free()


# "Nasıl Oynanır?" Butonu (Senin Button6 dediğin buton)
func _on_button_6_pressed() -> void:
	print("Nasıl Oynanır penceresi açılıyor...")
	_clear_popups() # Diğer popupları temizle
	
	current_page = 0
	_update_tutorial_screen()
	tutorial_panel.show()
	
func _update_tutorial_screen():
	# Bbcode (Kalın yazı vb.) desteğini açıp metni basıyoruz
	rules_text.bbcode_enabled = true
	rules_text.text = tutorial_pages[current_page]
	
	# Sayfa numarasını güncelle (Örn: 1 / 5)
	page_label.text = str(current_page + 1) + " / " + str(tutorial_pages.size())
	
	# İlk sayfadaysak Geri butonunu, son sayfadaysak İleri butonunu kilitle
	btn_geri.disabled = (current_page == 0)
	btn_ileri.disabled = (current_page == tutorial_pages.size() - 1)


func _on_btn_ileri_pressed() -> void:
	if current_page < tutorial_pages.size() - 1:
		current_page += 1
		_update_tutorial_screen()

func _on_btn_geri_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		_update_tutorial_screen()

func _on_btn_kapat_pressed() -> void:
	tutorial_panel.hide()
