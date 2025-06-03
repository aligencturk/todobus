import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../viewmodels/report_viewmodel.dart';
import '../services/logger_service.dart';

class ReportDetailView extends StatefulWidget {
  final int reportId;
  final int groupId;
  
  const ReportDetailView({
    Key? key, 
    required this.reportId, 
    required this.groupId
  }) : super(key: key);
  
  @override
  _ReportDetailViewState createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  final LoggerService _logger = LoggerService();
  GroupReport? _report;
  bool _isLoading = true;
  bool _isDisposed = false;
  String _errorMessage = '';
  bool _isEditing = false;
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  int _selectedProjectId = 0;
  
  // Sabit renkler
  final Color _primaryTextColor = CupertinoColors.black;
  final Color _secondaryTextColor = CupertinoColors.black;
  final Color _primaryButtonColor = CupertinoColors.activeBlue;
  final Color _deleteButtonColor = CupertinoColors.destructiveRed;
  final Color _cardBorderColor = CupertinoColors.systemGrey5;
  final Color _cardBackgroundColor = CupertinoColors.systemBackground;
  
  @override
  void initState() {
    super.initState();
    _loadReportDetail();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }
  
  // Güvenli setState
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }
  
  Future<void> _loadReportDetail() async {
    _safeSetState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
      final report = await reportViewModel.getReportDetail(widget.reportId);
      
      if (report != null) {
        _safeSetState(() {
          _report = report;
          _isLoading = false;
          
          // Form alanlarını doldur
          _titleController.text = report.reportTitle;
          _descController.text = report.reportDesc;
          _dateController.text = report.reportDate;
          _selectedProjectId = report.projectID;
        });
        
        _logger.i('Rapor detayı yüklendi: ${report.reportTitle}');
      } else {
        _safeSetState(() {
          _errorMessage = 'Rapor bulunamadı';
          _isLoading = false;
        });
      }
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Rapor detayı yüklenemedi: $e';
        _isLoading = false;
      });
      _logger.e('Rapor detayı yüklenirken hata: $e');
    }
  }
  
  // Rapor güncelleme
  Future<void> _updateReport() async {
    if (_report == null) return;
    
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final date = _dateController.text.trim();
    
    if (title.isEmpty) {
      _showErrorAlert('Rapor başlığı boş olamaz');
      return;
    }
    
    if (desc.isEmpty) {
      _showErrorAlert('Rapor açıklaması boş olamaz');
      return;
    }
    
    _safeSetState(() => _isLoading = true);
    
    try {
      final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
      final success = await reportViewModel.updateReport(
        reportId: widget.reportId,
        groupId: widget.groupId,
        projectId: _selectedProjectId,
        title: title,
        desc: desc,
        date: date,
      );
      
      if (success) {
        await _loadReportDetail();
        _safeSetState(() => _isEditing = false);
        _showSuccessAlert('Rapor başarıyla güncellendi');
      } else {
        _safeSetState(() {
          _isLoading = false;
          _errorMessage = 'Rapor güncellenemedi';
        });
        _showErrorAlert('Rapor güncelleme işlemi başarısız oldu');
      }
    } catch (e) {
      _safeSetState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _showErrorAlert('Rapor güncellenirken hata oluştu: $_errorMessage');
    }
  }
  
  // Rapor silme
  Future<void> _deleteReport() async {
    if (_report == null) return;
    
    // Provider'ı modal popup'tan önce al
    final reportViewModel = Provider.of<ReportViewModel>(context, listen: false);
    
    showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'Raporu Silmek İstediğinize Emin Misiniz?',
          style: TextStyle(
            decoration: TextDecoration.none,
            color: _primaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        message: Text(
          'Bu işlem geri alınamaz.',
          style: TextStyle(
            decoration: TextDecoration.none,
            color: _secondaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context, true);
              _safeSetState(() => _isLoading = true);
              
              try {
                // Önceden alınan provider'ı kullan
                final success = await reportViewModel.deleteReport(widget.reportId);
                
                if (success) {
                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                } else {
                  _safeSetState(() {
                    _isLoading = false;
                    _errorMessage = 'Rapor silinemedi';
                  });
                  _showErrorAlert('Rapor silme işlemi başarısız oldu');
                }
              } catch (e) {
                _safeSetState(() {
                  _isLoading = false;
                  _errorMessage = e.toString();
                });
                _showErrorAlert('Rapor silinirken hata oluştu: $_errorMessage');
              }
            },
            child: Text(
              'Raporu Sil',
              style: TextStyle(
                decoration: TextDecoration.none,
                color: _deleteButtonColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(
            'Vazgeç',
            style: TextStyle(
              decoration: TextDecoration.none,
              color: _primaryButtonColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
    );
  }
  
  // Tarih seçme
  Future<void> _selectDate() async {
    final currentDate = _dateController.text.isNotEmpty
        ? _parseDate(_dateController.text)
        : DateTime.now();
    
    DateTime? pickedDate;
    
      await showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return Container(
          height: 260,
          color: _cardBackgroundColor,
          child: Column(
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _cardBackgroundColor,
                  border: Border(
                    bottom: BorderSide(color: _cardBorderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'İptal',
                        style: TextStyle(
                          decoration: TextDecoration.none,
                          color: _primaryButtonColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Tamam',
                        style: TextStyle(
                          decoration: TextDecoration.none,
                          color: _primaryButtonColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        if (pickedDate != null) {
                          final day = pickedDate!.day.toString().padLeft(2, '0');
                          final month = pickedDate!.month.toString().padLeft(2, '0');
                          final year = pickedDate!.year.toString();
                          _dateController.text = '$day.$month.$year';
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 22,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
              child: CupertinoDatePicker(
                initialDateTime: currentDate,
                mode: CupertinoDatePickerMode.date,
                use24hFormat: true,
                onDateTimeChanged: (date) {
                  pickedDate = date;
                },
              ),
                ),
              ),
            ],
            ),
          );
        },
      );
  }
  
  // String tarih değerini DateTime'a çevirir
  DateTime _parseDate(String date) {
    try {
      final parts = date.split('.');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]), // yıl
          int.parse(parts[1]), // ay
          int.parse(parts[0]), // gün
        );
      }
    } catch (e) {
      _logger.e('Tarih ayrıştırma hatası: $e');
    }
    return DateTime.now();
  }
  
  void _toggleEditMode() {
    _safeSetState(() {
      _isEditing = !_isEditing;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _cardBackgroundColor,
        border: Border(bottom: BorderSide(color: _cardBorderColor, width: 0.5)),
        middle: Text(
          _report?.reportTitle ?? 'Rapor Detayı',
          style: TextStyle(
            decoration: TextDecoration.none,
            color: _primaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        trailing: _report != null && !_isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isEditing 
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Text(
                            'Vazgeç',
                            style: TextStyle(
                              decoration: TextDecoration.none,
                              color: _primaryButtonColor,
                            ),
                          ),
                          onPressed: _toggleEditMode,
                        )
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(
                            CupertinoIcons.trash,
                            color: _deleteButtonColor,
                            size: 22,
                  ),
                  onPressed: _deleteReport,
                ),
                  const SizedBox(width: 8),
                  _isEditing
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Text(
                            'Kaydet',
                            style: TextStyle(
                              decoration: TextDecoration.none,
                              color: _primaryButtonColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _updateReport,
                        )
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Text(
                            'Düzenle',
                            style: TextStyle(
                              decoration: TextDecoration.none,
                              color: _primaryButtonColor,
                            ),
                          ),
                          onPressed: _toggleEditMode,
                        ),
                ],
              )
            : null,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                ),
              )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
                : _isEditing
                    ? _buildEditForm()
                    : _buildDetailView(),
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 56,
              color: _deleteButtonColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Hata Oluştu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                color: _primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                decoration: TextDecoration.none,
                color: _secondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              onPressed: _loadReportDetail,
              color: _primaryButtonColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Text(
                'Tekrar Dene',
                style: TextStyle(
                  decoration: TextDecoration.none,
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailView() {
    if (_report == null) return const SizedBox();
    
    return ListView(
      padding: const EdgeInsets.all(16),
        children: [
          // Rapor sahibi bilgisi
          Container(
          padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: _cardBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorderColor, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                width: 48,
                height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: _report!.userProfilePhoto.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_report!.userProfilePhoto),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: _report!.userProfilePhoto.isEmpty
                      ? _primaryButtonColor.withOpacity(0.2)
                        : null,
                  ),
                  child: _report!.userProfilePhoto.isEmpty
                      ? Center(
                          child: Text(
                            _report!.userFullname.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                            color: _primaryButtonColor,
                          ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _report!.userFullname,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                        color: _primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                      Text(
                        'Oluşturma: ${_formatDate(_report!.createDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          decoration: TextDecoration.none,
                          color: _secondaryTextColor,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
        const SizedBox(height: 20),
        
        // Rapor Detayları - iOS tarzı liste görünümü
        _buildDetailInfoSection('Rapor Bilgileri', [
          _buildDetailItem('Başlık', _report!.reportTitle),
          _buildDetailItem('Tarih', _report!.reportDate),
        ]),
        
        const SizedBox(height: 16),
        
        // Açıklama bölümü - salt okunur görünüm
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Açıklama',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  color: _secondaryTextColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorderColor, width: 0.5),
              ),
              child: Text(
                _report!.reportDesc,
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.none,
                  color: _primaryTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
          
        const SizedBox(height: 24),
        
        // Düzenleme butonu (Büyük düğme)
        _buildStylishButton(
          'Raporu Düzenle',
          _primaryButtonColor,
          CupertinoColors.white,
          _toggleEditMode,
          icon: CupertinoIcons.pen,
        ),
        
        const SizedBox(height: 12),
        
        // Silme butonu
        _buildStylishButton(
          'Raporu Sil',
          _deleteButtonColor,
          CupertinoColors.white,
          _deleteReport,
          icon: CupertinoIcons.trash,
        ),
      ],
    );
  }
  
  Widget _buildStylishButton(
    String label,
    Color color,
    Color textColor,
    VoidCallback onPressed, {
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                decoration: TextDecoration.none,
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailInfoSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
              color: _secondaryTextColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorderColor, width: 0.5),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _cardBorderColor, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.none,
              color: _secondaryTextColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.none,
              color: _primaryTextColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditForm() {
    if (_report == null) return const SizedBox();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Form grupları
        _buildFormSection('Rapor Bilgileri', [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Başlık',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    color: _secondaryTextColor,
                  ),
                ),
              ),
              _buildInputField(
                controller: _titleController,
                hintText: "Rapor başlığı",
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Tarih',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    color: _secondaryTextColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _selectDate,
                child: _buildInputField(
                  controller: _dateController,
                  hintText: "GG.AA.YYYY",
                  suffix: Icon(
                    CupertinoIcons.calendar,
                    size: 20,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ],
          ),
        ]),
        
        const SizedBox(height: 20),
        
        _buildFormSection('Açıklama',[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Rapor İçeriği',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    color: _secondaryTextColor,
                  ),
                ),
              ),
              // Geliştirilmiş açıklama giriş alanı
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _cardBorderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey5.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: CupertinoTextField(
                  controller: _descController,
                  maxLines: 6,
                  minLines: 6,
                  placeholder: 'Rapor açıklaması',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.extraLightBackgroundGray,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  style: TextStyle(
                    color: _primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  placeholderStyle: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ]),
        
        const SizedBox(height: 24),
        
        // Kaydet butonu
        _buildStylishButton(
          'Değişiklikleri Kaydet',
          _primaryButtonColor,
          CupertinoColors.white,
          _updateReport,
          icon: CupertinoIcons.check_mark,
        ),
        
        const SizedBox(height: 12),
        
        // İptal butonu
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(width: 0.5, color: _cardBorderColor),
          ),
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: _toggleEditMode,
            child: Text(
              'Vazgeç',
              style: TextStyle(
                decoration: TextDecoration.none,
                color: _secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: maxLines > 1 ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(width: 0.5, color: _cardBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              maxLines: maxLines,
              minLines: maxLines,
              placeholder: hintText,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              style: TextStyle(
                fontSize: 16,
                color: _primaryTextColor,
              ),
              placeholderStyle: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 16,
              ),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }
  
  Widget _buildFormSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
              color: _secondaryTextColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(width: 0.5, color: _cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items,
          ),
        ),
      ],
    );
  }
  
  // Hata mesajı göster (iOS tarzı)
  void _showErrorAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          'Hata',
          style: TextStyle(
            decoration: TextDecoration.none,
            color: _deleteButtonColor,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'Tamam',
              style: TextStyle(
                decoration: TextDecoration.none,
                color: _primaryButtonColor,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
  
  // Başarı mesajı göster (iOS tarzı)
  void _showSuccessAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          'Başarılı',
          style: TextStyle(
            decoration: TextDecoration.none,
            color: CupertinoColors.activeGreen,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'Tamam',
              style: TextStyle(
                decoration: TextDecoration.none,
                color: _primaryButtonColor,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
  
  // Tarih formatını düzenle
  String _formatDate(String date) {
    try {
      final parts = date.split('.');
      if (parts.length == 3) {
        final day = parts[0];
        final month = parts[1];
        final year = parts[2];
        return '$day/$month/$year';
      }
    } catch (e) {
      _logger.e('Tarih formatı hatası: $e');
    }
    return date;
  }
} 