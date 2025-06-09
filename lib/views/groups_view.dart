import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../viewmodels/group_viewmodel.dart';
import 'create_group_view.dart';
import 'group_detail_view.dart';

// SnackBar için yardımcı fonksiyon
void showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
  if (isCupertino(context)) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(isError ? 'Hata' : 'Bilgi'),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            isDefaultAction: true,
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
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}

class GroupsView extends StatefulWidget {
  const GroupsView({Key? key}) : super(key: key);

  @override
  _GroupsViewState createState() => _GroupsViewState();
}

class _GroupsViewState extends State<GroupsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: Tüm, 1: Admin Olduğum, 2: Üye Olduğum

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupViewModel>(context, listen: false).loadGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToCreateGroupView() async {
    final result = await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => const CreateGroupView(),
      ),
    );
    if (result == true && mounted) {
      Provider.of<GroupViewModel>(context, listen: false).loadGroups();
    }
  }

  Future<void> _refreshGroups() async {
    await Provider.of<GroupViewModel>(context, listen: false).loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupViewModel>(
      builder: (context, viewModel, _) {
        return PlatformScaffold(
          appBar: PlatformAppBar(
            title: const Text('Gruplar'),
            material: (_, __) => MaterialAppBarData(
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _navigateToCreateGroupView,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshGroups,
                ),
              ],
            ),
            cupertino: (_, __) => CupertinoNavigationBarData(
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.add),
                    onPressed: _navigateToCreateGroupView,
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.refresh),
                    onPressed: _refreshGroups,
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: _buildBody(viewModel),
          ),
        );
      }
    );
  }

  Widget _buildBody(GroupViewModel viewModel) {
    if (viewModel.status == GroupLoadStatus.loading) {
      return Center(child: PlatformCircularProgressIndicator());
    }
    
    if (viewModel.status == GroupLoadStatus.error) {
      return _buildErrorView(viewModel);
    }
    
    if (!viewModel.hasGroups) {
      return _buildEmptyView();
    }
    
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshGroups,
            child: ListView(
              children: [
                _buildGroupStats(viewModel),
                ..._filteredGroups(viewModel.groups).map((group) => 
                  _buildGroupListItem(group, viewModel)
                ).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Group> _filteredGroups(List<Group> allGroups) {
    var filteredList = _searchQuery.isEmpty 
        ? allGroups 
        : allGroups.where((group) => 
            group.groupName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            group.groupDesc.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
    
    if (_selectedFilterIndex == 1) {
      filteredList = filteredList.where((group) => group.isAdmin).toList();
    } else if (_selectedFilterIndex == 2) {
      filteredList = filteredList.where((group) => !group.isAdmin).toList();
    }
    
    return filteredList;
  }

  Widget _buildErrorView(GroupViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gruplar Yüklenemedi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _refreshGroups,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.group,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Henüz hiç grup yok',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yeni bir grup oluşturmak için + butonuna tıklayın',
              textAlign: TextAlign.center,
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupStats(GroupViewModel viewModel) {
    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.all(16),
      children: [
        CupertinoListTile(
          title: const Text('Toplam Grup'),
          leading: const Icon(CupertinoIcons.group, color: CupertinoColors.systemBlue),
          additionalInfo: Text('${viewModel.groups.length}'),
        ),
        CupertinoListTile(
          title: const Text('Toplam Proje'),
          leading: const Icon(CupertinoIcons.folder, color: CupertinoColors.systemOrange),
          additionalInfo: Text('${viewModel.totalProjects}'),
        ),
      ],
    );
  }

  Widget _buildGroupListItem(Group group, GroupViewModel viewModel) {
    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        CupertinoListTile(
          title: Text(group.groupName),
          subtitle: group.groupDesc.isNotEmpty ? Text(group.groupDesc) : null,
          leading: Icon(
            group.isAdmin ? CupertinoIcons.shield : CupertinoIcons.group,
            color: group.isAdmin ? CupertinoColors.systemBlue : CupertinoColors.systemGrey,
          ),
          additionalInfo: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${group.projects.length}'),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.folder, size: 16, color: CupertinoColors.secondaryLabel),
            ],
          ),
          trailing: group.isAdmin 
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.ellipsis),
                onPressed: () => _showGroupActions(context, group, viewModel),
              )
            : const CupertinoListTileChevron(),
          onTap: () {
            Navigator.of(context).push(
              platformPageRoute(
                context: context,
                builder: (context) => GroupDetailView(groupId: group.groupID),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showGroupActions(BuildContext context, Group group, GroupViewModel viewModel) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(group.groupName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                platformPageRoute(
                  context: context,
                  builder: (context) => GroupDetailView(groupId: group.groupID),
                ),
              );
            },
            child: const Text('Grup Detayları'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteGroup(context, group, viewModel);
            },
            child: const Text('Grubu Sil'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('İptal'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, Group group, GroupViewModel viewModel) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Grubu Sil'),
        content: Text('${group.groupName} grubunu silmek istediğinize emin misiniz?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await viewModel.deleteGroup(group.groupID);
              if (mounted) {
                showCustomSnackBar(
                  context, 
                  success ? 'Grup silindi' : 'Hata oluştu', 
                  isError: !success
                );
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 4),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Grup Ara',
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          _buildFilterChip(0, 'Tümü'),
          const SizedBox(width: 8),
          _buildFilterChip(1, 'Yönetici'),
          const SizedBox(width: 8),
          _buildFilterChip(2, 'Üye'),
          
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? CupertinoColors.systemBlue 
            : CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
              ? CupertinoColors.white 
              : CupertinoColors.label,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
} 
