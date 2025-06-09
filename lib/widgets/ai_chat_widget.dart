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
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeAI();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
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
    _animationController.dispose();
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: _buildChatInterface(),
          ),
        );
      },
    );
  }

  Widget _buildChatInterface() {
    final theme = Theme.of(context);
    final isIOS = Platform.isIOS;
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(isIOS, theme),
          _buildChatArea(isIOS),
          if (_isInitialized) _buildInputArea(isIOS, theme),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isIOS, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.chat_bubble_2,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'AI Asistan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BETA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isInitialized ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isInitialized ? 'Çevrimiçi' : 'Bağlanıyor...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _showBetaInfo,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      CupertinoIcons.info_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            if (_isInitialized && _aiService.chatHistory.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _startNewChat,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        CupertinoIcons.refresh,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea(bool isIOS) {
    final messages = _aiService.chatHistory;

    return Expanded(
      child: !_isInitialized
          ? _buildLoadingState(isIOS)
          : messages.isEmpty
              ? _buildEmptyState(isIOS)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && _isTyping) {
                      return _buildTypingIndicator(isIOS);
                    }
                    return _buildMessageBubble(messages[index], isIOS);
                  },
                ),
    );
  }

  Widget _buildLoadingState(bool isIOS) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CupertinoActivityIndicator(radius: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'AI Asistan başlatılıyor...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu birkaç saniye sürebilir',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isIOS) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemBlue.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.chat_bubble_2,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'AI Asistan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: CupertinoColors.systemBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'BETA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemBlue,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Akıllı Sohbet Asistanınız',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemBlue,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Proje yönetimi, görev planlama ve iş akışı konularında\nsize yardımcı olmak için buradayım.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
              height: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '💡 İpucu: Mesajları kopyalamak için basılı tutun',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isIOS) {
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Yazıyor',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 400 + (index * 100)),
                        curve: Curves.easeInOut,
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemGrey3,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isIOS) {
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
                  boxShadow: [
                    BoxShadow(
                      color: isUser 
                        ? CupertinoColors.systemBlue.withOpacity(0.3)
                        : Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isUser ? Colors.white : CupertinoColors.label,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
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

  Widget _buildInputArea(bool isIOS, ThemeData theme) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 
        16, 
        20, 
        keyboardHeight > 0 ? 16 : 20
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: keyboardHeight > 0 ? 8 : 0),
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
                  maxLines: keyboardHeight > 0 ? 2 : 4, // Klavye açıkken satır sayısını azalt
                  minLines: 1,
                  style: const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.label,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Mesajınızı yazın...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    hintStyle: TextStyle(
                      color: CupertinoColors.placeholderText,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: _isLoading || _messageController.text.trim().isEmpty
                  ? CupertinoColors.systemGrey4
                  : CupertinoColors.systemBlue,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: (_isLoading || _messageController.text.trim().isEmpty) 
                    ? null 
                    : _sendMessage,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: _isLoading
                        ? const CupertinoActivityIndicator(
                            color: Colors.white,
                            radius: 12,
                          )
                        : const Icon(
                            CupertinoIcons.paperplane_fill,
                            color: Colors.white,
                            size: 18,
                          ),
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