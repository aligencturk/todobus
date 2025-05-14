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
        // Eğer form gönderimi devam ediyorsa, geri tuşunu devre dışı bırak
        return !_isLoading;
      },
      child: PlatformScaffold(
        appBar: PlatformAppBar(
          title: const Text('Yeni Grup Oluştur'),
          cupertino: (_, __) => CupertinoNavigationBarData(
            transitionBetweenRoutes: false,
          ),
          // İslem devam ederken geri düğmesini devre dışı bırak
          automaticallyImplyLeading: !_isLoading,
        ),
        body: SafeArea(
          child: _isLoading
              ? Center(
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
                          fontWeight: isIOS ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage.isNotEmpty)
                              _buildErrorMessage(isIOS),
                            
                            // Grup Adı Alanı
                            if (isIOS)
                              _buildIOSLabel('Grup Adı'),
                            _buildGroupNameField(isIOS),
                            
                            const SizedBox(height: 16),
                            
                            // Grup Açıklaması Alanı
                            if (isIOS)
                              _buildIOSLabel('Grup Açıklaması'),
                            _buildGroupDescField(isIOS),
                            
                            const SizedBox(height: 32),
                            
                            // Oluştur Butonu
                            _buildCreateButton(isIOS),
                          ],
                        ),
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage(bool isIOS) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemRed.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isIOS ? CupertinoColors.systemRed.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildIOSLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: CupertinoColors.secondaryLabel,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildGroupNameField(bool isIOS) {
    return PlatformTextFormField(
      controller: _groupNameController,
      hintText: 'Grup Adı',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Lütfen bir grup adı girin';
        }
        return null;
      },
      material: (_, __) => MaterialTextFormFieldData(
        decoration: const InputDecoration(
          labelText: 'Grup Adı',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
  
  Widget _buildGroupDescField(bool isIOS) {
    return PlatformTextFormField(
      controller: _groupDescController,
      hintText: 'Grup Açıklaması',
      material: (_, __) => MaterialTextFormFieldData(
        decoration: const InputDecoration(
          labelText: 'Grup Açıklaması',
          border: OutlineInputBorder(),
        ),
        minLines: 3,
        maxLines: 5,
      ),
      cupertino: (_, __) => CupertinoTextFormFieldData(
        placeholder: 'Grup Açıklaması (isteğe bağlı)',
        minLines: 3,
        maxLines: 5,
      ),
    );
  }
  
  Widget _buildCreateButton(bool isIOS) {
    return PlatformElevatedButton(
      onPressed: _submitForm,
      child: const Text('Grubu Oluştur'),
      material: (_, __) => MaterialElevatedButtonData(
        icon: const Icon(Icons.group_add),
      ),
    );
  }
} 