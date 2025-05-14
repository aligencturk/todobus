import 'base_api_service.dart';
import 'auth_service.dart';
import 'user_service.dart';
import 'group_service.dart';
import 'project_service.dart';
import 'event_service.dart';

/// API servisi, tüm API servislerine tek bir yerden erişimi kolaylaştıran facade sınıfıdır.
/// Bu servis, her servisi tek bir yerden sağlayarak kodun farklı yerlerinde tutarlı kullanımı garantiler.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  
  // Alt servisler
  final BaseApiService _baseApiService = BaseApiService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final GroupService _groupService = GroupService();
  final ProjectService _projectService = ProjectService();
  final EventService _eventService = EventService();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // Temel API servisi
  BaseApiService get base => _baseApiService;
  
  // Kimlik doğrulama servisi
  AuthService get auth => _authService;
  
  // Kullanıcı servisi
  UserService get user => _userService;
  
  // Grup servisi
  GroupService get group => _groupService;
  
  // Proje servisi
  ProjectService get project => _projectService;
  
  // Etkinlik servisi
  EventService get event => _eventService;
} 