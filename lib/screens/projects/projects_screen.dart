import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/project_model.dart';
import '../../models/team_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../providers/role_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/permission_gated.dart';
import '../../widgets/rbac_gated_screen.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';
import 'widgets/modern_project_card.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectService _projectService = ProjectService();
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  final RoleService _roleService = RoleService();
  
  List<Project> _projects = [];
  Map<String, int> _projectTeamCounts = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasProjectAccess = false; // Variable pour contrôler l'accès aux projets
  
  @override
  void initState() {
    super.initState();
    _checkProjectAccess(); // Vérifier d'abord l'accès aux projets
    // Tracer les informations sur l'utilisateur au démarrage de l'écran
    _logUserAccessInfo();
  }

  /// Vérifie si l'utilisateur a accès à au moins un projet
  Future<void> _checkProjectAccess() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _hasProjectAccess = false;
          _isLoading = false;
        });
        return;
      }
      
      // Récupérer les rôles de l'utilisateur avec les projets associés
      final userRolesDetails = await _roleService.getUserRolesDetails();
      
      // Vérifier si l'utilisateur a un rôle system_admin (accès global)
      final isSystemAdmin = userRolesDetails.any((role) => role['role_name'] == 'system_admin');
      
      if (isSystemAdmin) {
        print('DEBUG: Utilisateur system_admin, accès à tous les projets accordé');
        setState(() {
          _hasProjectAccess = true;
        });
        _loadProjects(); // Charger tous les projets
        return;
      }
      
      // Extraire les IDs des projets auxquels l'utilisateur a accès via ses rôles
      final projectIds = userRolesDetails
          .where((role) => role['project_id'] != null)
          .map((role) => role['project_id'] as String)
          .toSet()
          .toList();
      
      print('DEBUG: Projets accessibles: $projectIds');
      
      if (projectIds.isEmpty) {
        // Aucun projet spécifique trouvé, vérifier une dernière fois via hasPermission
        final hasGlobalAccess = await _roleService.hasPermission('read_project');
        
        setState(() {
          _hasProjectAccess = hasGlobalAccess;
          _isLoading = false;
        });
        
        if (hasGlobalAccess) {
          _loadProjects(); // Accès global confirmé, charger tous les projets
        }
      } else {
        // L'utilisateur a accès à des projets spécifiques
        setState(() {
          _hasProjectAccess = true;
        });
        
        // Charger uniquement les projets accessibles à l'utilisateur
        _loadUserProjects(projectIds);
      }
    } catch (e) {
      print('ERROR: Erreur lors de la vérification de l\'accès aux projets: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la vérification de l\'accès aux projets: $e';
        _isLoading = false;
        _hasProjectAccess = false;
      });
    }
  }
  
  /// Charge uniquement les projets auxquels l'utilisateur a accès
  Future<void> _loadUserProjects(List<String> projectIds) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      if (projectIds.isEmpty) {
        setState(() {
          _projects = [];
          _isLoading = false;
        });
        return;
      }
      
      // Charger les projets spécifiques
      List<Project> accessibleProjects = [];
      for (var projectId in projectIds) {
        try {
          final project = await _projectService.getProjectById(projectId);
          if (project != null) {
            accessibleProjects.add(project);
          }
        } catch (e) {
          print('WARN: Erreur lors du chargement du projet $projectId: $e');
        }
      }
      
      // Récupérer le nombre d'équipes pour chaque projet
      Map<String, int> projectTeamCounts = {};
      for (var project in accessibleProjects) {
        try {
          final teams = await _teamService.getTeamsByProject(project.id);
          projectTeamCounts[project.id] = teams.length;
        } catch (e) {
          projectTeamCounts[project.id] = 0;
          print('WARN: Erreur lors du comptage des équipes pour le projet ${project.id}: $e');
        }
      }
      
      setState(() {
        _projects = accessibleProjects;
        _projectTeamCounts = projectTeamCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des projets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProjects() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final projects = await _projectService.getAllProjects();
      
      // Récupérer le nombre d'équipes pour chaque projet
      Map<String, int> projectTeamCounts = {};
      for (var project in projects) {
        final teams = await _teamService.getTeamsByProject(project.id);
        projectTeamCounts[project.id] = teams.length;
      }
      
      setState(() {
        _projects = projects;
        _projectTeamCounts = projectTeamCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des projets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProjectTeamCounts() async {
    Map<String, int> counts = {};
    
    for (var project in _projects) {
      try {
        final teams = await _teamService.getTeamsByProject(project.id);
        counts[project.id] = teams.length;
      } catch (e) {
        print('Erreur lors du chargement des équipes pour le projet ${project.id}: $e');
        counts[project.id] = 0;
      }
    }
    
    if (mounted) {
      setState(() {
        _projectTeamCounts = counts;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Projets',
        actions: [
          if (_hasProjectAccess) // N'afficher que si l'utilisateur a accès aux projets
            PermissionGated(
              permissionName: 'create_project',
              child: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Ajouter un projet',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProjectFormScreen(),
                    ),
                  );
                  
                  if (result == true) {
                    // Recharger les projets en respectant les droits d'accès
                    if (_hasProjectAccess) {
                      final userRolesDetails = await _roleService.getUserRolesDetails();
                      final isSystemAdmin = userRolesDetails.any((role) => role['role_name'] == 'system_admin');
                      
                      if (isSystemAdmin) {
                        _loadProjects();
                      } else {
                        final projectIds = userRolesDetails
                            .where((role) => role['project_id'] != null)
                            .map((role) => role['project_id'] as String)
                            .toSet()
                            .toList();
                        
                        _loadUserProjects(projectIds);
                      }
                    }
                  }
                },
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkProjectAccess,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : !_hasProjectAccess 
                  ? _buildAccessDeniedView()
                  : _buildProjectList(),
    );
  }

  Widget _buildAccessDeniedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Accès refusé',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Vous n\'avez pas l\'autorisation d\'accéder à cet écran.\nContactez un administrateur si vous pensez qu\'il s\'agit d\'une erreur.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Aucun projet trouvé',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            PermissionGated(
              permissionName: 'create_project',
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProjectFormScreen(),
                    ),
                  );
                  if (result == true) {
                    _checkProjectAccess(); // Recharger avec les bons contextes
                  }
                },
                child: const Text('Créer un projet'),
              ),
              fallback: const Text(
                'Vous n\'avez pas l\'autorisation de créer des projets',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _checkProjectAccess,
      child: ListView.builder(
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          return ModernProjectCard(
            project: project,
            teamCount: _projectTeamCounts[project.id],
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailScreen(projectId: project.id),
                ),
              );
              if (result == true) {
                _checkProjectAccess();
              }
            },
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectFormScreen(project: project),
                ),
              );
              if (result == true) {
                _checkProjectAccess();
              }
            },
            onDelete: () {
              _showDeleteConfirmationDialog(project);
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation de suppression'),
        content: Text('Voulez-vous vraiment supprimer le projet "${project.name}" ?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _projectService.deleteProject(project.id);
                _checkProjectAccess();
              } catch (e) {
                print('Erreur lors de la suppression du projet : $e');
              }
              Navigator.of(context).pop();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('ERREUR: ProjectsScreen - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (ProjectsScreen) =====');
      print('ID utilisateur: ${user.id}');
      print('Email: ${user.email}');
      
      // Récupérer le profil utilisateur
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      if (profileResponse != null) {
        print('Nom: ${profileResponse['first_name']} ${profileResponse['last_name']}');
      }
      
      // Récupérer les rôles de l'utilisateur
      final userRolesResponse = await Supabase.instance.client
          .from('user_roles')
          .select('role_id, roles (name, description), team_id, project_id')
          .eq('user_id', user.id);
      
      print('\nRôles attribués:');
      if (userRolesResponse != null && userRolesResponse.isNotEmpty) {
        for (var roleData in userRolesResponse) {
          final roleName = roleData['roles']['name'];
          final roleDesc = roleData['roles']['description'];
          final teamId = roleData['team_id'];
          final projectId = roleData['project_id'];
          
          print('- Rôle: $roleName ($roleDesc)');
          if (teamId != null) print('  → Équipe: $teamId');
          if (projectId != null) print('  → Projet: $projectId');
          
          // Récupérer toutes les permissions pour ce rôle
          final rolePermissions = await Supabase.instance.client
              .from('role_permissions')
              .select('permissions (name, description)')
              .eq('role_id', roleData['role_id']);
          
          if (rolePermissions != null && rolePermissions.isNotEmpty) {
            print('  Permissions:');
            for (var permData in rolePermissions) {
              final permName = permData['permissions']['name'];
              final permDesc = permData['permissions']['description'];
              print('    • $permName: $permDesc');
            }
          }
        }
      } else {
        print('Aucun rôle attribué à cet utilisateur.');
      }
      
      // Vérifier spécifiquement la permission pour l'écran des projets
      final hasProjectAccess = await Supabase.instance.client.rpc('user_has_permission', params: {
        'p_user_id': user.id,
        'p_permission_name': 'read_project',
      });
      print('\nPermission "read_project" (accès projets): ${hasProjectAccess ? 'ACCORDÉE' : 'REFUSÉE'}');
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }
}
