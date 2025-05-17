import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/group_models.dart';
import '../viewmodels/event_viewmodel.dart';
import '../viewmodels/group_viewmodel.dart';
import '../services/logger_service.dart';

// Hızlı etkinlik şablonu modeli
class QuickEventTemplate {
  final String icon;
  final String title;
  final String description;
  final Color color;
  final TextDecoration decoration;
  const QuickEventTemplate({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.decoration = TextDecoration.none,
  });
}

class CreateEventView extends StatefulWidget {
  final int? initialGroupID;
  final DateTime? initialDate;
  final bool isEditing;
  final int? eventID;
  final String? initialTitle;
  final String? initialDescription;
  
  const CreateEventView({
    Key? key,
    this.initialGroupID,
    this.initialDate,
    this.isEditing = false,
    this.eventID,
    this.initialTitle,
    this.initialDescription,
  }) : super(key: key);

  @override
  _CreateEventViewState createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<CreateEventView> {
  final LoggerService _logger = LoggerService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isGroupLoading = false;
  List<Group> _groups = [];
  Group? _selectedGroup;
  
  // Hızlı etkinlik şablonları listesi
  final List<QuickEventTemplate> _quickEventTemplates = [
    QuickEventTemplate(
      icon: '🤝',
      title: 'Toplantı',
      description: 'Genel ekip toplantısı',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🎂',
      title: 'Doğum Günü',
      description: 'Doğum günü kutlaması',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🍽️',
      title: 'Yemek',
      description: 'Ekip yemeği',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '📊',
      title: 'Sunum',
      description: 'Proje sunumu',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '📱',
      title: 'Görüşme',
      description: 'Online görüşme',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '💻',
      title: 'Webinar',
      description: 'Online eğitim semineri',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '📝',
      title: 'Not Alma',
      description: 'Proje notları oluşturma',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🏃',
      title: 'Spor',
      description: 'Ekip spor etkinliği',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🎯',
      title: 'Hedef Belirleme',
      description: 'Aylık hedef belirleme toplantısı',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🧠',
      title: 'Beyin Fırtınası',
      description: 'Yaratıcı fikir geliştirme seansı',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🤔',
      title: 'Strateji',
      description: 'Strateji belirleme toplantısı',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '📢',
      title: 'Duyuru',
      description: 'Önemli duyuru toplantısı',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🛠️',
      title: 'Hackathon',
      description: 'Kod yazma maratonu',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '📚',
      title: 'Eğitim',
      description: 'Teknik eğitim seansı',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '👋',
      title: 'Karşılama',
      description: 'Yeni ekip üyesi karşılama etkinliği',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '📆',
      title: 'Sprint Planlama',
      description: 'Agile sprint planlama toplantısı',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '📈',
      title: 'Performans',
      description: 'Performans değerlendirme görüşmesi',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🎮',
      title: 'Oyun Etkinliği',
      description: 'Ekip kaynaştırma oyunları',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🎭',
      title: 'Kültürel Etkinlik',
      description: 'Kültürel gezi veya etkinlik',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '✈️',
      title: 'İş Seyahati',
      description: 'İş için şehir dışı seyahat',
      color: Colors.grey,
      decoration: TextDecoration.none,
    ),
    QuickEventTemplate(
      icon: '🏆',
      title: 'Ödül Töreni',
      description: 'Başarı ödüllerinin verilmesi',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🥂',
      title: 'Kutlama',
      description: 'Başarı kutlaması',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🧪',
      title: 'Workshop',
      description: 'Uygulama atölyesi',
      color: Colors.grey,
    ),
    QuickEventTemplate(
      icon: '🧩',
      title: 'Problem Çözme',
      description: 'Sorun giderme oturumu',
      color: Colors.grey,
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadGroups();
    
    // Eğer başlangıç grup ID'si verilmişse, o grubu seç
    if (widget.initialGroupID != null && widget.initialGroupID! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setInitialGroup();
      });
    }
  }
  
  void _initializeControllers() {
    // Eğer düzenleme modundaysa, mevcut verileri doldur
    if (widget.isEditing) {
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialDescription != null) {
        _descController.text = widget.initialDescription!;
      }
    }
    
    // Tarih ve saat bilgilerini ayarla
    final date = widget.initialDate ?? DateTime.now();
    final dateFormat = DateFormat('dd.MM.yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    _dateController.text = dateFormat.format(date);
    _timeController.text = timeFormat.format(date);
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }
  
  Future<void> _loadGroups() async {
    setState(() {
      _isGroupLoading = true;
    });
    
    try {
      final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
      await groupViewModel.loadGroups();
      
      setState(() {
        _groups = groupViewModel.groups;
        // Kendime seçeneğini ekle
        _groups.insert(0, Group(
          groupID: 0,
          groupName: 'Kendime',
          groupDesc: '',
          createdBy: '', 
          packageName: '',
          packageExpires: '',
          createDate: '',
          isFree: true,
          isAdmin: true,
          projects: [],
        ));
        _isGroupLoading = false;
      });
      
      _logger.i('${_groups.length} grup yüklendi');
    } catch (e) {
      _logger.e('Gruplar yüklenirken hata: $e');
      setState(() {
        _isGroupLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gruplar yüklenirken hata: $e')),
        );
      }
    }
  }
  
  void _setInitialGroup() {
    if (_groups.isNotEmpty && widget.initialGroupID != null) {
      final initialGroup = _groups.firstWhere(
        (group) => group.groupID == widget.initialGroupID,
        orElse: () => _groups.first,
      );
      
      setState(() {
        _selectedGroup = initialGroup;
      });
    } else if (_groups.isNotEmpty) {
      // Eğer başlangıç grup ID'si verilmemişse, "Kendime" seçeneğini seç
      setState(() {
        _selectedGroup = _groups.first; // Kendime seçeneği
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final isIOS = isCupertino(context);
    final now = DateTime.now();
    
    // Mevcut tarih değerini al
    final parts = _dateController.text.split('.');
    
    DateTime initialDate;
    try {
      initialDate = DateTime(
        int.parse(parts[2]), // Yıl
        int.parse(parts[1]), // Ay
        int.parse(parts[0]), // Gün
      );
      // Eğer seçilen tarih bugünden önceyse, bugünü kullan
      if (initialDate.isBefore(DateTime(now.year, now.month, now.day))) {
        initialDate = DateTime(now.year, now.month, now.day);
      }
    } catch (e) {
      initialDate = DateTime(now.year, now.month, now.day);
    }
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return Container(
            height: 300,
            color: CupertinoColors.systemBackground,
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  child: CupertinoDatePicker(
                    initialDateTime: initialDate,
                    minimumDate: DateTime(now.year, now.month, now.day),
                    maximumDate: DateTime(now.year + 2, now.month, now.day),
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (DateTime dateTime) {
                      _dateController.text = '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
                    },
                  ),
                ),
                CupertinoButton(
                  child: const Text('Tamam', 
                    style: TextStyle(decoration: TextDecoration.none)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ),
          );
        },
      );
    } else {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: now,
        lastDate: DateTime(now.year + 2, now.month, now.day),
      );
      
      if (pickedDate != null) {
        setState(() {
          _dateController.text = '${pickedDate.day.toString().padLeft(2, '0')}.${pickedDate.month.toString().padLeft(2, '0')}.${pickedDate.year}';
        });
      }
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final isIOS = isCupertino(context);
    final now = TimeOfDay.now();
    
    // Mevcut saat değerini al
    final parts = _timeController.text.split(':');
    
    TimeOfDay initialTime;
    try {
      initialTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      initialTime = now;
    }
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) {
          // Zaman seçici için bugün tarihi olarak kullan
          final today = DateTime.now();
          final initialDateTime = DateTime(
            today.year,
            today.month,
            today.day,
            initialTime.hour,
            initialTime.minute,
          );
          
          return Container(
            height: 300,
            color: CupertinoColors.systemBackground,
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  child: CupertinoDatePicker(
                    initialDateTime: initialDateTime,
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    onDateTimeChanged: (DateTime dateTime) {
                      setState(() {
                        _timeController.text = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                      });
                    },
                  ),
                ),
                CupertinoButton(
                  child: const Text('Tamam', 
                    style: TextStyle(decoration: TextDecoration.none)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ),
          );
        },
      );
    } else {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      
      if (pickedTime != null) {
        setState(() {
          _timeController.text = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
        });
      }
    }
  }
  
  // Hızlı etkinlik seçim ekranını göster
  void _showQuickEventPicker(BuildContext context) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          return Container(
            color: CupertinoColors.systemBackground,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Kapat',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(top: 14, bottom: 40, left: 12, right: 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 24,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: _quickEventTemplates.length,
                        itemBuilder: (context, index) {
                          final template = _quickEventTemplates[index];
                          return _buildIOSQuickEventItem(context, template);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 14, bottom: 40, left: 12, right: 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: _quickEventTemplates.length,
                    itemBuilder: (context, index) {
                      final template = _quickEventTemplates[index];
                      return _buildMaterialQuickEventItem(context, template);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  // iOS tasarımında hızlı etkinlik öğesi
  Widget _buildIOSQuickEventItem(BuildContext context, QuickEventTemplate template) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: GestureDetector(
        onTap: () {
          _applyQuickEventTemplate(template);
          Navigator.pop(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  template.icon,
                  style: const TextStyle(fontSize: 30, decoration: TextDecoration.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                template.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Material tasarımda hızlı etkinlik öğesi
  Widget _buildMaterialQuickEventItem(BuildContext context, QuickEventTemplate template) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: InkWell(
        onTap: () {
          _applyQuickEventTemplate(template);
          Navigator.pop(context);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  template.icon,
                  style: const TextStyle(fontSize: 28, decoration: TextDecoration.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                template.title,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Seçilen hızlı etkinlik şablonunu uygula
  void _applyQuickEventTemplate(QuickEventTemplate template) {
    setState(() {
      _titleController.text = template.title;
      _descController.text = template.description;
    });
  }
  
  Future<void> _createEvent() async {
    // Form doğrulama
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen etkinlik başlığını girin')),
      );
      return;
    }
    
    if (_descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen etkinlik açıklamasını girin')),
      );
      return;
    }
    
    // Tarih formatını birleştir
    final eventDate = '${_dateController.text} ${_timeController.text}';
    final groupID = _selectedGroup?.groupID ?? 0;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
      bool success;
      
      if (widget.isEditing && widget.eventID != null) {
        // Etkinlik güncelleme
        success = await eventViewModel.updateEvent(
          eventID: widget.eventID!,
          eventTitle: _titleController.text,
          eventDesc: _descController.text,
          eventDate: eventDate,
          eventStatus: 1, // Aktif etkinlik
          groupID: groupID,
        );
      } else {
        // Yeni etkinlik oluşturma
        success = await eventViewModel.createEvent(
          groupID: groupID,
          eventTitle: _titleController.text,
          eventDesc: _descController.text,
          eventDate: eventDate,
        );
      }
      
      if (success) {
        _logger.i(widget.isEditing 
          ? 'Etkinlik başarıyla güncellendi' 
          : 'Etkinlik başarıyla oluşturuldu');
        
        if (mounted) {
          // iOS tarzında başarı mesajı göster
          if (isCupertino(context)) {
            showCupertinoDialog(
              context: context,
              builder: (BuildContext context) => CupertinoAlertDialog(
                title: const Text('Başarılı', 
                  style: TextStyle(decoration: TextDecoration.none)),
                content: Text(widget.isEditing 
                  ? 'Etkinlik başarıyla güncellendi' 
                  : 'Etkinlik başarıyla oluşturuldu',
                  style: const TextStyle(decoration: TextDecoration.none)),
                actions: <CupertinoDialogAction>[
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text('Tamam', 
                      style: TextStyle(decoration: TextDecoration.none)),
                    onPressed: () {
                      Navigator.pop(context);
                      // Etkinlik işlemi başarılı olduğunda önceki sayfaya başarı bilgisi ile dön
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            );
          } else {
            // İşlem başarılı mesajını göster ve sonra geri dön
            Navigator.of(context).pop(true);
          }
        }
      } else {
        _logger.e(widget.isEditing 
          ? 'Etkinlik güncellenemedi: ${eventViewModel.errorMessage}'
          : 'Etkinlik oluşturulamadı: ${eventViewModel.errorMessage}');
        
        if (mounted) {
          // Scaffold hatasını önlemek için sadece iOS için 
          // CupertinoAlertDialog gösterelim, diğer platformlar için de uyarlayalım
          if (isCupertino(context)) {
            showCupertinoDialog(
              context: context,
              builder: (BuildContext context) => CupertinoAlertDialog(
                title: const Text('Hata', 
                  style: TextStyle(decoration: TextDecoration.none)),
                content: Text(widget.isEditing 
                  ? 'Etkinlik güncellenemedi: ${eventViewModel.errorMessage}'
                  : 'Etkinlik oluşturulamadı: ${eventViewModel.errorMessage}',
                  style: const TextStyle(decoration: TextDecoration.none)),
                actions: <CupertinoDialogAction>[
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text('Tamam', 
                      style: TextStyle(decoration: TextDecoration.none)),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          } else {
            // Android için SnackBar kullanmaya devam edelim
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.isEditing 
                ? 'Etkinlik güncellenemedi: ${eventViewModel.errorMessage}'
                : 'Etkinlik oluşturulamadı: ${eventViewModel.errorMessage}')),
            );
          }
        }
      }
    } catch (e) {
      _logger.e(widget.isEditing 
        ? 'Etkinlik güncellenirken hata: $e'
        : 'Etkinlik oluşturulurken hata: $e');
      
      if (mounted) {
        // Aynı şekilde hata mesajlarını da hem iOS hem Android için uygun şekilde gösterelim
        if (isCupertino(context)) {
          showCupertinoDialog(
            context: context,
            builder: (BuildContext context) => CupertinoAlertDialog(
              title: const Text('Hata', 
                style: TextStyle(decoration: TextDecoration.none)),
              content: Text(widget.isEditing 
                ? 'Etkinlik güncellenirken hata: $e'
                : 'Etkinlik oluşturulurken hata: $e',
                style: const TextStyle(decoration: TextDecoration.none)),
              actions: <CupertinoDialogAction>[
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Tamam', 
                    style: TextStyle(decoration: TextDecoration.none)),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isEditing 
              ? 'Etkinlik güncellenirken hata: $e'
              : 'Etkinlik oluşturulurken hata: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.isEditing ? 'Etkinlik Düzenle' : 'Yeni Etkinlik', 
              style: TextStyle(decoration: TextDecoration.none)),
        trailingActions: [
          PlatformIconButton(
            icon: Icon(isIOS ? CupertinoIcons.check_mark : Icons.check),
            onPressed: _isLoading ? null : _createEvent,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık bölümü
                    PlatformWidget(
                      material: (_, __) => Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Başlık',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.event_outlined),
                            tooltip: 'Hızlı Etkinlik',
                            onPressed: () => _showQuickEventPicker(context),
                            color: Colors.grey[700],
                            iconSize: 22,
                          ),
                        ],
                      ),
                      cupertino: (_, __) => Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              controller: _titleController,
                              placeholder: 'Etkinlik Başlığı',
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showQuickEventPicker(context),
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.square_grid_2x2,
                                  size: 18,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Açıklama
                    PlatformWidget(
                      material: (_, __) => TextField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Açıklama',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      cupertino: (_, __) => CupertinoTextField(
                        controller: _descController,
                        placeholder: 'Etkinlik Açıklaması',
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        maxLines: 4,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Tarih ve saat seçimi
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PlatformWidget(
                            material: (_, __) => InkWell(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _dateController,
                                  decoration: InputDecoration(
                                    labelText: 'Tarih',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            cupertino: (_, __) => GestureDetector(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: CupertinoTextField(
                                  controller: _dateController,
                                  placeholder: 'GG.AA.YYYY',
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: PlatformWidget(
                            material: (_, __) => InkWell(
                              onTap: () => _selectTime(context),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _timeController,
                                  decoration: InputDecoration(
                                    labelText: 'Saat',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            cupertino: (_, __) => GestureDetector(
                              onTap: () => _selectTime(context),
                              child: AbsorbPointer(
                                child: CupertinoTextField(
                                  controller: _timeController,
                                  placeholder: 'SS:DD',
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Grup seçimi
                    Text(
                      'Grup',
                      style: TextStyle(
                        fontSize: 14,
                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _isGroupLoading
                        ? Center(child: PlatformCircularProgressIndicator())
                        : _buildGroupSelector(context),
                        
                    const SizedBox(height: 24),
                    
                    // Kaydet butonu
                    SizedBox(
                      width: double.infinity,
                      child: PlatformElevatedButton(
                        onPressed: _isLoading ? null : _createEvent,
                        material: (_, __) => MaterialElevatedButtonData(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        cupertino: (_, __) => CupertinoElevatedButtonData(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 15,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
  
  Widget _buildGroupSelector(BuildContext context) {
    final isIOS = isCupertino(context);
    
    if (_groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isIOS ? CupertinoColors.systemGrey6 : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              isIOS ? CupertinoIcons.group : Icons.group,
              color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Henüz hiç grubunuz yok.',
              style: TextStyle(
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            PlatformTextButton(
              onPressed: _loadGroups,
              child: const Text('Yenile', 
                  style: TextStyle(decoration: TextDecoration.none)),
            ),
          ],
        ),
      );
    }
    
    if (isIOS) {
      return Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (BuildContext context) {
                return Container(
                  height: 250,
                  padding: const EdgeInsets.only(top: 6.0),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              child: const Text('İptal',
                                style: TextStyle(decoration: TextDecoration.none)),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            CupertinoButton(
                              child: const Text('Tamam',
                                style: TextStyle(decoration: TextDecoration.none)),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            magnification: 1.22,
                            squeeze: 1.2,
                            useMagnifier: true,
                            itemExtent: 32.0,
                            scrollController: FixedExtentScrollController(
                              initialItem: _selectedGroup != null 
                                ? _groups.indexOf(_selectedGroup!)
                                : 0,
                            ),
                            onSelectedItemChanged: (int index) {
                              setState(() {
                                _selectedGroup = _groups[index];
                              });
                            },
                            children: _groups.map((Group group) {
                              return Center(
                                child: Text(
                                  group.groupName.isNotEmpty ? group.groupName : 'Kendime',
                                  style: const TextStyle(fontSize: 16, decoration: TextDecoration.none),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.group,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedGroup?.groupName ?? 'Grup Seçin',
                    style: TextStyle(
                      color: _selectedGroup != null
                        ? CupertinoColors.label.resolveFrom(context)
                        : CupertinoColors.placeholderText.resolveFrom(context),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const Icon(
                CupertinoIcons.chevron_down,
                color: CupertinoColors.systemGrey,
                size: 16,
              ),
            ],
          ),
        ),
      );
    } else {
      return DropdownButtonFormField<Group>(
        decoration: const InputDecoration(
          labelText: 'Grup',
          prefixIcon: Icon(Icons.group),
          border: OutlineInputBorder(),
        ),
        value: _selectedGroup,
        hint: const Text('Grup Seçin', style: TextStyle(decoration: TextDecoration.none)),
        onChanged: (Group? newValue) {
          setState(() {
            _selectedGroup = newValue;
          });
        },
        items: _groups.map<DropdownMenuItem<Group>>((Group group) {
          return DropdownMenuItem<Group>(
            value: group,
            child: Text(group.groupName, style: const TextStyle(decoration: TextDecoration.none)),
          );
        }).toList(),
      );
    }
  }
} 