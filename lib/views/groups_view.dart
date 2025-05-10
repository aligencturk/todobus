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
  @override
  void initState() {
    super.initState();
    // Widget oluşturulduktan sonra grup listesini yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupViewModel>(context, listen: false).loadGroups();
    });
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
      return _buildGroupList(viewModel);
    }
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

  Widget _buildGroupList(GroupViewModel viewModel) {
    if (!viewModel.hasGroups) {
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

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: viewModel.loadGroups,
        ),
        SliverSafeArea(
          top: true,
          bottom: false,
          left: false,
          right: false,
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _buildGroupStats(viewModel),
              ),
              SliverToBoxAdapter(
                child: CupertinoListSection.insetGrouped(
                  header: Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
                    child: Text(
                      'Tüm Gruplar',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  children: viewModel.groups.map((group) {
                    return _buildGroupListItem(group, viewModel);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
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
} 
