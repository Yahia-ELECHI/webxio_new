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

  @override
  void initState() {
    super.initState();
    _loadProjects();
    // Tracer les informations sur l'utilisateur au démarrage de l'écran
    _logUserAccessInfo();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUser?.id;
      
      if (userId == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }
      
      final projects = await _projectService.getProjectsByUser(userId);
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
      
      // Charger le nombre d'équipes pour chaque projet
      _loadProjectTeamCounts();
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
    return RbacGatedScreen(
      permissionName: 'read_project',
      accessDeniedWidget: Scaffold(
        appBar: AppBar(
          title: const Text('Accès refusé'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Vous n\'avez pas l\'autorisation d\'accéder aux projets',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Veuillez contacter votre administrateur pour obtenir l\'accès',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigation à la page d'accueil
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      ),
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Mes Projets',
          showLogo: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProjects,
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: PermissionGated(
          permissionName: 'create_project',
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProjectFormScreen(),
                ),
              );
              if (result == true) {
                _loadProjects();
              }
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProjects,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

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
                    _loadProjects();
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
      onRefresh: _loadProjects,
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
                _loadProjects();
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
                _loadProjects();
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
                _loadProjects();
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
