import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/event_models.dart';
import '../viewmodels/event_viewmodel.dart';
import '../services/logger_service.dart';

class EventDetailView extends StatefulWidget {
  final int eventID;
  
  const EventDetailView({
    Key? key,
    required this.eventID,
  }) : super(key: key);

  @override
  _EventDetailViewState createState() => _EventDetailViewState();
}

class _EventDetailViewState extends State<EventDetailView> {
  final LoggerService _logger = LoggerService();
  bool _isLoading = false;
  bool _isEditing = false;
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    // Sayfa açıldığında etkinlik detayını yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadEventDetail();
      }
    });
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }
  
  Future<void> _loadEventDetail() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
      await eventViewModel.getEventDetail(widget.eventID);
      
      // Detaylar yüklendiyse form alanlarını doldur
      if (eventViewModel.selectedEvent != null) {
        final event = eventViewModel.selectedEvent!;
        _titleController.text = event.eventTitle;
        _descController.text = event.eventDesc;
        
        // Tarih formatını ayırma
        final parts = event.eventDate.split(' ');
        if (parts.length == 2) {
          _dateController.text = parts[0]; // 27.04.2025
          _timeController.text = parts[1]; // 19:00
        }
        
        _logger.i('Etkinlik detayı başarıyla yüklendi: ${event.eventTitle}');
      }
    } catch (e) {
      _logger.e('Etkinlik detayı yüklenirken hata: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _updateEvent() async {
    final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
    final selectedEvent = eventViewModel.selectedEvent;
    
    if (selectedEvent == null) {
      _logger.e('Güncellenecek etkinlik bulunamadı');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final eventDate = '${_dateController.text} ${_timeController.text}';
      
      final success = await eventViewModel.updateEvent(
        eventID: selectedEvent.eventID,
        eventTitle: _titleController.text,
        eventDesc: _descController.text,
        eventDate: eventDate,
        eventStatus: selectedEvent.eventStatusID,
        groupID: selectedEvent.groupID,
      );
      
      if (success) {
        setState(() {
          _isEditing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Etkinlik başarıyla güncellendi')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Etkinlik güncellenemedi: ${eventViewModel.errorMessage}')),
          );
        }
      }
    } catch (e) {
      _logger.e('Etkinlik güncellenirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etkinlik güncellenirken hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _deleteEvent() async {
    final isIOS = isCupertino(context);
    final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
    final selectedEvent = eventViewModel.selectedEvent;
    
    if (selectedEvent == null) {
      _logger.e('Silinecek etkinlik bulunamadı');
      return;
    }
    
    // Silme onay iletişim kutusu
    bool? confirmDelete;
    
    if (isIOS) {
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Etkinlik Silinecek'),
          content: const Text('Bu etkinliği silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Sil'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ).then((value) => confirmDelete = value);
    } else {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Etkinlik Silinecek'),
          content: const Text('Bu etkinliği silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
          actions: [
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ).then((value) => confirmDelete = value);
    }
    
    if (confirmDelete != true) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await eventViewModel.deleteEvent(
        selectedEvent.eventID,
        groupID: selectedEvent.groupID,
      );
      
      if (success) {
        if (mounted) {
          Navigator.of(context).pop(); // Detay sayfasını kapat
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Etkinlik başarıyla silindi')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Etkinlik silinemedi: ${eventViewModel.errorMessage}')),
          );
        }
      }
    } catch (e) {
      _logger.e('Etkinlik silinirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etkinlik silinirken hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    } catch (e) {
      initialDate = now;
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
                    minimumDate: now.subtract(const Duration(days: 365)),
                    maximumDate: DateTime(now.year + 2, now.month, now.day),
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (DateTime dateTime) {
                      _dateController.text = '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
                    },
                  ),
                ),
                CupertinoButton(
                  child: const Text('Tamam'),
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
        firstDate: now.subtract(const Duration(days: 365)),
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
    
    // Mevcut saat değerini al
    final parts = _timeController.text.split(':');
    
    TimeOfDay initialTime;
    try {
      initialTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      initialTime = TimeOfDay.now();
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
                    initialDateTime: DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                      initialTime.hour,
                      initialTime.minute,
                    ),
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
                  child: const Text('Tamam'),
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
  
  @override
  Widget build(BuildContext context) {
    final eventViewModel = Provider.of<EventViewModel>(context);
    final selectedEvent = eventViewModel.selectedEvent;
    final isIOS = isCupertino(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(selectedEvent?.eventTitle ?? 'Etkinlik Detayı'),
        trailingActions: _buildTrailingActions(context, isIOS, selectedEvent),
      ),
      body: SafeArea(
        child: _isLoading && selectedEvent == null
            ? Center(child: PlatformCircularProgressIndicator())
            : selectedEvent == null
                ? _buildErrorView(context, eventViewModel.errorMessage)
                : _buildContent(context, selectedEvent, isIOS),
      ),
    );
  }

  List<Widget> _buildTrailingActions(BuildContext context, bool isIOS, Event? selectedEvent) {
    if (_isEditing)
      return [
        PlatformIconButton(
          icon: Icon(isIOS ? CupertinoIcons.xmark : Icons.close),
          onPressed: () {
            setState(() {
              _isEditing = false;
            });
          },
        ),
      ];
    if (!_isEditing && selectedEvent != null && selectedEvent.eventType != 'company')
      return [
        PlatformIconButton(
          icon: Icon(isIOS ? CupertinoIcons.pencil : Icons.edit),
          onPressed: () {
            setState(() {
              _isEditing = true;
            });
          },
        ),
      ];
    if (_isEditing)
      return [
        PlatformIconButton(
          icon: Icon(isIOS ? CupertinoIcons.checkmark : Icons.check),
          onPressed: _updateEvent,
        ),
      ];
    return [];
  }

  Widget _buildErrorView(BuildContext context, String? errorMessage) {
    return Center(
      child: Text(
        errorMessage ?? 'Bir hata oluştu',
        style: platformThemeData(
          context,
          material: (data) => data.textTheme.headlineSmall,
          cupertino: (data) => data.textTheme.navTitleTextStyle,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Event event, bool isIOS) {
    return _isEditing
        ? _buildEditForm(context)
        : SingleChildScrollView(
            child: Column(
              children: [
                _buildEventDetailCard(context, event),
                if (event.eventType != 'company')
                  _buildActionButtons(context),
              ],
            ),
          );
  }

  Widget _buildEventDetailCard(BuildContext context, Event event) {
    final isIOS = isCupertino(context);
    final now = DateTime.now();
    final eventDate = event.eventDateTime;
    final isUpcoming = eventDate.isAfter(now);
    final isCompanyEvent = event.eventType == 'company';
    
    // Tarih durumunu belirle
    Color statusColor;
    String statusText;
    
    if (isUpcoming) {
      if (eventDate.difference(now).inDays < 3) {
        statusColor = isIOS ? CupertinoColors.systemOrange : Colors.orange;
        statusText = 'Yaklaşıyor';
      } else {
        statusColor = isIOS ? CupertinoColors.activeGreen : Colors.green;
        statusText = 'Planlandı';
      }
    } else {
      statusColor = isIOS ? CupertinoColors.systemGrey : Colors.grey;
      statusText = 'Süresi Doldu';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemBackground : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isIOS ? CupertinoColors.systemGrey5.withOpacity(0.4) : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isCompanyEvent ? Border.all(
          color: isIOS ? CupertinoColors.activeBlue.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
          width: 1.5,
        ) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.eventTitle,
                    style: platformThemeData(
                      context,
                      material: (data) => data.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (isCompanyEvent)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isIOS ? CupertinoColors.activeBlue.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIOS ? CupertinoIcons.briefcase : Icons.business,
                      size: 16,
                      color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Şirket Etkinliği',
                      style: TextStyle(
                        color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(
              event.eventDesc,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
                cupertino: (data) => data.textTheme.textStyle.copyWith(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow(
              context,
              isIOS ? CupertinoIcons.calendar : Icons.event,
              'Tarih',
              DateFormat.yMMMMd('tr_TR').format(eventDate),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              isIOS ? CupertinoIcons.time : Icons.access_time,
              'Saat',
              DateFormat.Hm().format(eventDate),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              isIOS ? CupertinoIcons.person : Icons.person,
              'Oluşturan',
              isCompanyEvent ? 'Şirket Yönetimi' : event.userFullname,
            ),
            if (!isCompanyEvent && event.groupID > 0)
              Column(
                children: [
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    context,
                    isIOS ? CupertinoIcons.group : Icons.group,
                    'Grup',
                    'Grup #${event.groupID}',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isIOS = isCupertino(context);
    final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
    final event = eventViewModel.selectedEvent;
    
    if (event == null) return const SizedBox.shrink();
    
    // Şirket etkinlikleri düzenlenemez ve silinemez
    final isCompanyEvent = event.eventType == 'company';
    if (isCompanyEvent) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: PlatformElevatedButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              material: (_, __) => MaterialElevatedButtonData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              cupertino: (_, __) => CupertinoElevatedButtonData(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIOS ? CupertinoIcons.pencil : Icons.edit,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('Düzenle'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PlatformElevatedButton(
              onPressed: () async {
                await _deleteEvent();
              },
              material: (_, __) => MaterialElevatedButtonData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              cupertino: (_, __) => CupertinoElevatedButtonData(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: CupertinoColors.destructiveRed,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIOS ? CupertinoIcons.delete : Icons.delete,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('Sil'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etkinlik Bilgileri',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 16),
          PlatformTextFormField(
            controller: _titleController,
            hintText: 'Etkinlik Başlığı',
            material: (_, __) => MaterialTextFormFieldData(
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
            ),
            cupertino: (_, __) => CupertinoTextFormFieldData(
              prefix: const Text('Başlık:'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: CupertinoColors.systemGrey4),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PlatformTextFormField(
            controller: _descController,
            hintText: 'Etkinlik Açıklaması',
            keyboardType: TextInputType.multiline,
            maxLines: 4,
            material: (_, __) => MaterialTextFormFieldData(
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            cupertino: (_, __) => CupertinoTextFormFieldData(
              prefix: const Text('Açıklama:'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: CupertinoColors.systemGrey4),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Etkinlik Tarihi',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: PlatformTextFormField(
                      controller: _dateController,
                      hintText: 'gg.aa.yyyy',
                      material: (_, __) => MaterialTextFormFieldData(
                        decoration: InputDecoration(
                          labelText: 'Tarih',
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                      cupertino: (_, __) => CupertinoTextFormFieldData(
                        prefix: const Text('Tarih:'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context),
                  child: AbsorbPointer(
                    child: PlatformTextFormField(
                      controller: _timeController,
                      hintText: 'ss:dd',
                      material: (_, __) => MaterialTextFormFieldData(
                        decoration: InputDecoration(
                          labelText: 'Saat',
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time),
                        ),
                      ),
                      cupertino: (_, __) => CupertinoTextFormFieldData(
                        prefix: const Text('Saat:'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final isIOS = isCupertino(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isIOS 
                ? CupertinoColors.systemGrey5
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isIOS ? CupertinoColors.systemGrey : Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  cupertino: (data) => data.textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 