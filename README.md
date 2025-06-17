# TodoBus 

TodoBus, Flutter ile geliştirilmiş kapsamlı bir proje ve görev yönetimi uygulamasıdır. 

## 📱 Uygulama Hakkında

**Sürüm:** 1.0.1  
**Platform:** iOS, Android  
**Framework:** Flutter 3.7.2+

TodoBus, kişisel ve takım görev yönetimini AI destekli akıllı özelliklerle birleştiren modern bir uygulamadır.

## ✨ Temel Özellikler

### 🔐 Kullanıcı Yönetimi
- **Güvenli Giriş/Kayıt Sistemi**: E-posta doğrulama ve şifre sıfırlama
- **"Beni Hatırla" Özelliği**: Kullanıcı e-posta adresini kaydetme
- **Hesap Yönetimi**: Profil güncelleme, hesap silme seçenekleri
- **Kullanıcı Dostu Hata Mesajları**: Geliştirilmiş hata yönetimi ve bilgilendirme

### 📊 Dashboard ve Ana Özellikler
- **Dinamik Dashboard**: Özelleştirilebilir widget düzeni ve sıralaması
- **Veri Yenileme**: Pull-to-refresh ile anlık veri güncelleme
- **Profil Fotoğrafı**: Resim yükleme ve düzenleme özellikleri
- **İstatistik Kartları**: Grup, proje ve görev sayıları
- **Bildirim Merkezi**: Okunmamış bildirim sayısı gösterimi

### 🤖 AI Assistant
- **Google Generative AI Entegrasyonu**: Akıllı asistan desteği
- **AI Chat Widget**: Dashboard'a entegre edilmiş chat arayüzü
- **Mesaj Yönetimi**: Mesaj kopyalama ve uzun basma desteği
- **Beta Özellikler**: E-posta kopyalama ve gelişmiş etkileşim

### 📱 Bildirim Sistemi
- **Firebase Cloud Messaging**: Gerçek zamanlı bildirimler
- **Arka Plan İşleme**: Uygulama kapalıyken bildirim yönetimi
- **Yerel Bildirimler**: Cihaz içi bildirim gösterimi
- **Topic Aboneliği**: Kullanıcı gruplarına göre bildirim yönetimi

### 👥 Grup ve Proje Yönetimi
- **Grup Oluşturma**: Takım projeler için grup oluşturma ve düzenleme
- **Proje Yönetimi**: Grup içinde proje oluşturma, düzenleme ve silme
- **Görev Takibi**: Kullanıcıya atanan görevlerin takibi
- **Kullanıcı Rolleri**: Farklı yetki seviyelerinde üye yönetimi
- **Proje Raporları**: Detaylı proje raporlama sistemi

### 📅 Takvim ve Etkinlikler
- **TableCalendar Entegrasyonu**: Aylık takvim görünümü
- **Etkinlik Yönetimi**: Etkinlik oluşturma, düzenleme ve silme
- **Cihaz Takvimi Entegrasyonu**: Sistem takvimi ile senkronizasyon
- **Hızlı Etkinlik Şablonları**: Toplantı, beyin fırtınası, eğitim gibi hazır şablonlar
- **Etkinlik Filtreleme**: Grup etkinlikleri, kullanıcı etkinlikleri ve şirket etkinlikleri

## 🔧 Teknik Düzeltmeler ve İyileştirmeler

### 📱 Platform Optimizasyonları
- **iOS 16.0 Uyumluluğu**: Minimum iOS sürümü güncellendi
- **Android SDK 35**: En son Android API desteği
- **Proguard Kuralları**: Android build optimizasyonları

### ⚡ Performans İyileştirmeleri
- **Splash Ekranı**: Native splash ekranı kaldırma süreci optimize edildi (3s → 500ms)
- **API Çağrıları**: FCM token güncelleme süresi kısaltıldı
- **Remote Config**: Fetch süresi 1 dakikadan 10 saniyeye düşürüldü
- **Widget Düzeni**: Daha az iç içe geçmiş widget yapısı

### 🛡️ Güvenlik ve Kararlılık
- **Batarya Optimizasyonu**: Android'de arka plan işlemleri için izin yönetimi
- **Ağ Güvenliği**: NSAppTransportSecurity ayarları
- **Hata Yönetimi**: Geliştirilmiş exception handling ve logging

### 🔗 Bağımlılık Yönetimi
- **Bağımlılık Güncellemeleri**: 
  - Firebase bileşenleri güncellendi
  - Connectivity Plus 4.0.2 → 6.1.4
  - File Picker 5.5.0 → 10.1.9
  - Flutter Local Notifications 16.3.3 → 17.2.4
- **Gereksiz Bağımlılıklar**: Add_2_calendar, animated_text_kit gibi kullanılmayan paketler kaldırıldı

### 🎨 UI/UX İyileştirmeleri
- **Bottom Navigation**: Arka plan rengi ve yükseklik ayarları
- **Modal Sayfalar**: Klavye etkileşimi ve güvenli alan kullanımı
- **Padding Optimizasyonları**: Grup görünümü ve filtre çiplerinde spacing iyileştirmeleri
- **IconButton Geçişi**: GestureDetector'dan IconButton'a geçiş (tooltip desteği)

## 🚀 Kurulum

```bash
# Depoyu klonlayın
git clone [repository-url]

# Bağımlılıkları yükleyin
flutter pub get

# Uygulamayı çalıştırın
flutter run
```

## 📋 Gereksinimler

- Flutter SDK 3.7.2+
- Dart SDK
- iOS 16.0+ / Android API 21+
- Firebase hesabı (FCM, Remote Config için)
- Google AI API anahtarı (AI Assistant için)

## 🔐 Yapılandırma

1. `.env` dosyasını oluşturun ve `GEMINI_API_KEY` ekleyin
2. Firebase yapılandırma dosyalarını (`google-services.json`, `GoogleService-Info.plist`) ekleyin
3. AI Assistant için Google Generative AI API anahtarını yapılandırın

## 📱 Ekranlar ve Özellikler

### Ana Ekranlar
- **Login/Register**: Kullanıcı girişi ve kayıt
- **Dashboard**: Ana sayfa ve widget yönetimi
- **Profile**: Kullanıcı profili ve ayarlar
- **Groups**: Grup listesi ve yönetimi
- **Events**: Takvim ve etkinlik yönetimi
- **Notifications**: Bildirim merkezi
- **AI Chat**: AI Assistant sohbet ekranı

### Detay Ekranları
- **Group Detail**: Grup detayları ve proje listesi
- **Project Detail**: Proje detayları ve görev yönetimi
- **Event Detail**: Etkinlik detayları ve takvim entegrasyonu
- **Work Detail**: Görev detayları ve düzenleme
- **Report Views**: Proje raporları ve analitik

### Oluşturma/Düzenleme Ekranları
- **Create/Edit Group**: Grup oluşturma ve düzenleme
- **Create/Edit Project**: Proje oluşturma ve düzenleme
- **Create/Edit Event**: Etkinlik oluşturma ve düzenleme
- **Add/Edit Work**: Görev ekleme ve düzenleme
- **Create Report**: Rapor oluşturma

## 📝 Lisans

Bu proje özel bir projedir ve halka açık yayınlanmamıştır.

---

**Son Güncelleme:** Aralık 2024  
**Geliştirici:** [Geliştirici Adı]
