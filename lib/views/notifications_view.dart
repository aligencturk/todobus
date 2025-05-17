import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import 'package:intl/intl.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({Key? key}) : super(key: key);

  @override
  _NotificationsViewState createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final NotificationService _notificationService = NotificationService.instance;
  final LoggerService _logger = LoggerService();
  
  List<NotificationModel>? _notifications;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final notifications = await _notificationService.fetchNotifications();
      
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Bildirimler yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Bildirimler yüklenemedi: $e';
      });
    }
  }



  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Bildirimler'),
        trailingActions: [
          PlatformIconButton(
            icon: Icon(PlatformIcons(context).refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700]),
            ),
            const SizedBox(height: 16),
            PlatformElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_notifications == null || _notifications!.isEmpty) {
      return const Center(
        child: Text('Bildirim bulunamadı'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: _notifications!.length,
        itemBuilder: (context, index) {
          final notification = _notifications![index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.message),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(notification.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              leading: CircleAvatar(
                backgroundColor: notification.isRead 
                    ? Colors.grey[200] 
                    : Theme.of(context).primaryColor,
                child: Icon(
                  Icons.notifications,
                  color: notification.isRead ? Colors.grey[600] : Colors.white,
                ),
              ),
              onTap: () {
                // Bildirime tıklandığında yapılacak işlemler
                _logger.i('Bildirime tıklandı: ${notification.id}');
               
                // Bildirim verilerine göre yönlendirme yapılabilir
                if (notification.data != null && notification.data!.containsKey('screen')) {
                  _logger.i('Bildirim yönlendirmesi: ${notification.data!['screen']}');
                  // Navigator.of(context).pushNamed(notification.data!['screen']);
                }
              },
            ),
          );
        },
      ),
    );
  }
} 