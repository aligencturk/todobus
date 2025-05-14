import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'dart:io' show Platform;
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
  
  bool _isLoading = false;
  bool _isDisposed = false;
  String _errorMessage = '';
  GroupDetail? _groupDetail;
  
  @override
  void initState() {
    super.initState();
    _loadGroupDetail();
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
                onTap: () {
                  // Takvime ekleme işlevi eklenecek
                  _showMessage('Takvime ekleme işlevi henüz mevcut değil');
                },
                color: isIOS ? CupertinoColors.systemGreen : Colors.green,
              ),
              _buildActionButton(
                icon: isIOS ? CupertinoIcons.share : Icons.share,
                label: 'Paylaş',
                onTap: () {
                  // Paylaşım işlevi eklenecek
                  _showMessage('Paylaşım işlevi henüz mevcut değil');
                },
                color: isIOS ? CupertinoColors.systemIndigo : Colors.indigo,
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