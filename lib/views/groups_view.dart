import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../viewmodels/group_viewmodel.dart';

class GroupsView extends StatefulWidget {
  const GroupsView({Key? key}) : super(key: key);

  @override
  _GroupsViewState createState() => _GroupsViewState();
}

class _GroupsViewState extends State<GroupsView> {
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Gruplar'),
        material: (_, __) => MaterialAppBarData(
          actions: <Widget>[
            IconButton(
              icon: Icon(context.platformIcons.refresh),
              onPressed: () {
                Provider.of<GroupViewModel>(context, listen: false).loadGroups();
              },
            ),
          ],
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          transitionBetweenRoutes: false,
        ),
      ),
      body: ChangeNotifierProvider(
        create: (_) => GroupViewModel(),
        child: Consumer<GroupViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.status == GroupLoadStatus.initial) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                viewModel.loadGroups();
              });
              return Center(child: PlatformCircularProgressIndicator());
            } else if (viewModel.status == GroupLoadStatus.loading) {
              return Center(child: PlatformCircularProgressIndicator());
            } else if (viewModel.status == GroupLoadStatus.error) {
              return _buildErrorView(context, viewModel);
            } else {
              return _buildGroupList(context, viewModel);
            }
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, GroupViewModel viewModel) {
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

  Widget _buildGroupList(BuildContext context, GroupViewModel viewModel) {
    if (!viewModel.hasGroups) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              context.platformIcons.group,
              size: 64,
              color: platformThemeData(
                context,
                material: (data) => data.disabledColor,
                cupertino: (data) => CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz hiç grup yok',
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.headlineSmall,
                cupertino: (data) => data.textTheme.navTitleTextStyle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni bir grup oluşturmak için + butonuna tıklayın',
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyMedium,
                cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
              ),
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
        SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return _buildGroupStats(context, viewModel);
                }
                final group = viewModel.groups[index - 1];
                return _buildGroupCard(context, group);
              },
              childCount: viewModel.groups.length + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupStats(BuildContext context, GroupViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: platformThemeData(
          context,
          material: (data) => data.colorScheme.surface,
          cupertino: (data) => CupertinoColors.systemBackground,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isCupertino(context))
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Özet',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleLarge,
              cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  context.platformIcons.group,
                  'Gruplar',
                  '${viewModel.groups.length}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  context,
                  context.platformIcons.collections,
                  'Projeler',
                  '${viewModel.totalProjects}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: platformThemeData(
            context,
            material: (data) => data.colorScheme.primary,
            cupertino: (data) => CupertinoColors.activeBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: platformThemeData(
            context,
            material: (data) => data.textTheme.headlineSmall,
            cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(fontSize: 24),
          ),
        ),
        Text(
          label,
          style: platformThemeData(
            context,
            material: (data) => data.textTheme.bodySmall,
            cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(BuildContext context, Group group) {
    final hasProjects = group.projects.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: platformThemeData(
          context,
          material: (data) => data.colorScheme.surface,
          cupertino: (data) => CupertinoColors.systemBackground,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isCupertino(context))
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(context, group),
          if (hasProjects) 
            _buildProjectsList(context, group),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context, Group group) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: group.isAdmin 
            ? platformThemeData(
                context,
                material: (data) => data.colorScheme.primaryContainer,
                cupertino: (data) => CupertinoColors.activeBlue.withOpacity(0.1),
              )
            : null,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  group.groupName,
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.titleLarge,
                    cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: group.isFree
                      ? platformThemeData(
                          context,
                          material: (data) => Colors.green.withOpacity(0.1),
                          cupertino: (data) => CupertinoColors.activeGreen.withOpacity(0.1),
                        )
                      : platformThemeData(
                          context,
                          material: (data) => Colors.deepOrange.withOpacity(0.1),
                          cupertino: (data) => CupertinoColors.systemOrange.withOpacity(0.1),
                        ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  group.packageName,
                  style: TextStyle(
                    fontSize: 12,
                    color: group.isFree
                        ? platformThemeData(
                            context,
                            material: (data) => Colors.green,
                            cupertino: (data) => CupertinoColors.activeGreen,
                          )
                        : platformThemeData(
                            context,
                            material: (data) => Colors.deepOrange,
                            cupertino: (data) => CupertinoColors.systemOrange,
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (group.groupDesc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              group.groupDesc,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyMedium,
                cupertino: (data) => data.textTheme.textStyle,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                context.platformIcons.person,
                size: 14,
                color: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall?.color,
                  cupertino: (data) => CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                group.createdBy,
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall,
                  cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(color: CupertinoColors.secondaryLabel),
                ),
              ),
              const Spacer(),
              Icon(
                context.platformIcons.time,
                size: 14,
                color: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall?.color,
                  cupertino: (data) => CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                group.createDate,
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall,
                  cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(color: CupertinoColors.secondaryLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                context.platformIcons.collections,
                size: 14,
                color: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall?.color,
                  cupertino: (data) => CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Projeler: ${group.projects.length}',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall,
                  cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(color: CupertinoColors.secondaryLabel),
                ),
              ),
              if (group.isAdmin) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: platformThemeData(
                      context,
                      material: (data) => data.colorScheme.secondary.withOpacity(0.1),
                      cupertino: (data) => CupertinoColors.systemIndigo.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Yönetici',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: platformThemeData(
                        context,
                        material: (data) => data.colorScheme.secondary,
                        cupertino: (data) => CupertinoColors.systemIndigo,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList(BuildContext context, Group group) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projeler',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium,
              cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          ...group.projects.map((project) => _buildProjectItem(context, project)).toList(),
        ],
      ),
    );
  }

  Widget _buildProjectItem(BuildContext context, Project project) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            context.platformIcons.collections,
            size: 16,
            color: platformThemeData(
              context,
              material: (data) => data.colorScheme.primary,
              cupertino: (data) => CupertinoColors.activeBlue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              project.projectName,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyMedium,
                cupertino: (data) => data.textTheme.textStyle,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: platformThemeData(
                context,
                material: (data) => data.colorScheme.primaryContainer.withOpacity(0.3),
                cupertino: (data) => CupertinoColors.systemBlue.withOpacity(0.1),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              project.projectStatus,
              style: TextStyle(
                fontSize: 12,
                color: platformThemeData(
                  context,
                  material: (data) => data.colorScheme.primary,
                  cupertino: (data) => CupertinoColors.systemBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 