import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/spelling_correction_service.dart';

class CreateReportView extends StatefulWidget {
  final int groupId;
  final List<Project> projects;
  
  const CreateReportView({
    super.key,
    required this.groupId,
    required this.projects,
  });

  @override
  State<CreateReportView> createState() => _CreateReportViewState();
}

class _CreateReportViewState extends State<CreateReportView> {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _currentItemController = TextEditingController();
  
  int _selectedProjectID = 0;
  List<String> _reportItems = [];
  bool _isLoading = false;
  bool _isCorrecting = false;

  @override
  void initState() {
    super.initState();
    final DateTime currentDate = DateTime.now();
    final String formattedDate = '${currentDate.day}.${currentDate.month}.${currentDate.year}';
    _dateController.text = formattedDate;
    
    _initializeSpellingService();
  }

  Future<void> _initializeSpellingService() async {
    try {
      await SpellingCorrectionService.instance.initialize();
    } catch (e) {
      _logger.e('Yazım düzeltme servisi başlatılamadı: $e');
      if (mounted) {
        _showSnackBar('Yazım düzeltme servisi başlatılamadı.', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _currentItemController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _addReportItem() {
    final String text = _currentItemController.text.trim();
    if (text.isNotEmpty) {
      _safeSetState(() {
        _reportItems.add(text);
        _currentItemController.clear();
      });
    }
  }

  void _removeReportItem(int index) {
    _safeSetState(() {
      _reportItems.removeAt(index);
    });
  }

  void _editReportItem(int index) {
    final bool isIOS = isCupertino(context);
    final TextEditingController editController = TextEditingController(text: _reportItems[index]);

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Maddeyi Düzenle'),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: CupertinoTextField(
              controller: editController,
              placeholder: 'Madde metni',
              maxLines: 3,
              autofocus: true,
              keyboardType: TextInputType.multiline,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final String newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  _safeSetState(() {
                    _reportItems[index] = newText;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Maddeyi Düzenle'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(
              hintText: 'Madde metni',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
            keyboardType: TextInputType.multiline,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İPTAL'),
            ),
            ElevatedButton(
              onPressed: () {
                final String newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  _safeSetState(() {
                    _reportItems[index] = newText;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('KAYDET'),
            ),
          ],
        ),
      );
    }
  }

  void _selectProject() {
    final bool isIOS = isCupertino(context);
    final List<Map<String, dynamic>> projectItems = [
      {'id': 0, 'name': 'Genel (Gruba ait)'},
      ...widget.projects
          .map((Project p) => {'id': p.projectID, 'name': p.projectName})
          .toList(),
    ];

    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoActionSheet(
          title: const Text('Proje Seç'),
          actions: projectItems
              .map((Map<String, dynamic> project) => CupertinoActionSheetAction(
                    onPressed: () {
                      _safeSetState(() {
                        _selectedProjectID = project['id'] as int;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(project['name'] as String),
                  ))
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Proje Seç'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: projectItems.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> project = projectItems[index];
                return ListTile(
                  title: Text(project['name'] as String),
                  onTap: () {
                    _safeSetState(() {
                      _selectedProjectID = project['id'] as int;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('KAPAT'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _correctSpelling(TextEditingController controller) async {
    final String text = controller.text.trim();
    if (text.isEmpty || _isCorrecting) return;

    _safeSetState(() => _isCorrecting = true);

    try {
      final String correctedText = await SpellingCorrectionService.instance.correctSpelling(text);
      if (correctedText != text && mounted) {
        controller.text = correctedText;
        _showSnackBar('Yazım hataları düzeltildi');
      } else if (mounted) {
        _showSnackBar('Düzeltilecek yazım hatası bulunamadı.');
      }
    } catch (e) {
      _logger.e('Yazım düzeltme hatası: $e');
      _showSnackBar('Yazım düzeltme sırasında hata oluştu', isError: true);
    } finally {
      _safeSetState(() => _isCorrecting = false);
    }
  }

  Future<void> _correctAllItemsSpelling() async {
    if (_reportItems.isEmpty || _isCorrecting) return;

    _safeSetState(() => _isCorrecting = true);

    try {
      final List<String> correctedItems = [];
      bool hasChanges = false;

      for (final String item in _reportItems) {
        final String correctedItem = await SpellingCorrectionService.instance.correctSpelling(item);
        correctedItems.add(correctedItem);
        if (correctedItem != item) {
          hasChanges = true;
        }
      }

      if (hasChanges && mounted) {
        _safeSetState(() {
          _reportItems = correctedItems;
        });
        _showSnackBar('Tüm maddelerin yazım hataları düzeltildi');
      } else if (mounted) {
        _showSnackBar('Düzeltilecek yazım hatası bulunamadı');
      }
    } catch (e) {
      _logger.e('Toplu yazım düzeltme hatası: $e');
      _showSnackBar('Yazım düzeltme sırasında hata oluştu', isError: true);
    } finally {
      _safeSetState(() => _isCorrecting = false);
    }
  }

  Future<void> _saveReport() async {
    final String title = _titleController.text.trim();
    final String date = _dateController.text.trim();
    
    if (title.isEmpty) {
      _showSnackBar('Rapor başlığı boş bırakılamaz', isError: true);
      return;
    }
    
    if (_reportItems.isEmpty) {
      _showSnackBar('En az bir madde eklemelisiniz', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      final String reportContent = _reportItems.map((String item) => '• $item').join('\n');

      final bool success = await _apiService.report.createReport(
        groupID: widget.groupId,
        projectID: _selectedProjectID,
        reportTitle: title,
        reportDesc: reportContent,
        reportDate: date,
      );

      if (success && mounted) {
        Navigator.pop(context, true);
        _showSnackBar('Rapor başarıyla kaydedildi.');
      } else if(mounted) {
        _showSnackBar('Rapor oluşturulamadı', isError: true);
      }
    } catch (e) {
      _logger.e('Rapor oluşturma hatası: $e');
       if (mounted) {
        _showSnackBar('Rapor oluşturulurken hata oluştu: $e', isError: true);
       }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    try {
      // Scaffold var mı kontrol et
      final ScaffoldMessengerState? scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError
                ? (isCupertino(context) ? CupertinoColors.destructiveRed : Theme.of(context).colorScheme.error)
                : Theme.of(context).snackBarTheme.backgroundColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Eğer Scaffold yoksa, alternatif olarak debug print kullan
        _logger.i('SnackBar mesajı: $message');
      }
    } catch (e) {
      _logger.e('SnackBar gösterme hatası: $e');
      // Alternatif olarak debug print
      _logger.i('Mesaj: $message');
    }
  }

  String _getSelectedProjectName() {
    if (_selectedProjectID == 0) return 'Genel (Gruba ait)';
    
    try {
      final Project project = widget.projects.firstWhere(
        (Project p) => p.projectID == _selectedProjectID,
        orElse: () => Project(projectID: 0, projectName: 'Bilinmeyen Proje', projectStatus: '', projectStatusID: 0),
      );
      return project.projectName;
    } catch (e) {
      _logger.w('Proje adı alınırken hata: $_selectedProjectID, $e');
      return 'Proje Bulunamadı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = isCupertino(context);
    final ThemeData theme = Theme.of(context);
    final CupertinoThemeData cupertinoTheme = CupertinoTheme.of(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Rapor Oluştur'),
        leading: PlatformIconButton(
          icon: Icon(isIOS ? CupertinoIcons.back : Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        trailingActions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: PlatformCircularProgressIndicator(),
            )
          else
            PlatformTextButton(
              onPressed: _saveReport,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'KAYDET',
                style: TextStyle(
                  color: isIOS ? cupertinoTheme.primaryColor : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Rapor Bilgileri'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _titleController,
                hintText: 'Rapor başlığını girin',
                isIOS: isIOS,
                suffixIcon: PlatformIconButton(
                  icon: _isCorrecting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: PlatformCircularProgressIndicator(
                            material: (_, __) => MaterialProgressIndicatorData(strokeWidth: 2),
                            cupertino: (_, __) => CupertinoProgressIndicatorData(radius: 8),
                          ),
                        )
                      : Icon(
                          isIOS ? CupertinoIcons.textformat_abc : Icons.spellcheck,
                          color: isIOS ? cupertinoTheme.primaryColor : theme.colorScheme.primary,
                        ),
                  onPressed: _isCorrecting ? null : () => _correctSpelling(_titleController),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _dateController,
                hintText: 'GG.AA.YYYY',
                isIOS: isIOS,
                readOnly: true,
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),

              _buildProjectPicker(isIOS, theme, cupertinoTheme),
              const SizedBox(height: 24),

              _buildSectionTitle('Rapor Maddeleri'),
              const SizedBox(height: 12),
              
              _buildAddItemField(isIOS, theme, cupertinoTheme),
              const SizedBox(height: 18),

              if (_reportItems.isNotEmpty)
                _buildReportItemsList(isIOS, theme, cupertinoTheme)
              else
                _buildEmptyItemsPlaceholder(isIOS, theme, cupertinoTheme),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _selectDate() async {
    final bool isIOS = isCupertino(context);
    DateTime? pickedDate;

    if (isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (BuildContext context) {
          DateTime selectedDate = DateTime.now();
          return Container(
            height: 280,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                Container(
                  height: 50,
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          onPressed: () => Navigator.pop(context),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: const Text(
                            'İptal',
                            style: TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: CupertinoColors.systemGrey4.resolveFrom(context),
                      ),
                      Expanded(
                        child: CupertinoButton(
                          onPressed: () {
                            pickedDate = selectedDate;
                            Navigator.pop(context);
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: const Text(
                            'Tamam',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: DateTime.now(),
                    minimumDate: DateTime(2000),
                    maximumDate: DateTime(2101),
                    backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
                    onDateTimeChanged: (DateTime date) {
                      selectedDate = date;
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).colorScheme.primary,
              ),
            ),
            child: child!,
          );
        },
      );
    }

    if (pickedDate != null) {
      final String formattedDate =
          '${pickedDate!.day}.${pickedDate!.month}.${pickedDate!.year}';
      _safeSetState(() {
        _dateController.text = formattedDate;
      });
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isIOS,
    Widget? suffixIcon,
    bool readOnly = false,
    int? maxLines,
    TextInputAction? textInputAction,
    VoidCallback? onTap,
  }) {
    InputDecoration materialDecoration = InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
    );

    BoxDecoration cupertinoDecoration = BoxDecoration(
      border: Border.all(color: CupertinoColors.systemGrey4),
      borderRadius: BorderRadius.circular(10),
      color: CupertinoColors.systemGrey6,
    );

    return PlatformTextField(
      controller: controller,
      hintText: hintText,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      textInputAction: textInputAction,
      material: (_, __) => MaterialTextFieldData(
        decoration: materialDecoration,
      ),
      cupertino: (_, __) => CupertinoTextFieldData(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: cupertinoDecoration,
        suffix: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 8.0), child: suffixIcon) : null,
        keyboardAppearance: Brightness.light,
      ),
    );
  }

  Widget _buildProjectPicker(bool isIOS, ThemeData theme, CupertinoThemeData cupertinoTheme) {
    return InkWell(
      onTap: _selectProject,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _getSelectedProjectName(),
                style: TextStyle(
                  fontSize: 14,
                  color: isIOS ? cupertinoTheme.textTheme.textStyle.color : theme.textTheme.titleMedium?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              isIOS ? CupertinoIcons.chevron_down : Icons.keyboard_arrow_down,
              color: isIOS ? CupertinoColors.systemGrey2 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddItemField(bool isIOS, ThemeData theme, CupertinoThemeData cupertinoTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isIOS ? CupertinoColors.systemBackground : theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: _buildTextField(
                  controller: _currentItemController,
                  hintText: 'Yeni madde ekle...',
                  isIOS: isIOS,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PlatformTextButton(
                      onPressed: _isCorrecting ? null : () => _correctSpelling(_currentItemController),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isCorrecting)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: PlatformCircularProgressIndicator(
                                 material: (_, __) => MaterialProgressIndicatorData(strokeWidth: 2),
                                 cupertino: (_, __) => CupertinoProgressIndicatorData(radius: 8)
                              ),
                            )
                          else
                            Icon(
                              isIOS ? CupertinoIcons.textformat : Icons.spellcheck,
                              size: 18,
                              color: isIOS ? cupertinoTheme.primaryColor : theme.colorScheme.primary,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            'Düzelt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isIOS ? cupertinoTheme.primaryColor : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PlatformElevatedButton(
                      onPressed: _addReportItem,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      material: (_,__)=> MaterialElevatedButtonData(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        )
                      ),
                      cupertino: (_,__)=> CupertinoElevatedButtonData(
                         borderRadius: BorderRadius.circular(10),
                         padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIOS ? CupertinoIcons.add : Icons.add,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isIOS ? 'Ekle' : 'EKLE',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportItemsList(bool isIOS, ThemeData theme, CupertinoThemeData cupertinoTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Eklenen Maddeler',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isIOS ? CupertinoColors.secondaryLabel : theme.textTheme.titleMedium?.color,
              ),
            ),
            PlatformTextButton(
              onPressed: _isCorrecting ? null : _correctAllItemsSpelling,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isCorrecting)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: PlatformCircularProgressIndicator(
                         material: (_, __) => MaterialProgressIndicatorData(strokeWidth: 2),
                         cupertino: (_, __) => CupertinoProgressIndicatorData(radius: 8)
                      ),
                    )
                  else
                    Icon(
                      isIOS ? CupertinoIcons.textformat : Icons.spellcheck,
                      size: 18,
                      color: isIOS ? cupertinoTheme.primaryColor : theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    'Tümünü Düzelt',
                    style: TextStyle(
                      color: isIOS ? cupertinoTheme.primaryColor : theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isIOS ? CupertinoColors.systemBackground : theme.colorScheme.surface,
            border: Border.all(
              color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reportItems.length,
              separatorBuilder: (BuildContext context, int index) => Divider(
                height: 1,
                color: isIOS ? CupertinoColors.systemGrey5 : Colors.grey.shade200,
                indent: 12,
                endIndent: 12,
              ),
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minLeadingWidth: 20,
                    leading: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: (isIOS 
                            ? cupertinoTheme.primaryColor 
                            : theme.colorScheme.primary).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isIOS 
                                ? cupertinoTheme.primaryColor 
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      _reportItems[index],
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: PlatformIconButton(
                            padding: const EdgeInsets.all(6),
                            icon: Icon(
                              isIOS ? CupertinoIcons.pencil_circle : Icons.edit_outlined,
                              size: 22,
                              color: isIOS ? cupertinoTheme.primaryColor : theme.colorScheme.secondary,
                            ),
                            onPressed: () => _editReportItem(index),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: PlatformIconButton(
                            padding: const EdgeInsets.all(6),
                            icon: Icon(
                              isIOS ? CupertinoIcons.delete_simple : Icons.delete_outline,
                              size: 22,
                              color: isIOS ? CupertinoColors.destructiveRed : theme.colorScheme.error,
                            ),
                            onPressed: () => _removeReportItem(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyItemsPlaceholder(bool isIOS, ThemeData theme, CupertinoThemeData cupertinoTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemBackground : theme.colorScheme.surface,
        border: Border.all(
          color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isIOS ? CupertinoIcons.square_list : Icons.format_list_bulleted,
            size: 48,
            color: isIOS ? cupertinoTheme.primaryColor.withOpacity(0.3) : theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz Rapor Maddesi Yok',
            style: TextStyle(
              color: isIOS ? CupertinoColors.secondaryLabel : theme.textTheme.titleMedium?.color?.withOpacity(0.7),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Yukarıdaki alandan yeni maddeler ekleyebilirsiniz.',
            style: TextStyle(
              color: isIOS ? CupertinoColors.tertiaryLabel : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 