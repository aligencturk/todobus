import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';

class EditGroupView extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String groupDesc;

  const EditGroupView({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupDesc,
  }) : super(key: key);

  @override
  _EditGroupViewState createState() => _EditGroupViewState();
}

class _EditGroupViewState extends State<EditGroupView> {
  final LoggerService _logger = LoggerService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _descController;
  
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.groupName);
    _descController = TextEditingController(text: widget.groupDesc);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _updateGroup() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final newName = _nameController.text.trim();
    final newDesc = _descController.text.trim();

    if (newName.isEmpty) {
      setState(() {
        _errorMessage = 'Grup adı boş olamaz';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .updateGroup(widget.groupId, newName, newDesc);

      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Grup güncellenemedi.';
        });
      }
    } catch (e) {
      _logger.e('Grup güncellenirken hata: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Grup güncellenirken hata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Grubu Düzenle'),
        trailingActions: [
          PlatformIconButton(
            icon: Icon(
              isIOS ? CupertinoIcons.check_mark : Icons.check,
            ),
            onPressed: _isLoading ? null : _updateGroup,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: _isLoading
              ? Center(child: PlatformCircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: isIOS
                                ? CupertinoColors.systemRed.withOpacity(0.1)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: isIOS
                                  ? CupertinoColors.systemRed
                                  : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildNameField(isIOS),
                      const SizedBox(height: 16),
                      _buildDescField(isIOS),
                      const SizedBox(height: 24),
                      PlatformElevatedButton(
                        onPressed: _isLoading ? null : _updateGroup,
                        child: Text(
                          'Güncelle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNameField(bool isIOS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Grup Adı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isIOS 
                  ? CupertinoColors.secondaryLabel 
                  : Colors.grey[700],
            ),
          ),
        ),
        isIOS
            ? CupertinoTextField(
                controller: _nameController,
                padding: const EdgeInsets.all(12),
                placeholder: 'Grup adı',
                clearButtonMode: OverlayVisibilityMode.editing,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            : TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Grup adı',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, 
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Grup adı boş olamaz';
                  }
                  return null;
                },
              ),
      ],
    );
  }

  Widget _buildDescField(bool isIOS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Grup Açıklaması',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isIOS 
                  ? CupertinoColors.secondaryLabel 
                  : Colors.grey[700],
            ),
          ),
        ),
        isIOS
            ? CupertinoTextField(
                controller: _descController,
                padding: const EdgeInsets.all(12),
                placeholder: 'Grup açıklaması',
                minLines: 3,
                maxLines: 5,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            : TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  hintText: 'Grup açıklaması',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, 
                    vertical: 16,
                  ),
                ),
                minLines: 3,
                maxLines: 5,
              ),
      ],
    );
  }
} 