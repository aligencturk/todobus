import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'dart:io' show Platform;
import '../services/ai_assistant_service.dart';
import '../services/logger_service.dart';

class AIChatWidget extends StatefulWidget {
  const AIChatWidget({Key? key}) : super(key: key);

  @override
  State<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends State<AIChatWidget> 
    with TickerProviderStateMixin {
  final AIAssistantService _aiService = AIAssistantService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LoggerService _logger = LoggerService();
  final FocusNode _inputFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      await _aiService.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = _aiService.isInitialized;
        });
      }
    } catch (e) {
      _logger.e('AI servisi başlatılamadı: $e');
    }
  }

  void _startNewChat() {
    _aiService.clearChat();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading || !_isInitialized) return;

    setState(() {
      _isLoading = true;
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();
    
    try {
      await _aiService.sendMessage(message);
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      _logger.e('Mesaj gönderilirken hata: $e');
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _showErrorSnackBar('Mesaj gönderilemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, color: CupertinoColors.systemRed, size: 20),
            SizedBox(width: 8),
            Text('Hata'),
          ],
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Tamam'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showBetaInfo() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.info_circle, color: CupertinoColors.systemBlue, size: 24),
            SizedBox(width: 8),
            Text('Beta Sürümü'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12),
            Text(
              'AI Asistan şu anda beta sürecindedir. Deneyiminizi geliştirmek için geri dönüşleriniz çok değerli!',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Text(
              'Önerilerinizi ve hata bildirimlerinizi şu adrese gönderebilirsiniz:',
              style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
            ),
            SizedBox(height: 8),
            Text(
              'info@todobus.tr',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemBlue,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('E-posta Kopyala'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'info@todobus.tr'));
              Navigator.pop(context);
              _showSuccessSnackBar('E-posta adresi kopyalandı!');
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Tamam'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.check_mark_circled,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // 2 saniye sonra kaldır
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSuccessSnackBar('Mesaj kopyalandı!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildChatArea()),
          if (_isInitialized) _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: CupertinoColors.systemBlue,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.only(left: 16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.chat_bubble_2,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AI Asistan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'BETA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                Icons.circle,
                color: CupertinoColors.systemGreen,
                size: 8,
              ),
              SizedBox(width: 6),
              Text(
                'Çevrimiçi',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_isInitialized && _aiService.chatHistory.isNotEmpty)
          IconButton(
            icon: const Icon(CupertinoIcons.refresh, color: Colors.white),
            onPressed: _startNewChat,
          ),
        IconButton(
          icon: const Icon(CupertinoIcons.info_circle, color: Colors.white),
          onPressed: _showBetaInfo,
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildChatArea() {
    final messages = _aiService.chatHistory;

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(messages[index]);
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 16),
          SizedBox(height: 16),
          Text(
            'AI Asistan başlatılıyor...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2,
            size: 64,
            color: CupertinoColors.systemBlue,
          ),
          SizedBox(height: 24),
          Text(
            'AI Asistan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.label,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Proje yönetimi ve iş akışı konularında\nsize yardımcı olmak için buradayım.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: CupertinoColors.systemBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.chat_bubble_2,
              color: Colors.white,
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Yazıyor...',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.chat_bubble_2,
                color: Colors.white,
                size: 10,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyMessage(message.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isUser ? Colors.white : CupertinoColors.label,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemGrey4,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.person,
                size: 10,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _inputFocusNode.hasFocus 
                      ? CupertinoColors.systemBlue
                      : Colors.transparent,
                    width: _inputFocusNode.hasFocus ? 2 : 0,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _inputFocusNode,
                  enabled: !_isLoading,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.label,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Mesajınızı yazın...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(
                      color: CupertinoColors.placeholderText,
                      fontSize: 15,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isLoading || _messageController.text.trim().isEmpty
                  ? CupertinoColors.systemGrey4
                  : CupertinoColors.systemBlue,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: (_isLoading || _messageController.text.trim().isEmpty) 
                    ? null 
                    : _sendMessage,
                  child: _isLoading
                      ? const Center(
                          child: CupertinoActivityIndicator(
                            color: Colors.white,
                            radius: 10,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.paperplane_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}