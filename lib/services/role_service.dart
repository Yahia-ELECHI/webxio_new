import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/role.dart';
import '../models/permission.dart';
import '../models/user_role.dart';
import '../models/user_profile.dart';

/// Service pour gérer les rôles et permissions dans le système RBAC
class RoleService {
  final SupabaseClient _client;

  RoleService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  /// Vérifie si l'utilisateur courant a une permission spécifique
  Future<bool> hasPermission(
    String permissionName, {
    String? teamId,
    String? projectId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;
      
      print('DEBUG: Vérification permission: $permissionName pour user: $userId');
      
      // Récupérer directement les rôles de l'utilisateur pour debug
      final userRolesResponse = await _client.from('user_roles').select('roles (name)').eq('user_id', userId);
      final userRoles = (userRolesResponse as List).map((role) => role['roles']['name'] as String).toList();
      print('DEBUG: Rôles de l\'utilisateur: $userRoles');
      
      // Vérifier directement les permissions associées aux rôles de l'utilisateur
      if (userRoles.contains('system_admin')) {
        print('DEBUG: L\'utilisateur a le rôle system_admin, vérifions ses permissions');
        // Pour le rôle system_admin, récupérer l'ID du rôle
        final roleResponse = await _client.from('roles').select('id').eq('name', 'system_admin').single();
        final roleId = roleResponse['id'] as String;
        print('DEBUG: ID du rôle system_admin: $roleId');
        
        // Récupérer l'ID de la permission demandée
        final permissionResponse = await _client.from('permissions').select('id').eq('name', permissionName).single();
        final permissionId = permissionResponse['id'] as String;
        print('DEBUG: ID de la permission $permissionName: $permissionId');
        
        // Vérifier directement dans role_permissions
        final rolePermissionResponse = await _client
            .from('role_permissions')
            .select()
            .eq('role_id', roleId)
            .eq('permission_id', permissionId);
        
        print('DEBUG: Association role-permission trouvée: ${rolePermissionResponse.length > 0}');
        print('DEBUG: Données role-permission: $rolePermissionResponse');
      }
      
      final response = await _client.rpc('user_has_permission', params: {
        'p_user_id': userId,
        'p_permission_name': permissionName,
        'p_team_id': teamId,
        'p_project_id': projectId,
      });
      
      print('DEBUG: Réponse de la RPC user_has_permission: $response');

      return response ?? false;
    } catch (e) {
      print('Erreur lors de la vérification de la permission: $e');
      return false;
    }
  }

  /// Vérifie si l'utilisateur courant peut accéder à un projet
  Future<bool> canAccessProject(String projectId) async {
    try {
      final response = await _client.rpc('can_access_project', params: {
        'project_id': projectId,
      });
      
      return response ?? false;
    } catch (e) {
      print('Erreur lors de la vérification de l\'accès au projet: $e');
      return false;
    }
  }

  /// Vérifie si l'utilisateur courant peut modifier un projet
  Future<bool> canModifyProject(String projectId) async {
    try {
      final response = await _client.rpc('can_modify_project', params: {
        'project_id': projectId,
      });
      
      return response ?? false;
    } catch (e) {
      print('Erreur lors de la vérification des droits de modification: $e');
      return false;
    }
  }

  /// Attribue un rôle à un utilisateur
  Future<bool> assignRole({
    required String userId,
    required String roleName,
    String? teamId,
    String? projectId,
  }) async {
    try {
      // Récupérer l'ID du rôle par son nom
      final rolesResponse = await _client
          .from('roles')
          .select('id')
          .eq('name', roleName)
          .single();
      
      final roleId = rolesResponse['id'] as String;
      
      // Insérer le rôle utilisateur
      await _client.from('user_roles').insert({
        'user_id': userId,
        'role_id': roleId,
        'team_id': teamId,
        'project_id': projectId,
        'created_by': _client.auth.currentUser?.id,
      });
      
      return true;
    } catch (e) {
      print('Erreur lors de l\'attribution du rôle: $e');
      return false;
    }
  }

  /// Récupère tous les rôles disponibles dans le système
  Future<List<Role>> getAllRoles() async {
    try {
      final response = await _client.from('roles').select().order('name');
      return response.map((json) => Role.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des rôles: $e');
      return [];
    }
  }

  /// Récupère toutes les permissions disponibles dans le système
  Future<List<Permission>> getAllPermissions() async {
    try {
      final response = await _client.from('permissions').select().order('resource_type, action');
      return response.map((json) => Permission.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des permissions: $e');
      return [];
    }
  }

  /// Récupère tous les rôles utilisateurs dans le système
  Future<List<UserRole>> getAllUserRoles() async {
    try {
      print('DEBUG: Récupération de tous les user_roles');
      final response = await _client
          .from('user_roles')
          .select('''
            *,
            roles (*),
            teams (*),
            projects (*)
          ''')
          .order('created_at');
      
      print('DEBUG: Réponse user_roles: ${response.length} éléments');
      
      // Récupérer les user_roles
      List<UserRole> userRoles = response.map((json) => UserRole.fromJson(json)).toList();
      
      // Pour chaque userRole, récupérer les informations de profil
      for (var i = 0; i < userRoles.length; i++) {
        try {
          final userProfile = await _client
              .from('profiles')
              .select('id, email, display_name')
              .eq('id', userRoles[i].userId)
              .single();
          
          if (userProfile != null) {
            // Mettre à jour le modèle UserRole avec les infos de profil
            userRoles[i] = UserRole(
              id: userRoles[i].id,
              userId: userRoles[i].userId,
              roleId: userRoles[i].roleId,
              role: userRoles[i].role,
              teamId: userRoles[i].teamId,
              team: userRoles[i].team,
              projectId: userRoles[i].projectId,
              project: userRoles[i].project,
              createdAt: userRoles[i].createdAt,
              createdBy: userRoles[i].createdBy,
              userProfile: UserProfile.fromJson(userProfile),
            );
          }
        } catch (e) {
          print('Erreur lors de la récupération du profil utilisateur ${userRoles[i].userId}: $e');
        }
      }
      
      return userRoles;
    } catch (e) {
      print('Erreur lors de la récupération des rôles utilisateurs: $e');
      return [];
    }
  }

  /// Récupère les rôles d'un utilisateur spécifique
  Future<List<UserRole>> getUserRoles(String userId) async {
    try {
      print('DEBUG: Récupération des rôles de l\'utilisateur: $userId');
      final response = await _client
          .from('user_roles')
          .select('''
            *,
            roles (*),
            teams (*),
            projects (*)
          ''')
          .eq('user_id', userId)
          .order('created_at');
      
      // Récupérer les user_roles
      List<UserRole> userRoles = response.map((json) => UserRole.fromJson(json)).toList();
      
      // Récupérer les informations de profil de l'utilisateur
      try {
        final userProfile = await _client
            .from('profiles')
            .select('id, email, display_name')
            .eq('id', userId)
            .single();
        
        if (userProfile != null) {
          final profile = UserProfile.fromJson(userProfile);
          
          // Mettre à jour tous les UserRole avec les mêmes informations de profil
          userRoles = userRoles.map((userRole) => UserRole(
            id: userRole.id,
            userId: userRole.userId,
            roleId: userRole.roleId,
            role: userRole.role,
            teamId: userRole.teamId,
            team: userRole.team,
            projectId: userRole.projectId,
            project: userRole.project,
            createdAt: userRole.createdAt,
            createdBy: userRole.createdBy,
            userProfile: profile,
          )).toList();
        }
      } catch (e) {
        print('Erreur lors de la récupération du profil utilisateur $userId: $e');
      }
      
      return userRoles;
    } catch (e) {
      print('Erreur lors de la récupération des rôles de l\'utilisateur: $e');
      return [];
    }
  }

  /// Supprime un rôle utilisateur
  Future<bool> deleteUserRole(String userRoleId) async {
    try {
      await _client.from('user_roles').delete().eq('id', userRoleId);
      return true;
    } catch (e) {
      print('Erreur lors de la suppression du rôle utilisateur: $e');
      return false;
    }
  }

  /// Récupère les noms des rôles de l'utilisateur actuellement connecté
  Future<List<String>> getUserRolesWithoutParam() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return ['Non connecté'];
      
      final response = await _client.from('user_roles').select('roles (name)').eq('user_id', userId);
      final roles = (response as List).map((role) => role['roles']['name'] as String).toList();
      
      return roles.isNotEmpty ? roles : ['Aucun rôle'];
    } catch (e) {
      print('Erreur lors de la récupération des rôles: $e');
      return ['Erreur'];
    }
  }

  /// Récupère les informations détaillées des rôles de l'utilisateur (incluant team_id et project_id)
  Future<List<Map<String, dynamic>>> getUserRolesDetails() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [{'error': 'Non connecté'}];
      
      final response = await _client
          .from('user_roles')
          .select('*, roles (id, name)')
          .eq('user_id', userId);
      
      // Convertir la réponse en liste de Map
      List<Map<String, dynamic>> roleDetails = [];
      for (var role in response) {
        roleDetails.add({
          'role_id': role['role_id'],
          'role_name': role['roles']['name'],
          'team_id': role['team_id'],
          'project_id': role['project_id'],
          'user_id': role['user_id'],
        });
      }
      
      print('DEBUG: Détails des rôles récupérés: $roleDetails');
      return roleDetails;
    } catch (e) {
      print('Erreur lors de la récupération des détails des rôles: $e');
      return [{'error': e.toString()}];
    }
  }

  /// Récupère les informations sur tous les utilisateurs
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, email, display_name')
          .order('display_name');
      
      return response;
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs: $e');
      return [];
    }
  }
}
