import 'dart:async';

class RefreshService {
  static final RefreshService _instance = RefreshService._internal();
  
  factory RefreshService() {
    return _instance;
  }
  
  RefreshService._internal();
  
  final StreamController<String> _refreshController = StreamController<String>.broadcast();
  
  Stream<String> get refreshStream => _refreshController.stream;
  
  void refreshData(String refreshType) {
    _refreshController.add(refreshType);
  }
  
  void refreshGroups() {
    refreshData('groups');
  }
  
  void refreshProjects() {
    refreshData('projects');
  }
  
  void refreshWorks() {
    refreshData('works');
  }
  
  void refreshEvents() {
    refreshData('events');
  }
  
  void refreshProfile() {
    refreshData('profile');
  }
  
  void refreshAll() {
    refreshData('all');
  }
  
  void dispose() {
    _refreshController.close();
  }
} 