import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import 'group_detail_view.dart';

class EventDetailPage extends StatefulWidget {
  final int groupId;
  final String eventTitle;
  final String eventDescription;
  final String eventDate;
  final String eventUser;
  
  const EventDetailPage({
    Key? key,
    required this.groupId,
    required this.eventTitle,
    required this.eventDescription,
    required this.eventDate,
    required this.eventUser,
  }) : super(key: key);

  @override
  _EventDetailPageState createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final LoggerService _logger = LoggerService();
  final ApiService _apiService = ApiService();
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  
  bool _isLoading = false;
  bool _isDisposed = false;
  bool _isLoadingCalendars = false;
  String _errorMessage = '';
  GroupDetail? _groupDetail;
  List<Calendar>? _calendars;
  Calendar? _selectedCalendar;
  List<Event>? _calendarEvents;
  
  @override
  void initState() {
    super.initState();
    // Timezone verisini başlat
    try {
      tz.initializeTimeZones();
    } catch (e) {
      _logger.e('Timezone başlatma hatası: $e');
    }
    _loadGroupDetail();
    _requestCalendarPermissions();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
  
  // Güvenli setState
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }
  
  // Takvim izinlerini isteme
  Future<void> _requestCalendarPermissions() async {
    _safeSetState(() {
      _isLoadingCalendars = true;
    });
    
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          _safeSetState(() {
            _isLoadingCalendars = false;
          });
          return;
        }
      }
      
      // Takvimleri yükle
      await _retrieveCalendars();
    } catch (e) {
      _logger.e('Takvim izinleri alınırken hata: $e');
      _safeSetState(() {
        _isLoadingCalendars = false;
      });
    }
  }
  
  // Takvimleri getirme
  Future<void> _retrieveCalendars() async {
    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      
      _safeSetState(() {
        // Sadece yazılabilir takvimleri filtrele
        _calendars = calendarsResult.data?.where((calendar) => 
          calendar.isReadOnly != true).toList();
        _isLoadingCalendars = false;
        
        // Varsayılan takvimi seç (varsa)
        if (_calendars != null && _calendars!.isNotEmpty) {
          // Önce kullanıcı varsayılan takvimini bulmaya çalış
          _selectedCalendar = _calendars!.firstWhere(
            (calendar) => calendar.isDefault ?? false,
            orElse: () => _calendars!.first,
          );
        }
      });
    } catch (e) {
      _logger.e('Takvimler yüklenirken hata: $e');
      _safeSetState(() {
        _isLoadingCalendars = false;
      });
    }
  }
  
  // Seçili takvimden etkinlikleri getirme
  Future<void> _retrieveEvents() async {
    if (_selectedCalendar == null) return;
    
    _safeSetState(() {
      _isLoading = true;
    });
    
    try {
      // Bu hafta için etkinlikleri getir
      final DateTime now = DateTime.now();
      final DateTime startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      final DateTime endDate = startDate.add(const Duration(days: 14)); // iki haftalık pencere
      
      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        _selectedCalendar!.id,
        RetrieveEventsParams(startDate: startDate, endDate: endDate)
      );
      
      _safeSetState(() {
        _calendarEvents = eventsResult.data;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Etkinlikler yüklenirken hata: $e');
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }
  
  // Seçili takvime etkinlik ekleme
  Future<void> _addEventToCalendar() async {
    if (_selectedCalendar == null) {
      _showCalendarSelectionDialog();
      return;
    }
    
    try {
      // Takvimin salt okunur olup olmadığını kontrol et
      if (_selectedCalendar!.isReadOnly == true) {
        _showMessage('${_selectedCalendar!.name} takvimi salt okunur, etkinlik eklenemez');
        return;
      }
      
      // Etkinlik tarihini parse etme
      final DateTime? eventDateTime = _parseEventDate(widget.eventDate);
      if (eventDateTime == null) {
        _showMessage('Etkinlik tarihi doğru formatta değil');
        return;
      }
      
      _logger.i('Etkinlik ekleme başlatılıyor - Seçili takvim: ${_selectedCalendar!.name}, ID: ${_selectedCalendar!.id}');
      
      // Bitiş tarihi (varsayılan olarak 1 saat sonra)
      final DateTime endDate = eventDateTime.add(const Duration(hours: 1));
      
      try {
        // DateTime'ı TZDateTime'a dönüştür
        final tz.TZDateTime tzStart = tz.TZDateTime.from(eventDateTime, tz.local);
        final tz.TZDateTime tzEnd = tz.TZDateTime.from(endDate, tz.local);
        
        _logger.i('Dönüştürülen TZDateTime - Başlangıç: $tzStart, Bitiş: $tzEnd');
        
        // Takvimine eklenecek etkinlik
        final event = Event(
          _selectedCalendar!.id,
          title: widget.eventTitle,
          description: widget.eventDescription,
          start: tzStart,
          end: tzEnd,
          allDay: false,
        );
        
        _logger.i('Oluşturulan etkinlik: ${event.title}, tarih: ${event.start} - ${event.end}');
        
        // Etkinliği takvime ekle
        final createEventResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
        
        _logger.i('Takvim yanıtı - Başarılı: ${createEventResult?.isSuccess}, Veri: ${createEventResult?.data}');
        
        if (createEventResult?.isSuccess == true) {
          if (createEventResult?.data != null) {
            _showMessage('Etkinlik takvime başarıyla eklendi');
          } else {
            _showMessage('Etkinlik eklenmiş olabilir ancak doğrulama alınamadı');
          }
        } else {
          // Hatanın PlatformException olup olmadığını kontrol et ve daha anlamlı mesaj göster
          final String errorMessage = createEventResult?.errors.join(", ") ?? "Bilinmeyen hata";
          _logger.e('Takvim hatası: $errorMessage');
          
          if (errorMessage.isEmpty) {
            // Bazen boş hata mesajı gelse bile aslında başarılı olabilir
            _showMessage('Etkinlik takvime eklendi');
          } else if (errorMessage.contains('read-only')) {
            _showMessage('Bu takvim salt okunur, etkinlik eklenemez');
          } else if (errorMessage.contains('permission')) {
            _showMessage('Takvim izinleri yetersiz, lütfen izinleri kontrol edin');
          } else {
            _showMessage('Etkinlik takvime eklenemedi: $errorMessage');
          }
        }
      } catch (innerError) {
        _logger.e('TZDateTime dönüşümü veya etkinlik oluşturma hatası: $innerError');
        _showMessage('Tarih dönüşümü sırasında hata oluştu, lütfen tekrar deneyin');
      }
    } catch (e) {
      _logger.e('Etkinlik eklenirken genel hata: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('read-only')) {
        _showMessage('Bu takvim salt okunur, etkinlik eklenemez');
      } else if (errorMessage.contains('permission')) {
        _showMessage('Takvim izinleri yetersiz, lütfen ayarlardan izin verin');
      } else {
        _showMessage('Etkinlik eklenirken hata oluştu: $e');
      }
    }
  }
  
  // Takvim seçme dialogu
  void _showCalendarSelectionDialog() {
    if (_calendars == null || _calendars!.isEmpty) {
      _showMessage('Kullanılabilir yazılabilir takvim bulunamadı');
      return;
    }
    
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Takvim Seçin'),
          message: const Text('Etkinlik eklemek istediğiniz takvimi seçin'),
          actions: _calendars!.map((calendar) {
            return CupertinoActionSheetAction(
              onPressed: () {
                _safeSetState(() {
                  _selectedCalendar = calendar;
                });
                Navigator.of(context).pop();
                _addEventToCalendar();
              },
              child: Text(calendar.name ?? 'Takvim'),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            isDestructiveAction: true,
            child: const Text('İptal'),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Takvim Seçin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _calendars!.map((calendar) {
                return ListTile(
                  title: Text(calendar.name ?? 'Takvim'),
                  subtitle: Text(calendar.accountName ?? ''),
                  onTap: () {
                    _safeSetState(() {
                      _selectedCalendar = calendar;
                    });
                    Navigator.of(context).pop();
                    _addEventToCalendar();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        ),
      );
    }
  }
  
  // Takvimdeki etkinlikleri gösteren sayfa
  void _showCalendarEvents() async {
    if (_calendars == null || _calendars!.isEmpty) {
      _requestCalendarPermissions();
      return;
    }
    
    if (_selectedCalendar == null) {
      _showCalendarSelectionForView();
      return;
    }
    
    // Etkinlikleri yüklememişsek yükleyelim
    if (_calendarEvents == null) {
      await _retrieveEvents();
    }
    
    if (!mounted) return;
    
    final bool isIOS = Platform.isIOS;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isIOS ? CupertinoColors.systemBackground : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve kapat butonu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isIOS ? CupertinoColors.systemBackground : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Takvimdeki Etkinlikler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isIOS ? CupertinoColors.label : Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isIOS ? CupertinoColors.systemFill : Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIOS ? CupertinoIcons.xmark : Icons.close,
                        size: 20,
                        color: isIOS ? CupertinoColors.label : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Seçili takvim
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedCalendar?.name ?? 'Takvim',
                    style: TextStyle(
                      fontSize: 16,
                      color: isIOS ? CupertinoColors.label : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showCalendarSelectionForView,
                    child: Text(
                      'Değiştir',
                      style: TextStyle(
                        fontSize: 14,
                        color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Etkinlik listesi
            Expanded(
              child: _isLoading
                  ? Center(child: PlatformCircularProgressIndicator())
                  : _calendarEvents == null || _calendarEvents!.isEmpty
                      ? const Center(child: Text('Bu takvimde etkinlik bulunamadı'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _calendarEvents!.length,
                          itemBuilder: (context, index) {
                            final event = _calendarEvents![index];
                            return _buildEventListItem(event);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Görüntüleme için takvim seçme
  void _showCalendarSelectionForView() {
    if (_calendars == null || _calendars!.isEmpty) {
      _showMessage('Kullanılabilir takvim bulunamadı');
      return;
    }
    
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Takvim Seçin'),
          message: const Text('Görüntülemek istediğiniz takvimi seçin'),
          actions: _calendars!.map((calendar) {
            return CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(context).pop();
                _safeSetState(() {
                  _selectedCalendar = calendar;
                  _calendarEvents = null; // Yeni takvim seçildiği için etkinlikleri temizle
                });
                await _retrieveEvents();
                _showCalendarEvents();
              },
              child: Text(calendar.name ?? 'Takvim'),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            isDestructiveAction: true,
            child: const Text('İptal'),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Takvim Seçin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _calendars!.map((calendar) {
                return ListTile(
                  title: Text(calendar.name ?? 'Takvim'),
                  subtitle: Text(calendar.accountName ?? ''),
                  onTap: () async {
                    Navigator.of(context).pop();
                    _safeSetState(() {
                      _selectedCalendar = calendar;
                      _calendarEvents = null; // Yeni takvim seçildiği için etkinlikleri temizle
                    });
                    await _retrieveEvents();
                    _showCalendarEvents();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        ),
      );
    }
  }
  
  // Etkinlik listesi öğesi
  Widget _buildEventListItem(Event event) {
    final bool isIOS = Platform.isIOS;
    final bool isAllDay = event.allDay ?? false;
    
    final String timeText = isAllDay
        ? 'Tüm gün'
        : '${_formatTime(event.start)} - ${_formatTime(event.end)}';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isIOS ? 0 : 2,
      child: Container(
        decoration: isIOS
            ? BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border.all(color: CupertinoColors.systemGrey5),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: ListTile(
          title: Text(
            event.title ?? 'İsimsiz Etkinlik',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isIOS ? CupertinoIcons.time : Icons.access_time,
                    size: 14,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 13,
                      color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  event.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[800],
                  ),
                ),
              ],
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
  
  // Saat formatı
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  Future<void> _loadGroupDetail() async {
    _safeSetState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // GroupID=0 ise grup detayı yüklemeye gerek yok
      if (widget.groupId == 0) {
        _safeSetState(() {
          _isLoading = false;
        });
        return;
      }
      
      final groupDetail = await _apiService.group.getGroupDetail(widget.groupId);
      
      if (mounted && !_isDisposed) {
        _safeSetState(() {
          _groupDetail = groupDetail;
          _isLoading = false;
        });
        
        _logger.i('Grup ve etkinlik detayları yüklendi: ${groupDetail.groupName}');
      }
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Grup detayları yüklenemedi: $e';
        _isLoading = false;
      });
      
      _logger.e('Grup detayları yüklenirken hata: $e');
    }
  }
  
  void _goToGroupDetail() {
    // GroupID=0 ise gruba gitmeye gerek yok
    if (widget.groupId == 0) {
      return;
    }
    
    Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => GroupDetailView(
          groupId: widget.groupId,
        ),
      ),
    );
  }
  
  // Takvime ekleme fonksiyonu - bu fonksiyonu takvim seçme ve ekleme işlevi için kullanıyoruz
  Future<void> _addToCalendar() async {
    _addEventToCalendar();
  }
  
  // Google Takvim için RFC 5545 formatında tarih formatı
  String _formatDateForCalendar(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String()
      .replaceAll('-', '')
      .replaceAll(':', '')
      .substring(0, 15) + 'Z';
  }
  
  // Etkinlik tarihini parse etme yardımcı metodu
  DateTime? _parseEventDate(String dateStr) {
    try {
      _logger.i('Ayrıştırılacak tarih: $dateStr');
      
      // Boş kontrol
      if (dateStr.trim().isEmpty) {
        _logger.e('Tarih boş');
        return DateTime.now(); // Şu anki zamanı kullan
      }
      
      // ISO formatındaki tarihi doğrudan parse etme (2025-05-22 17:26:00.000)
      // Bu format veritabanından geliyorsa önce bunu deneyelim
      try {
        final DateTime parsedDate = DateTime.parse(dateStr);
        _logger.i('ISO formatında tarih başarıyla ayrıştırıldı: $parsedDate');
        return parsedDate;
      } catch (e) {
        _logger.i('ISO formatında tarih değil, diğer formatları deniyorum');
        // ISO formatı değilse, diğer formatları deneyeceğiz
      }
      
      // Türkçe ay isimleri
      final Map<String, int> monthNames = {
        'ocak': 1, 'şubat': 2, 'mart': 3, 'nisan': 4,
        'mayıs': 5, 'haziran': 6, 'temmuz': 7, 'ağustos': 8,
        'eylül': 9, 'ekim': 10, 'kasım': 11, 'aralık': 12,
      };
      
      // Tarih ve saat patternleri
      // ISO formatı (YYYY-MM-DD)
      final RegExp isoDatePattern = RegExp(
        r'(\d{4})-(\d{1,2})-(\d{1,2})([ T](\d{1,2}):(\d{2})(:(\d{2}))?)?',
        caseSensitive: false
      );
      
      // Tam tarih ve saat (örn: 15.06.2023 14:30)
      final RegExp fullDateTimePattern = RegExp(
        r'(\d{1,2})[\/\.\-\s](\d{1,2}|[a-zA-ZğüşıöçĞÜŞİÖÇ]+)[\/\.\-\s](\d{4})[\s,]*(\d{1,2})[:\.](\d{2})',
        caseSensitive: false
      );
      
      final RegExp dateOnlyPattern = RegExp(
        r'(\d{1,2})[\/\.\-\s](\d{1,2}|[a-zA-ZğüşıöçĞÜŞİÖÇ]+)[\/\.\-\s](\d{4})',
        caseSensitive: false
      );
      
      final RegExp timeOnlyPattern = RegExp(
        r'(\d{1,2})[:\.](\d{2})',
        caseSensitive: false
      );
      
      _logger.i('Tarih ayrıştırma başlatılıyor...');
      
      // ISO formatı (YYYY-MM-DD)
      final isoMatch = isoDatePattern.firstMatch(dateStr);
      if (isoMatch != null) {
        _logger.i('ISO formatı eşleşmesi bulundu: ${isoMatch.group(0)}');
        
        int year = int.parse(isoMatch.group(1)!);
        int month = int.parse(isoMatch.group(2)!);
        int day = int.parse(isoMatch.group(3)!);
        
        int hour = 0;
        int minute = 0;
        int second = 0;
        
        // Saat bilgisi varsa
        if (isoMatch.group(5) != null && isoMatch.group(6) != null) {
          hour = int.parse(isoMatch.group(5)!);
          minute = int.parse(isoMatch.group(6)!);
          
          if (isoMatch.group(8) != null) {
            second = int.parse(isoMatch.group(8)!);
          }
        }
        
        _logger.i('Ayrıştırılan ISO tarihi: $year-$month-$day $hour:$minute:$second');
        return DateTime(year, month, day, hour, minute, second);
      }
      
      // Tam tarih ve saat (örn: 15.06.2023 14:30)
      final fullMatch = fullDateTimePattern.firstMatch(dateStr);
      if (fullMatch != null) {
        _logger.i('Tam tarih-saat eşleşmesi bulundu: ${fullMatch.group(0)}');
        
        int day = int.parse(fullMatch.group(1)!);
        int month;
        final monthPart = fullMatch.group(2)!;
        
        // Ay sayı mı yoksa isim mi?
        if (RegExp(r'^\d+$').hasMatch(monthPart)) {
          month = int.parse(monthPart);
        } else {
          // Ay ismi
          String normalizedMonth = monthPart.toLowerCase().trim();
          month = 1; // Varsayılan değer
          
          for (var entry in monthNames.entries) {
            if (normalizedMonth.contains(entry.key)) {
              month = entry.value;
              break;
            }
          }
        }
        
        int year = int.parse(fullMatch.group(3)!);
        int hour = int.parse(fullMatch.group(4)!);
        int minute = int.parse(fullMatch.group(5)!);
        
        _logger.i('Ayrıştırılan tarih: $day/$month/$year $hour:$minute');
        return DateTime(year, month, day, hour, minute);
      }
      
      // Sadece tarih (örn: 15.06.2023)
      final dateMatch = dateOnlyPattern.firstMatch(dateStr);
      // Sadece saat (örn: 14:30)
      final timeMatch = timeOnlyPattern.firstMatch(dateStr);
      
      if (dateMatch != null) {
        _logger.i('Sadece tarih eşleşmesi bulundu: ${dateMatch.group(0)}');
        
        int day = int.parse(dateMatch.group(1)!);
        int month;
        final monthPart = dateMatch.group(2)!;
        
        // Ay sayı mı yoksa isim mi?
        if (RegExp(r'^\d+$').hasMatch(monthPart)) {
          month = int.parse(monthPart);
        } else {
          // Ay ismi
          String normalizedMonth = monthPart.toLowerCase().trim();
          month = 1; // Varsayılan değer
          
          for (var entry in monthNames.entries) {
            if (normalizedMonth.contains(entry.key)) {
              month = entry.value;
              break;
            }
          }
        }
        
        int year = int.parse(dateMatch.group(3)!);
        int hour = 0;
        int minute = 0;
        
        // Ayrıca saat bilgisi varsa ekle
        if (timeMatch != null) {
          _logger.i('Ayrıca saat eşleşmesi bulundu: ${timeMatch.group(0)}');
          hour = int.parse(timeMatch.group(1)!);
          minute = int.parse(timeMatch.group(2)!);
        }
        
        _logger.i('Ayrıştırılan tarih: $day/$month/$year $hour:$minute');
        return DateTime(year, month, day, hour, minute);
      }
      
      // Hiçbir formatla eşleşmediyse, şu anki zamanı kullan
      _logger.w('Tarih formatı algılanamadı, şimdiki zaman kullanılıyor');
      return DateTime.now();
    } catch (e) {
      _logger.e('Tarih parse edilirken hata: $e');
      return DateTime.now(); // Hata olduğunda şu anki zamanı kullan
    }
  }
  
  // Paylaşım fonksiyonu
  Future<void> _shareEvent() async {
    try {
      final String shareText = 'Etkinlik: ${widget.eventTitle}\n'
          '${widget.eventDescription}\n'
          'Tarih: ${widget.eventDate}\n'
          '${_groupDetail != null ? 'Grup: ${_groupDetail!.groupName}\n' : ''}'
          'Organizatör: ${widget.eventUser}';
      
      await Share.share(
        shareText,
        subject: widget.eventTitle,
      );
    } catch (e) {
      _logger.e('Etkinlik paylaşılırken hata oluştu: $e');
      _showMessage('Etkinlik paylaşılırken bir hata oluştu');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('Etkinlik Detayı'),
        trailingActions: [
          PlatformIconButton(
            icon: Icon(
              isIOS ? CupertinoIcons.group : Icons.group,
            ),
            onPressed: _goToGroupDetail,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView()
                : _buildEventDetailContent(),
      ),
    );
  }
  
  Widget _buildErrorView() {
    final isIOS = Platform.isIOS;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline,
              size: 56,
              color: isIOS ? CupertinoColors.systemRed : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Hata Oluştu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isIOS ? CupertinoColors.label : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatErrorMessage(_errorMessage),
              style: TextStyle(
                color: isIOS ? CupertinoColors.systemGrey : Colors.grey[700],
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PlatformElevatedButton(
              onPressed: _loadGroupDetail,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Hata mesajlarını temizleme
  String _formatErrorMessage(String error) {
    // Uzun hata mesajlarını kısaltma
    if (error.length > 100) {
      error = '${error.substring(0, 100)}...';
    }
    
    // "Exception: " text'ini kaldırma
    if (error.startsWith('Exception: ')) {
      error = error.substring('Exception: '.length);
    }
    
    return error;
  }
  
  Widget _buildEventDetailContent() {
    final bool isIOS = Platform.isIOS;
    final cardBackgroundColor = isIOS 
        ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
        : Theme.of(context).cardColor;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etkinlik başlık kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: (isIOS ? CupertinoColors.systemIndigo : Colors.indigo).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: isIOS ? Border.all(color: CupertinoColors.systemIndigo.withOpacity(0.3), width: 0.5) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isIOS ? CupertinoIcons.calendar : Icons.event,
                      size: 22,
                      color: isIOS ? CupertinoColors.systemIndigo : Colors.indigo,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.eventTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isIOS ? CupertinoColors.systemIndigo : Colors.indigo,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_groupDetail != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isIOS ? CupertinoIcons.group : Icons.group,
                        size: 14,
                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _groupDetail!.groupName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Etkinlik detayları kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
              boxShadow: isIOS ? null : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etkinlik Bilgileri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isIOS ? CupertinoTheme.of(context).textTheme.textStyle.color : Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tarih bilgisi
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isIOS ? CupertinoColors.systemOrange : Colors.orange).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                        color: isIOS ? CupertinoColors.systemOrange : Colors.orange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarih',
                          style: TextStyle(
                            fontSize: 14,
                            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.eventDate,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Oluşturan kişi bilgisi
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isIOS ? CupertinoIcons.person : Icons.person,
                        color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Oluşturan',
                          style: TextStyle(
                            fontSize: 14,
                            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.eventUser,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                if (widget.eventDescription.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  
                  // Açıklama bilgisi
                  Text(
                    'Açıklama',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isIOS ? CupertinoTheme.of(context).textTheme.textStyle.color : Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.eventDescription,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isIOS ? CupertinoTheme.of(context).textTheme.textStyle.color : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // İşlem butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.groupId > 0) // Grup ID'si 0'dan büyükse gruba git butonunu göster
                _buildActionButton(
                  icon: isIOS ? CupertinoIcons.group : Icons.group,
                  label: 'Gruba Git',
                  onTap: _goToGroupDetail,
                  color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                ),
              _buildActionButton(
                icon: isIOS ? CupertinoIcons.calendar_badge_plus : Icons.event_available,
                label: 'Takvime Ekle',
                onTap: _addToCalendar,
                color: isIOS ? CupertinoColors.systemGreen : Colors.green,
              ),
              _buildActionButton(
                icon: isIOS ? CupertinoIcons.share : Icons.share,
                label: 'Paylaş',
                onTap: _shareEvent,
                color: isIOS ? CupertinoColors.systemIndigo : Colors.indigo,
              ),
              _buildActionButton(
                icon: isIOS ? CupertinoIcons.calendar : Icons.calendar_month,
                label: 'Takvimim',
                onTap: _showCalendarEvents,
                color: isIOS ? CupertinoColors.systemOrange : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showMessage(String message) {
    final isIOS = Platform.isIOS;
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Bilgi'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
} 