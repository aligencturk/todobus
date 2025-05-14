import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../viewmodels/group_viewmodel.dart';
import '../services/logger_service.dart';

class CreateGroupView extends StatefulWidget {
  const CreateGroupView({Key? key}) : super(key: key);

  @override
  _CreateGroupViewState createState() => _CreateGroupViewState();
}

class _CreateGroupViewState extends State<CreateGroupView> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _groupDescController = TextEditingController();
  final _logger = LoggerService();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _formSubmitted = false;
  
  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formSubmitted) return; // Çift gönderimi engelle
    
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _formSubmitted = true;
      });
      
      try {
        final groupName = _groupNameController.text.trim();
        final groupDesc = _groupDescController.text.trim();
        
        // Ana provider'dan GroupViewModel'e erişim
        final viewModel = Provider.of<GroupViewModel>(context, listen: false);
        final success = await viewModel.createGroup(groupName, groupDesc);
            
        if (success) {
          _logger.i('Grup başarıyla oluşturuldu: $groupName');
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'Grup oluşturulamadı. Lütfen tekrar deneyin.';
              _isLoading = false;
              _formSubmitted = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Hata: ${e.toString()}';
            _isLoading = false;
            _formSubmitted = false;
          });
        }
        _logger.e('Grup oluşturma hatası: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return WillPopScope(
      onWillPop: () async {
        return !_isLoading;
      },
      child: PlatformScaffold(
        backgroundColor: isIOS ? CupertinoColors.systemBackground : Colors.white,
        appBar: PlatformAppBar(
          title: Text('Yeni Grup Oluştur', 
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          cupertino: (_, __) => CupertinoNavigationBarData(
            transitionBetweenRoutes: false,
            backgroundColor: CupertinoColors.systemBackground,
          ),
          material: (_, __) => MaterialAppBarData(
            elevation: 0,
            backgroundColor: Colors.white,
          ),
          automaticallyImplyLeading: !_isLoading,
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _isLoading
              ? _buildLoadingState(isIOS)
              : _buildForm(isIOS),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingState(bool isIOS) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlatformCircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Grup oluşturuluyor...',
            style: TextStyle(
              fontSize: 16,
              color: isIOS ? CupertinoColors.systemGrey : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildForm(bool isIOS) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form başlığı
              const Text(
                'Grup Bilgileri',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Grubu oluşturmak için aşağıdaki bilgileri doldurun.',
                style: TextStyle(
                  fontSize: 15,
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              
              // Hata mesajı
              if (_errorMessage.isNotEmpty)
                _buildErrorMessage(isIOS),
              
              // Grup Adı Alanı
              const Text(
                'Grup Adı',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildGroupNameField(isIOS),
              
              const SizedBox(height: 24),
              
              // Grup Açıklaması Alanı
              const Text(
                'Grup Açıklaması',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildGroupDescField(isIOS),
              
              const SizedBox(height: 40),
              
              // Oluştur Butonu
              _buildCreateButton(isIOS),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage(bool isIOS) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemRed.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isIOS ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
            color: isIOS ? CupertinoColors.systemRed : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: isIOS ? CupertinoColors.systemRed : Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGroupNameField(bool isIOS) {
    return Container(
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemGrey6 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: PlatformTextFormField(
        controller: _groupNameController,
        hintText: 'Grup adını girin',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Lütfen bir grup adı girin';
          }
          return null;
        },
        material: (_, __) => MaterialTextFormFieldData(
          decoration: InputDecoration(
            hintText: 'Grup adını girin',
            prefixIcon: Icon(Icons.group, size: 22, color: Colors.grey[700]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        cupertino: (_, __) => CupertinoTextFormFieldData(
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(CupertinoIcons.person_2_fill, size: 22, color: CupertinoColors.systemGrey),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
  
  Widget _buildGroupDescField(bool isIOS) {
    return Container(
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemGrey6 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: PlatformTextFormField(
        controller: _groupDescController,
        hintText: isIOS ? 'Grup hakkında kısa bir açıklama girin (isteğe bağlı)' : 'Grup açıklaması (isteğe bağlı)',
        material: (_, __) => MaterialTextFormFieldData(
          decoration: InputDecoration(
            hintText: 'Grup açıklaması (isteğe bağlı)',
            prefixIcon: Icon(Icons.description, size: 22, color: Colors.grey[700]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          minLines: 3,
          maxLines: 5,
        ),
        cupertino: (_, __) => CupertinoTextFormFieldData(
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 8.0),
            child: Icon(CupertinoIcons.doc_text, size: 22, color: CupertinoColors.systemGrey),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          minLines: 3,
          maxLines: 4,
        ),
      ),
    );
  }
  
  Widget _buildCreateButton(bool isIOS) {
    final Color buttonColor = isIOS 
        ? const Color(0xFF3478F6) // iOS mavi
        : Colors.blue;
        
    return SizedBox(
      width: double.infinity,
      child: PlatformElevatedButton(
        onPressed: _submitForm,
        material: (_, __) => MaterialElevatedButtonData(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
        cupertino: (_, __) => CupertinoElevatedButtonData(
          color: buttonColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          'Grubu Oluştur',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
} 
