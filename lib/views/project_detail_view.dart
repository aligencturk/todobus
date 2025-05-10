import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/snackbar_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../views/edit_project_view.dart';
import '../views/work_detail_view.dart';

class ProjectDetailView extends StatefulWidget {
  final int projectId;
  final int groupId;
  
  const ProjectDetailView({
    Key? key, 
    required this.projectId, 
    required this.groupId
  }) : super(key: key);
  
  @override
  _ProjectDetailViewState createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> {
  final LoggerService _logger = LoggerService();
  final SnackBarService _snackBarService = SnackBarService();
  
  ProjectDetail? _projectDetail;
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedSegment = 0; // 0: Bilgiler, 1: Kullanıcılar, 2: Görevler
  
  // Proje görevlerini yükle
  List<ProjectWork>? _projectWorks;
  bool _isLoadingWorks = false;
  String _worksErrorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadProjectDetail();
  }
  
  Future<void> _loadProjectDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final projectDetail = await Provider.of<GroupViewModel>(context, listen: false)
          .getProjectDetail(widget.projectId, widget.groupId);
      
      if (projectDetail != null) {
        setState(() {
          _projectDetail = projectDetail;
          _isLoading = false;
        });
        _logger.i('Proje detayları yüklendi: ${projectDetail.projectName}');
      } else {
        setState(() {
          _errorMessage = 'Proje detayları bulunamadı';
          _isLoading = false;
        });
        _logger.e('Proje detayları bulunamadı');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Proje detayları yüklenemedi: $e';
        _isLoading = false;
      });
      _logger.e('Proje detayları yüklenirken hata: $e');
    }
  }
  
  Future<void> _loadProjectWorks() async {
    if (_projectWorks != null) return; // Daha önce yüklenmişse tekrar yükleme
    
    setState(() {
      _isLoadingWorks = true;
      _worksErrorMessage = '';
    });
    
    try {
      final works = await Provider.of<GroupViewModel>(context, listen: false)
          .getProjectWorks(widget.projectId);
      
      setState(() {
        _projectWorks = works;
        _isLoadingWorks = false;
      });
      _logger.i('Proje görevleri yüklendi: ${works.length} görev');
    } catch (e) {
      setState(() {
        _worksErrorMessage = 'Görevler yüklenemedi: $e';
        _isLoadingWorks = false;
      });
      _logger.e('Proje görevleri yüklenirken hata: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_projectDetail?.projectName ?? 'Proje Detayı'),
        trailingActions: _projectDetail != null
            ? [
                PlatformIconButton(
                  icon: Icon(
                    isCupertino(context) ? CupertinoIcons.pencil : Icons.edit,
                  ),
                  onPressed: _editProject,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView(context)
                : _buildBody(context),
      ),
    );
  }
  
  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildProjectHeader(context),
        _buildSegmentedControl(context),
        Expanded(
          child: _buildSelectedContent(context),
        ),
      ],
    );
  }
  
  Widget _buildErrorView(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return SingleChildScrollView(
      child: Center(
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
                'İşlem Tamamlanamadı',
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
                onPressed: _loadProjectDetail,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Hata mesajlarını temizleme
  String _formatErrorMessage(String errorMessage) {
    // Exception: hatası gibi prefix'leri kaldır
    if (errorMessage.startsWith('Exception: ')) {
      errorMessage = errorMessage.substring('Exception: '.length);
    }
    
    // HTTP kodlarını temizle
    final regExp = RegExp(r'\b\d{3}\b');
    errorMessage = errorMessage.replaceAll(regExp, '');
    
    // Teknik detayları içeren uzun hataları kısalt
    if (errorMessage.length > 120) {
      return '${errorMessage.substring(0, 120)}...';
    }
    
    return errorMessage;
  }
  
  Widget _buildProjectHeader(BuildContext context) {
    final project = _projectDetail!;
    final isIOS = isCupertino(context);
    
    // İlerleme yüzdesini double'a çevir
    final progress = double.tryParse(project.projectProgress) ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: isIOS 
          ? CupertinoColors.systemBlue.withOpacity(0.1)
          : Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.projectName,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.titleLarge,
                        cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (project.projectDesc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        project.projectDesc,
                        style: platformThemeData(
                          context,
                          material: (data) => data.textTheme.bodyMedium,
                          cupertino: (data) => data.textTheme.textStyle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(project.projectStatusID, isIOS).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  project.projectStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(project.projectStatusID, isIOS),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Proje İlerlemesi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isIOS ? CupertinoColors.label : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: isIOS 
                  ? CupertinoColors.systemGrey5
                  : Colors.grey[300],
              color: isIOS
                  ? CupertinoColors.activeBlue
                  : Theme.of(context).colorScheme.primary,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '%${project.projectProgress}',
              style: TextStyle(
                fontSize: 12,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildInfoItem(
                context,
                icon: isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                label: 'Başlama',
                value: project.proStartDate,
              ),
              _buildInfoItem(
                context,
                icon: isIOS ? CupertinoIcons.calendar_badge_plus : Icons.event,
                label: 'Bitiş',
                value: project.proEndDate,
              ),
              _buildInfoItem(
                context,
                icon: isIOS ? CupertinoIcons.person : Icons.person,
                label: 'Oluşturan',
                value: project.createdBy,
              ),
              _buildInfoItem(
                context,
                icon: isIOS ? CupertinoIcons.person_2 : Icons.people,
                label: 'Üyeler',
                value: '${project.users.length} kişi',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isIOS = isCupertino(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isIOS ? CupertinoColors.label : Colors.black87,
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(int statusID, bool isIOS) {
    switch (statusID) {
      case 1: // Yeni Proje
        return isIOS ? CupertinoColors.systemBlue : Colors.blue;
      case 2: // Devam Ediyor
        return isIOS ? CupertinoColors.systemOrange : Colors.orange;
      case 3: // Tamamlandı
        return isIOS ? CupertinoColors.systemGreen : Colors.green;
      case 4: // İptal Edildi
        return isIOS ? CupertinoColors.systemRed : Colors.red;
      case 5: // Beklemede
        return isIOS ? CupertinoColors.systemGrey : Colors.grey;
      default:
        return isIOS ? CupertinoColors.systemBlue : Colors.blue;
    }
  }
  
  Widget _buildSegmentedControl(BuildContext context) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      final Map<int, Widget> segments = {
        0: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Bilgiler'),
        ),
        1: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Üyeler'),
        ),
        2: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Görevler'),
        ),
      };
      
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedSegment,
          onValueChanged: (value) {
            if (value != null) {
              _onSegmentChanged(value);
            }
          },
          children: segments,
        ),
      );
    } else {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMaterialTab(context, 'Bilgiler', 0),
            _buildMaterialTab(context, 'Üyeler', 1),
            _buildMaterialTab(context, 'Görevler', 2),
          ],
        ),
      );
    }
  }
  
  Widget _buildMaterialTab(BuildContext context, String title, int index) {
    return InkWell(
      onTap: () {
        _onSegmentChanged(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _selectedSegment == index 
                ? Theme.of(context).colorScheme.primary 
                : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: _selectedSegment == index 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: _selectedSegment == index 
                ? FontWeight.bold 
                : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  void _onSegmentChanged(int value) {
    setState(() {
      _selectedSegment = value;
    });
    
    // Görevler sekmesi seçildiyse görevleri yükle
    if (value == 2) {
      _loadProjectWorks();
    }
  }
  
  Widget _buildSelectedContent(BuildContext context) {
    switch (_selectedSegment) {
      case 0:
        return _buildInfoTab(context);
      case 1:
        return _buildMembersTab(context);
      case 2:
        return _buildTasksTab(context);
      default:
        return _buildInfoTab(context);
    }
  }
  
  Widget _buildInfoTab(BuildContext context) {
    final project = _projectDetail!;
    final isIOS = isCupertino(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proje Bilgileri',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navTitleTextStyle,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: isIOS ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isIOS 
                ? BorderSide(color: CupertinoColors.systemGrey5) 
                : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    context, 
                    label: 'Proje Adı', 
                    value: project.projectName,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context, 
                    label: 'Açıklama', 
                    value: project.projectDesc.isNotEmpty 
                      ? project.projectDesc 
                      : 'Açıklama bulunmuyor',
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context, 
                    label: 'Durum', 
                    value: project.projectStatus,
                    valueColor: _getStatusColor(project.projectStatusID, isIOS),
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context, 
                    label: 'Oluşturan', 
                    value: project.createdBy,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context, 
                    label: 'Başlangıç Tarihi', 
                    value: project.proStartDate,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context, 
                    label: 'Bitiş Tarihi', 
                    value: project.proEndDate,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    context, 
                    label: 'Oluşturma Tarihi', 
                    value: project.proCreateDate,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Hızlı İşlemler',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navTitleTextStyle,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionButton(
                icon: isIOS ? CupertinoIcons.square_list : Icons.playlist_add_check,
                color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                label: 'Görev Ekle',
                onTap: _showAddWorkDialog,
              ),
              _buildQuickActionButton(
                icon: isIOS ? CupertinoIcons.person_badge_plus : Icons.person_add,
                color: isIOS ? CupertinoColors.systemGreen : Colors.green,
                label: 'Üye Ekle',
                onTap: () {
                  // Üye ekleme işlevi eklenecek
                },
              ),
              _buildQuickActionButton(
                icon: isIOS ? CupertinoIcons.chart_bar : Icons.bar_chart,
                color: isIOS ? CupertinoColors.systemOrange : Colors.orange,
                label: 'Rapor',
                onTap: () {
                  // Rapor işlevi eklenecek
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(BuildContext context, {
    required String label, 
    required String value,
    Color? valueColor,
  }) {
    final isIOS = isCupertino(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor ?? (isIOS ? CupertinoColors.label : Colors.black87),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
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
  
  Widget _buildMembersTab(BuildContext context) {
    final project = _projectDetail!;
    final isIOS = isCupertino(context);
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Proje Üyeleri (${project.users.length})',
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                cupertino: (data) => data.textTheme.navTitleTextStyle,
              ),
            ),
            PlatformIconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                isIOS ? CupertinoIcons.person_add : Icons.person_add,
                color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                size: 20,
              ),
              onPressed: () {
                // Üye ekleme işlevi eklenecek
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...project.users.map((user) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: user.userRoleID == 1 
                  ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.2) 
                  : (isIOS ? CupertinoColors.systemGrey : Colors.grey).withOpacity(0.2),
              child: Text(
                user.userName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: user.userRoleID == 1 
                      ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                      : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                ),
              ),
            ),
            title: Text(user.userName),
            subtitle: Text(user.userRole),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.assignedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                PlatformIconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isIOS ? CupertinoIcons.trash : Icons.delete_outline,
                    color: isIOS ? CupertinoColors.destructiveRed : Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _confirmRemoveUser(user),
                ),
              ],
            ),
          ),
        )).toList(),
      ],
    );
  }
  
  Widget _buildTasksTab(BuildContext context) {
    final isIOS = isCupertino(context);
    
    if (_isLoadingWorks) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlatformCircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Görevler yükleniyor...',
              style: TextStyle(
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_worksErrorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isIOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline,
                size: 48,
                color: isIOS ? CupertinoColors.systemRed : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Görevler yüklenemedi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatErrorMessage(_worksErrorMessage),
                style: TextStyle(
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PlatformElevatedButton(
                onPressed: _loadProjectWorks,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_projectWorks == null || _projectWorks!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isIOS ? CupertinoIcons.square_list : Icons.assignment,
                size: 48,
                color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz görev bulunmuyor',
                style: TextStyle(
                  fontSize: 16,
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              PlatformElevatedButton(
                onPressed: _showAddWorkDialog,
                child: Text(
                  '+ Görev Ekle',
                  style: TextStyle(
                    color: isIOS ? CupertinoColors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Görevleri listeleyen sabit boyutlu widget
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Görevler (${_projectWorks!.length})',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  cupertino: (data) => data.textTheme.navTitleTextStyle,
                ),
              ),
              PlatformIconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isIOS ? CupertinoIcons.add : Icons.add,
                  color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  size: 20,
                ),
                onPressed: _showAddWorkDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            shrinkWrap: false,
            itemCount: _projectWorks!.length,
            itemBuilder: (context, index) {
              final work = _projectWorks![index];
              return _buildWorkItem(context, work);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildWorkItem(BuildContext context, ProjectWork work) {
    final isIOS = isCupertino(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: isIOS ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isIOS ? BorderSide(color: CupertinoColors.systemGrey5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          // Direkt görev detay sayfasına yönlendir
          Navigator.push(
            context,
            platformPageRoute(
              context: context,
              builder: (context) => WorkDetailView(
                projectId: widget.projectId,
                groupId: widget.groupId,
                workId: work.workID,
              ),
            ),
          ).then((_) {
            // Görev detay sayfasından döndüğünde görevleri yenile
            _projectWorks = null;
            _loadProjectWorks();
          });
        },
        onLongPress: () => _showWorkDetailActions(work),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tamamlanma durumu işareti - tıklanabilir
                  GestureDetector(
                    onTap: () => _toggleWorkCompletionStatus(work),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: work.workCompleted 
                            ? (isIOS ? CupertinoColors.systemGreen : Colors.green).withOpacity(0.2)
                            : (isIOS ? CupertinoColors.systemGrey : Colors.grey).withOpacity(0.2),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        work.workCompleted 
                            ? (isIOS ? CupertinoIcons.checkmark_alt : Icons.check)
                            : (isIOS ? CupertinoIcons.time : Icons.schedule),
                        size: 16,
                        color: work.workCompleted 
                            ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
                            : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          work.workName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isIOS ? CupertinoColors.label : Colors.black87,
                            decoration: work.workCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (work.workDesc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            work.workDesc,
                            style: TextStyle(
                              fontSize: 14,
                              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              decoration: work.workCompleted ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                color: isIOS ? CupertinoColors.systemGrey5 : Colors.grey[300],
                height: 16,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                        size: 14,
                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${work.workStartDate} - ${work.workEndDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        isIOS ? CupertinoIcons.person_2 : Icons.people,
                        size: 14,
                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${work.workUsers.length} üye',
                        style: TextStyle(
                          fontSize: 12,
                          color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (work.workUsers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: work.workUsers.map((user) => _buildUserChip(context, user)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildUserChip(BuildContext context, WorkUser user) {
    final isIOS = isCupertino(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemGrey6 : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        user.userName,
        style: TextStyle(
          fontSize: 12,
          color: isIOS ? CupertinoColors.label : Colors.black87,
        ),
      ),
    );
  }
  
  // Proje düzenleme işlevi
  void _editProject() async {
    if (_projectDetail == null) return;
    
    final result = await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => EditProjectView(
          groupId: widget.groupId,
          projectId: widget.projectId,
          projectName: _projectDetail!.projectName,
          projectDesc: _projectDetail!.projectDesc,
          projectStatusId: _projectDetail!.projectStatusID,
          startDate: _projectDetail!.proStartDate,
          endDate: _projectDetail!.proEndDate,
        ),
      ),
    );
    
    if (result == true && mounted) {
      await _loadProjectDetail();
      _snackBarService.showSuccess('Proje başarıyla güncellendi');
    }
  }
  
  // Kullanıcıyı projeden çıkarma doğrulama
  void _confirmRemoveUser(ProjectUser user) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Kullanıcıyı Çıkar'),
          content: Text('${user.userName} kullanıcısını projeden çıkarmak istediğinize emin misiniz?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(dialogContext);
                _removeUserFromProject(user.userID);
              },
              child: const Text('Çıkar'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kullanıcıyı Çıkar'),
          content: Text('${user.userName} kullanıcısını projeden çıkarmak istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _removeUserFromProject(user.userID);
              },
              child: const Text('Çıkar'),
            ),
          ],
        ),
      );
    }
  }
  
  // Kullanıcıyı projeden çıkar
  Future<void> _removeUserFromProject(int userID) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .removeUserFromProject(widget.groupId, widget.projectId, userID);
      
      if (mounted) {
        if (success) {
          await _loadProjectDetail();
          _snackBarService.showSuccess('Kullanıcı başarıyla projeden çıkarıldı');
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Kullanıcı projeden çıkarılamadı.';
          });
          
          _showErrorSnackbar('Kullanıcı çıkarma işlemi başarısız oldu. Lütfen daha sonra tekrar deneyin.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
  
  // Görev ekleme işlemi
  void _showAddWorkDialog() {
    final isIOS = isCupertino(context);
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    
    List<int> selectedUsers = [];
    final availableUsers = _projectDetail?.users ?? [];
    
    // Tarih formatlama fonksiyonu
    String formatDate(DateTime date) {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
    
    // Tarih seçici
    Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) async {
      if (isIOS) {
        DateTime? selectedDate;
        await showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) {
            return Container(
              height: 216,
              padding: const EdgeInsets.only(top: 6.0),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: CupertinoDatePicker(
                  initialDateTime: initialDate,
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                ),
              ),
            );
          },
        );
        return selectedDate;
      } else {
        return await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
      }
    }
    
    // Dialog içeriği
    Widget dialogContent = StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni Görev Ekle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              if (isIOS)
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Görev Adı',
                  padding: const EdgeInsets.all(12),
                )
              else
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Görev Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              if (isIOS)
                CupertinoTextField(
                  controller: descController,
                  placeholder: 'Görev Açıklaması',
                  padding: const EdgeInsets.all(12),
                  maxLines: 3,
                )
              else
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Görev Açıklaması',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await _pickDate(context, startDate);
                        if (pickedDate != null) {
                          setState(() {
                            startDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Başlangıç Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(startDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await _pickDate(context, endDate);
                        if (pickedDate != null) {
                          setState(() {
                            endDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bitiş Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(endDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Atanacak Kullanıcılar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: availableUsers.map((user) {
                  final isSelected = selectedUsers.contains(user.userID);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedUsers.remove(user.userID);
                        } else {
                          selectedUsers.add(user.userID);
                        }
                      });
                    },
                    child: Chip(
                      label: Text(user.userName),
                      backgroundColor: isSelected
                          ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.2)
                          : isIOS ? CupertinoColors.systemGrey6 : Colors.grey[200],
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                            : isIOS ? CupertinoColors.label : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Material(
              color: Colors.transparent,
              child: dialogContent,
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  _addWork(
                    nameController.text,
                    descController.text,
                    formatDate(startDate),
                    formatDate(endDate),
                    selectedUsers,
                  );
                  Navigator.of(context).pop();
                },
                isDefaultAction: true,
                child: const Text('Ekle'),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: dialogContent,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  _addWork(
                    nameController.text,
                    descController.text,
                    formatDate(startDate),
                    formatDate(endDate),
                    selectedUsers,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Ekle'),
              ),
            ],
          );
        },
      );
    }
  }
  
  // Görev ekleme işlemini gerçekleştir
  void _addWork(
    String name,
    String description,
    String startDate,
    String endDate,
    List<int> users,
  ) async {
    if (name.isEmpty) {
      _showErrorSnackbar('Görev adı boş olamaz');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .addProjectWork(
            widget.projectId,
            name,
            description,
            startDate,
            endDate,
            users,
          );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          // Görevleri yeniden yükle
          _projectWorks = null;
          _loadProjectWorks();
          
          _snackBarService.showSuccess('Görev başarıyla eklendi');
        } else {
          _showErrorSnackbar('Görev eklenemedi');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
  
  // Görev durumunu değiştirme
  void _toggleWorkCompletionStatus(ProjectWork work) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .changeWorkCompletionStatus(
            widget.projectId,
            work.workID,
            !work.workCompleted,  // Mevcut durumun tersini gönder
          );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          // Görevleri yeniden yükle
          _projectWorks = null;
          _loadProjectWorks();
          
          _snackBarService.showSuccess(
            work.workCompleted 
              ? 'Görev tamamlanmadı olarak işaretlendi' 
              : 'Görev tamamlandı olarak işaretlendi'
          );
        } else {
          _showErrorSnackbar('Görev durumu değiştirilemedi');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
  
  // Görev detay/düzenleme aksiyonları
  void _showWorkDetailActions(ProjectWork work) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          return CupertinoActionSheet(
            title: Text(work.workName),
            message: Text(work.workDesc.isNotEmpty ? work.workDesc : 'Açıklama bulunmuyor'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _toggleWorkCompletionStatus(work);
                },
                child: Text(
                  work.workCompleted ? 'Tamamlanmadı Olarak İşaretle' : 'Tamamlandı Olarak İşaretle'
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  // Görev detay sayfasına git
                  Navigator.push(
                    context,
                    platformPageRoute(
                      context: context,
                      builder: (context) => WorkDetailView(
                        projectId: widget.projectId,
                        groupId: widget.groupId,
                        workId: work.workID,
                      ),
                    ),
                  ).then((_) {
                    // Görev detay sayfasından döndüğünde görevleri yenile
                    _projectWorks = null;
                    _loadProjectWorks();
                  });
                },
                child: const Text('Görev Detayını Görüntüle'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  // Görev düzenleme ekranını aç
                  _showEditWorkDialog(work);
                },
                child: const Text('Görevi Düzenle'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
              isDestructiveAction: true,
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(work.workName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(work.workDesc.isNotEmpty ? work.workDesc : 'Açıklama bulunmuyor'),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    work.workCompleted ? Icons.check_box_outline_blank : Icons.check_box,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    work.workCompleted ? 'Tamamlanmadı Olarak İşaretle' : 'Tamamlandı Olarak İşaretle'
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleWorkCompletionStatus(work);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.visibility,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Görev Detayını Görüntüle'),
                  onTap: () {
                    Navigator.pop(context);
                    // Görev detay sayfasına git
                    Navigator.push(
                      context,
                      platformPageRoute(
                        context: context,
                        builder: (context) => WorkDetailView(
                          projectId: widget.projectId,
                          groupId: widget.groupId,
                          workId: work.workID,
                        ),
                      ),
                    ).then((_) {
                      // Görev detay sayfasından döndüğünde görevleri yenile
                      _projectWorks = null;
                      _loadProjectWorks();
                    });
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Görevi Düzenle'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditWorkDialog(work);
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }
  
  // Görev düzenleme dialogu
  void _showEditWorkDialog(ProjectWork work) {
    final isIOS = isCupertino(context);
    final TextEditingController nameController = TextEditingController(text: work.workName);
    final TextEditingController descController = TextEditingController(text: work.workDesc);
    
    // Tarih ayrıştırma: "DD.MM.YYYY" formatından DateTime'a çevirme
    DateTime parseDate(String dateStr) {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]), // Yıl
          int.parse(parts[1]), // Ay
          int.parse(parts[0]), // Gün
        );
      }
      return DateTime.now();
    }
    
    DateTime startDate = parseDate(work.workStartDate);
    DateTime endDate = parseDate(work.workEndDate);
    bool isCompleted = work.workCompleted;
    
    // Kullanıcıların listesi - Önceden seçilmişleri işaretle
    List<int> selectedUsers = work.workUsers.map((user) => user.userID).toList();
    final availableUsers = _projectDetail?.users ?? [];
    
    // Tarih formatlama fonksiyonu
    String formatDate(DateTime date) {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
    
    // Tarih seçici
    Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) async {
      if (isIOS) {
        DateTime? selectedDate;
        await showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) {
            return Container(
              height: 216,
              padding: const EdgeInsets.only(top: 6.0),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: CupertinoDatePicker(
                  initialDateTime: initialDate,
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                ),
              ),
            );
          },
        );
        return selectedDate;
      } else {
        return await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
      }
    }
    
    // Dialog içeriği
    Widget dialogContent = StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Görevi Düzenle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              if (isIOS)
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Görev Adı',
                  padding: const EdgeInsets.all(12),
                )
              else
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Görev Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              if (isIOS)
                CupertinoTextField(
                  controller: descController,
                  placeholder: 'Görev Açıklaması',
                  padding: const EdgeInsets.all(12),
                  maxLines: 3,
                )
              else
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Görev Açıklaması',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await _pickDate(context, startDate);
                        if (pickedDate != null) {
                          setState(() {
                            startDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Başlangıç Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(startDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await _pickDate(context, endDate);
                        if (pickedDate != null) {
                          setState(() {
                            endDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bitiş Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(endDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Tamamlandı',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIOS ? CupertinoColors.label : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (isIOS)
                    CupertinoSwitch(
                      value: isCompleted,
                      onChanged: (value) {
                        setState(() {
                          isCompleted = value;
                        });
                      },
                    )
                  else
                    Switch(
                      value: isCompleted,
                      onChanged: (value) {
                        setState(() {
                          isCompleted = value;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Atanacak Kullanıcılar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: availableUsers.map((user) {
                  final isSelected = selectedUsers.contains(user.userID);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedUsers.remove(user.userID);
                        } else {
                          selectedUsers.add(user.userID);
                        }
                      });
                    },
                    child: Chip(
                      label: Text(user.userName),
                      backgroundColor: isSelected
                          ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.2)
                          : isIOS ? CupertinoColors.systemGrey6 : Colors.grey[200],
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                            : isIOS ? CupertinoColors.label : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Material(
              color: Colors.transparent,
              child: dialogContent,
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  _updateWork(
                    work.workID,
                    nameController.text,
                    descController.text,
                    formatDate(startDate),
                    formatDate(endDate),
                    isCompleted,
                    selectedUsers,
                  );
                  Navigator.of(context).pop();
                },
                isDefaultAction: true,
                child: const Text('Güncelle'),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: dialogContent,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  _updateWork(
                    work.workID,
                    nameController.text,
                    descController.text,
                    formatDate(startDate),
                    formatDate(endDate),
                    isCompleted,
                    selectedUsers,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Güncelle'),
              ),
            ],
          );
        },
      );
    }
  }
  
  // Görevi güncelleme
  void _updateWork(
    int workID,
    String name,
    String description,
    String startDate,
    String endDate,
    bool isCompleted,
    List<int> users,
  ) async {
    if (name.isEmpty) {
      _showErrorSnackbar('Görev adı boş olamaz');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .updateProjectWork(
            widget.projectId,
            workID,
            name,
            description,
            startDate,
            endDate,
            isCompleted,
            users,
          );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          // Görevleri yeniden yükle
          _projectWorks = null;
          _loadProjectWorks();
          
          _snackBarService.showSuccess('Görev başarıyla güncellendi');
        } else {
          _showErrorSnackbar('Görev güncellenemedi');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
} 