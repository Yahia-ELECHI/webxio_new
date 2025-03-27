import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/project_model.dart';
import '../../models/team_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';
import '../../providers/role_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/permission_gated.dart';
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
  
  List<Project> _projects = [];
  Map<String, int> _projectTeamCounts = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjects();
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
    return Scaffold(
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
}
