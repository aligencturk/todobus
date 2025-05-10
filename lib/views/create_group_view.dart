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
  final LoggerService _logger = LoggerService();
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final groupName = _groupNameController.text.trim();
      final groupDesc = _groupDescController.text.trim();
      
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        final success = await Provider.of<GroupViewModel>(context, listen: false)
            .createGroup(groupName, groupDesc);
            
        if (success) {
          _logger.i('Grup başarıyla oluşturuldu: $groupName');
          if (mounted) {
            // Başarılı olduğunda önceki sayfaya dön
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _errorMessage = 'Grup oluşturulamadı. Lütfen tekrar deneyin.';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Hata: ${e.toString()}';
          _isLoading = false;
        });
        _logger.e('Grup oluşturma hatası: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Yeni Grup Oluştur'),
        cupertino: (_, __) => CupertinoNavigationBarData(
          transitionBetweenRoutes: false,
        ),
      ),
      body: _isLoading
          ? Center(child: PlatformCircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: isIOS ? CupertinoColors.systemRed : Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Grup Adı Alanı
                      if (isIOS)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Grup Adı',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      PlatformTextFormField(
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
                      ),
                      const SizedBox(height: 16),
                      // Grup Açıklaması Alanı
                      if (isIOS)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Grup Açıklaması',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      PlatformTextFormField(
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
                      ),
                      const SizedBox(height: 32),
                      // Kaydet Butonu
                      PlatformElevatedButton(
                        onPressed: _submitForm,
                        child: const Text('Grubu Oluştur'),
                        material: (_, __) => MaterialElevatedButtonData(
                          icon: const Icon(Icons.group_add),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
} 