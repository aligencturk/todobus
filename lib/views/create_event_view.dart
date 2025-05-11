import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/group_models.dart';
import '../viewmodels/event_viewmodel.dart';
import '../viewmodels/group_viewmodel.dart';
import '../services/logger_service.dart';

class CreateEventView extends StatefulWidget {
  final int? initialGroupID;
  final DateTime? initialDate;
  
  const CreateEventView({
    Key? key,
    this.initialGroupID,
    this.initialDate,
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
  
  @override
  void initState() {
    super.initState();
    
    // Tarih bilgisini ayarla
    final initialDateTime = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
    _dateController.text = '${initialDateTime.day.toString().padLeft(2, '0')}.${initialDateTime.month.toString().padLeft(2, '0')}.${initialDateTime.year}';
    _timeController.text = '12:00';
    
    // Grupları yükle
    _loadGroups();
    
    // Eğer başlangıç grup ID'si verilmişse, o grubu seç
    if (widget.initialGroupID != null && widget.initialGroupID! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setInitialGroup();
      });
    }
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
                    minimumDate: now,
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
      final success = await eventViewModel.createEvent(
        groupID: groupID,
        eventTitle: _titleController.text,
        eventDesc: _descController.text,
        eventDate: eventDate,
      );
      
      if (success) {
        _logger.i('Etkinlik başarıyla oluşturuldu');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu')),
          );
          
          // Oluşturma başarılı olduğunda geri dön
          Navigator.of(context).pop(true);
        }
      } else {
        _logger.e('Etkinlik oluşturulamadı: ${eventViewModel.errorMessage}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Etkinlik oluşturulamadı: ${eventViewModel.errorMessage}')),
          );
        }
      }
    } catch (e) {
      _logger.e('Etkinlik oluşturulurken hata: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etkinlik oluşturulurken hata: $e')),
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
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Yeni Etkinlik'),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    PlatformTextField(
                      controller: _titleController,
                      hintText: 'Etkinlik Başlığı',
                      material: (_, __) => MaterialTextFieldData(
                        decoration: const InputDecoration(
                          labelText: 'Başlık',
                          prefixIcon: Icon(Icons.title),
                        ),
                      ),
                      cupertino: (_, __) => CupertinoTextFieldData(
                        placeholder: 'Etkinlik Başlığı',
                        prefix: const Icon(CupertinoIcons.textformat),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Açıklama
                    PlatformTextField(
                      controller: _descController,
                      hintText: 'Etkinlik Açıklaması',
                      maxLines: 5,
                      material: (_, __) => MaterialTextFieldData(
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          prefixIcon: Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                      ),
                      cupertino: (_, __) => CupertinoTextFieldData(
                        placeholder: 'Etkinlik Açıklaması',
                        prefix: const Icon(CupertinoIcons.doc_text),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Tarih',
                                    prefixIcon: Icon(Icons.calendar_today),
                                    hintText: 'GG.AA.YYYY',
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
                                  prefix: const Icon(CupertinoIcons.calendar),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Saat',
                                    prefixIcon: Icon(Icons.access_time),
                                    hintText: 'SS:DD',
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
                                  prefix: const Icon(CupertinoIcons.time),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                    const SizedBox(height: 24),
                    
                    // Grup seçimi
                    Text(
                      'Gruba Ata',
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.titleMedium,
                        cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                          fontSize: 16,
                        ),
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
                          icon: const Icon(Icons.save),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        cupertino: (_, __) => CupertinoElevatedButtonData(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Etkinlik Oluştur'),
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
              ),
            ),
            const SizedBox(height: 8),
            PlatformTextButton(
              onPressed: _loadGroups,
              child: const Text('Yenile'),
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
                              child: const Text('İptal'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            CupertinoButton(
                              child: const Text('Tamam'),
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
                                  group.groupName,
                                  style: const TextStyle(fontSize: 16),
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
        hint: const Text('Grup Seçin'),
        onChanged: (Group? newValue) {
          setState(() {
            _selectedGroup = newValue;
          });
        },
        items: _groups.map<DropdownMenuItem<Group>>((Group group) {
          return DropdownMenuItem<Group>(
            value: group,
            child: Text(group.groupName),
          );
        }).toList(),
      );
    }
  }
} 