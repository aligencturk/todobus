import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../viewmodels/group_viewmodel.dart';
import 'create_group_view.dart';
import 'group_detail_view.dart';

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
    // Widget oluşturulduktan sonra grup listesini yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupViewModel>(context, listen: false).loadGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Grup oluşturma sayfasına git
  Future<void> _navigateToCreateGroupView() async {
    final result = await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => const CreateGroupView(),
      ),
    );
    // Grup oluşturulduysa listeyi yenile
    if (result == true && mounted) {
      Provider.of<GroupViewModel>(context, listen: false).loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupViewModel>(
      builder: (context, viewModel, _) {
        return PlatformScaffold(
          appBar: PlatformAppBar(
            title: const Text('Gruplar'),
            material: (_, __) => MaterialAppBarData(
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Yeni Grup Oluştur',
                  onPressed: _navigateToCreateGroupView,
                ),
                IconButton(
                  icon: Icon(context.platformIcons.refresh),
                  onPressed: () => viewModel.loadGroups(),
                ),
              ],
            ),
            cupertino: (_, __) => CupertinoNavigationBarData(
              transitionBetweenRoutes: false,
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
                    child: Icon(context.platformIcons.refresh),
                    onPressed: () => viewModel.loadGroups(),
                  ),
                ],
              ),
            ),
          ),
          body: _buildBody(viewModel),
        );
      }
    );
  }

  Widget _buildBody(GroupViewModel viewModel) {
    if (viewModel.status == GroupLoadStatus.initial || viewModel.status == GroupLoadStatus.loading) {
      return Center(child: PlatformCircularProgressIndicator());
    } else if (viewModel.status == GroupLoadStatus.error) {
      return _buildErrorView(viewModel);
    } else {
      return _buildGroupContent(viewModel);
    }
  }

  Widget _buildGroupContent(GroupViewModel viewModel) {
    if (!viewModel.hasGroups) {
      return _buildEmptyView();
    }
    
    final isIOS = isCupertino(context);
    
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (isIOS)
                CupertinoSliverRefreshControl(
                  onRefresh: viewModel.loadGroups,
                ),
              SliverSafeArea(
                top: false,
                bottom: false,
                left: false,
                right: false,
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildGroupStats(viewModel),
                    ),
                    _buildQuickAccessSection(viewModel),
                    SliverToBoxAdapter(
                      child: CupertinoListSection.insetGrouped(
                        header: Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
                          child: Text(
                            _filteredGroups(viewModel.groups).isEmpty 
                              ? 'Grup Bulunamadı' 
                              : 'Tüm Gruplar',
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: CupertinoColors.secondaryLabel,
                              fontWeight: FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        children: _filteredGroups(viewModel.groups).map((group) {
                          return _buildGroupListItem(group, viewModel);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  List<Group> _filteredGroups(List<Group> allGroups) {
    // Önce arama filtresi uygula
    var filteredList = _searchQuery.isEmpty 
        ? allGroups 
        : allGroups.where((group) => 
            group.groupName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            group.groupDesc.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            group.createdBy.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
    
    // Sonra seçilen kategoriye göre filtrele
    if (_selectedFilterIndex == 1) {
      // Admin olduğum gruplar
      filteredList = filteredList.where((group) => group.isAdmin).toList();
    } else if (_selectedFilterIndex == 2) {
      // Üye olduğum gruplar (admin olmadığım)
      filteredList = filteredList.where((group) => !group.isAdmin).toList();
    }
    
    return filteredList;
  }

  Widget _buildErrorView(GroupViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hata: ${viewModel.errorMessage}',
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyLarge?.copyWith(color: Colors.red),
                cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.systemRed),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PlatformElevatedButton(
              onPressed: () => viewModel.loadGroups(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.group,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz hiç grup yok',
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir grup oluşturmak için + butonuna tıklayın',
            style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(color: CupertinoColors.secondaryLabel),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupStats(GroupViewModel viewModel) {
    return CupertinoListSection.insetGrouped(
      header: Padding(
        padding: const EdgeInsets.only(left: 16.0, top:8.0, bottom: 4.0),
        child: Text(
            'Özet',
           style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
        ),
      ),
      children: <Widget>[
        CupertinoListTile(
          title: const Text('Toplam Grup'),
          leading: const Icon(CupertinoIcons.group_solid),
          additionalInfo: Text('${viewModel.groups.length}'),
        ),
        CupertinoListTile(
          title: const Text('Toplam Proje'),
          leading: const Icon(CupertinoIcons.briefcase_fill),
          additionalInfo: Text('${viewModel.totalProjects}'),
        ),
      ],
    );
  }

  Widget _buildGroupListItem(Group group, GroupViewModel viewModel) {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return CupertinoListTile.notched(
      title: Text(
        group.groupName,
        style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.groupDesc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              group.groupDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(CupertinoIcons.person_alt_circle, size: 14, color: CupertinoColors.secondaryLabel),
              const SizedBox(width: 4),
              Text(
                group.createdBy,
                style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.calendar, size: 14, color: CupertinoColors.secondaryLabel),
              const SizedBox(width: 4),
              Text(
                group.createDate,
                style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: group.isAdmin ? CupertinoColors.activeBlue.withOpacity(0.15) : CupertinoColors.systemGroupedBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            group.isAdmin ? CupertinoIcons.shield_lefthalf_fill : CupertinoIcons.group,
            color: group.isAdmin ? CupertinoColors.activeBlue : CupertinoColors.secondaryLabel,
            size: 20,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!group.isFree)
                Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                color: CupertinoColors.systemOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                group.packageName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: CupertinoColors.systemOrange,
                  fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          const SizedBox(width: 8),
          const CupertinoListTileChevron(),
        ],
      ),
      onTap: () {
        // Grup detay sayfasına yönlendir
        Navigator.of(context).push(
          platformPageRoute(
            context: context,
            builder: (context) => GroupDetailView(groupId: group.groupID),
          ),
        );
      },
    );
  }

  void _showProjectsDialog(BuildContext context, Group group) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          '${group.groupName} Projeleri',
          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(fontSize: 18),
        ),
        message: Text(
          'Toplam ${group.projects.length} proje bulundu.',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 15,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        actions: group.projects.map((project) {
          return CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(project.projectName),
                Text(
              project.projectStatus,
              style: TextStyle(
                    fontSize: 13,
                    color: project.projectStatus.toLowerCase() == 'tamamlandı'
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.systemOrange,
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              // Proje detayına gitme işlevi eklenebilir
              Navigator.of(context).push(
                platformPageRoute(
                  context: context,
                  builder: (context) => GroupDetailView(groupId: group.groupID),
                ),
              );
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Kapat'),
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
  
  // ARAMA ÇUBUĞU
  Widget _buildSearchBar() {
    final isIOS = isCupertino(context);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: isIOS
        ? CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'Grup Ara',
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onSubmitted: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          )
        : TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Grup Ara',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
    );
  }
  
  // FİLTRE ÇİPLERİ
  Widget _buildFilterChips() {
    final isIOS = isCupertino(context);
    
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(0, 'Tüm Gruplar'),
          const SizedBox(width: 8),
          _buildFilterChip(1, 'Admin Olduğum'),
          const SizedBox(width: 8),
          _buildFilterChip(2, 'Üye Olduğum'),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(int index, String label) {
    final isIOS = isCupertino(context);
    final isSelected = _selectedFilterIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
            ? (isIOS ? CupertinoColors.activeBlue : Theme.of(context).colorScheme.primary)
            : (isIOS ? CupertinoColors.systemGrey5 : Theme.of(context).colorScheme.surfaceVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
              ? (isIOS ? CupertinoColors.white : Theme.of(context).colorScheme.onPrimary)
              : (isIOS ? CupertinoColors.label : Theme.of(context).colorScheme.onSurfaceVariant),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  // HIZLI ERİŞİM GRUBU
  Widget _buildQuickAccessSection(GroupViewModel viewModel) {
    final adminGroups = viewModel.groups.where((group) => group.isAdmin).toList();
    
    if (adminGroups.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    // En fazla 3 grup göster
    final displayGroups = adminGroups.length > 3 ? adminGroups.sublist(0, 3) : adminGroups;
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Hızlı Erişim',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: displayGroups.length,
              itemBuilder: (context, index) {
                return _buildQuickAccessItem(displayGroups[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickAccessItem(Group group) {
    final isIOS = isCupertino(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          platformPageRoute(
            context: context,
            builder: (context) => GroupDetailView(groupId: group.groupID),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isIOS 
            ? CupertinoColors.systemBackground 
            : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isIOS
                ? CupertinoColors.systemGrey5.withOpacity(0.5)
                : Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isIOS
                        ? CupertinoColors.activeBlue.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isIOS
                        ? CupertinoIcons.shield_lefthalf_fill
                        : Icons.admin_panel_settings,
                      color: isIOS
                        ? CupertinoColors.activeBlue
                        : Colors.blue,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isIOS
                          ? CupertinoColors.label
                          : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${group.projects.length} Proje',
                style: TextStyle(
                  fontSize: 12,
                  color: isIOS
                    ? CupertinoColors.secondaryLabel
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
