import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/team_model.dart';
import '../../models/phase_model.dart';
import '../../models/budget_transaction_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/user_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../../services/budget_service.dart';
import '../../widgets/islamic_patterns.dart';
import '../../widgets/budget_summary_widget.dart';
import '../tasks/task_form_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../budget/budget_allocation_screen.dart';
import '../budget/transaction_form_screen.dart';
import '../budget/transaction_list_screen.dart';
import 'phases/phases_screen.dart';
import 'project_form_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectService _projectService = ProjectService();
  final TeamService _teamService = TeamService();
  final UserService _userService = UserService();
  final PhaseService _phaseService = PhaseService();
  final BudgetService _budgetService = BudgetService();
  
  Project? _project;
  List<Task> _tasks = [];
  List<Team> _projectTeams = [];
  List<Phase> _projectPhases = [];
  List<BudgetTransaction> _projectTransactions = [];
  
  bool _isLoading = true;
  bool _isLoadingTeams = true;
  bool _isLoadingPhases = true;
  bool _isLoadingBudget = true;
  String? _errorMessage;
  Map<String, String> _userDisplayNames = {};
  List<Team> _assignedTeams = [];
  
  // Map pour suivre l'état d'expansion de chaque phase (replié/déplié)
  Map<String, bool> _expandedPhases = {};

  @override
  void initState() {
    super.initState();
    _loadProjectDetails();
  }

  Future<void> _loadProjectDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final project = await _projectService.getProjectById(widget.projectId);
      final tasks = await _projectService.getTasksByProject(widget.projectId);
      
      setState(() {
        _project = project;
        _tasks = tasks;
        _isLoading = false;
      });
      
      // Récupérer tous les IDs d'utilisateurs (créateurs et assignés)
      final Set<String> userIds = {project.createdBy};
      for (final task in tasks) {
        userIds.add(task.createdBy);
        if (task.assignedTo != null) {
          userIds.add(task.assignedTo!);
        }
      }
      
      // Récupérer les noms d'affichage en une seule requête
      final userDisplayNames = await _userService.getUsersDisplayNames(userIds.toList());
      setState(() {
        _userDisplayNames = userDisplayNames;
      });
      
      _loadProjectTeams();
      _loadProjectPhases();
      _loadProjectBudget();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement du projet: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadProjectTeams() async {
    setState(() {
      _isLoadingTeams = true;
    });
    
    try {
      final teams = await _teamService.getTeamsByProject(widget.projectId);
      setState(() {
        _projectTeams = teams;
        _isLoadingTeams = false;
        _assignedTeams = teams;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des équipes: $e';
        _isLoadingTeams = false;
      });
    }
  }

  Future<void> _loadProjectPhases() async {
    if (_project == null) return;

    setState(() {
      _isLoadingPhases = true;
    });

    try {
      final phases = await _phaseService.getPhasesByProject(_project!.id);
      
      setState(() {
        _projectPhases = phases;
        _isLoadingPhases = false;
        
        // Initialiser toutes les phases comme repliées par défaut
        for (var phase in _projectPhases) {
          _expandedPhases[phase.id] = false;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingPhases = false;
        _errorMessage = 'Erreur lors du chargement des phases: $e';
      });
    }
  }

  Future<void> _loadProjectBudget() async {
    if (_project == null) return;

    setState(() {
      _isLoadingBudget = true;
    });

    try {
      final transactions = await _budgetService.getTransactionsByProject(_project!.id);
      
      setState(() {
        _projectTransactions = transactions;
        _isLoadingBudget = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBudget = false;
        _errorMessage = 'Erreur lors du chargement du budget: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_project?.name ?? 'Détails du projet'),
        actions: [
          if (_project != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _loadProjectDetails();
              },
            ),
          if (_project != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectFormScreen(
                      project: _project,
                    ),
                  ),
                );
                if (result == true) {
                  _loadProjectDetails();
                }
              },
            ),
          if (_project != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _showDeleteConfirmationDialog();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _project == null
              ? const Center(child: Text('Projet non trouvé'))
              : _buildBody(),
      floatingActionButton: _project != null
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhasesScreen(
                      project: _project!,
                    ),
                  ),
                );
                if (result == true) {
                  _loadProjectPhases();
                }
              },
              tooltip: 'Ajouter une phase',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadProjectDetails();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectHeader(),
            const SizedBox(height: 16),
            _buildProjectInfo(),
            const SizedBox(height: 24),
            _buildPhasesWithTasksSection(),
            const SizedBox(height: 24),
            _buildBudgetSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectHeader() {
    // Calculer les statistiques du projet
    final totalTasks = _tasks.length;
    final completedTasks = _tasks.where((task) => 
        TaskStatus.fromValue(task.status) == TaskStatus.completed).length;
    final totalPhases = _projectPhases.length;
    final completedPhases = _projectPhases.where((phase) => 
        PhaseStatus.fromValue(phase.status) == PhaseStatus.completed).length;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _project!.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_project!.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _project!.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard(
                  'Phases',
                  '$completedPhases/$totalPhases',
                  Icons.layers,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Tâches',
                  '$completedTasks/$totalTasks',
                  Icons.task_alt,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Équipes',
                  '${_projectTeams.length}',
                  Icons.people,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Créé par', _userDisplayNames[_project!.createdBy] ?? _project!.createdBy),
            _buildInfoRow('Créé le', _formatDate(_project!.createdAt)),
            if (_project!.updatedAt != null)
              _buildInfoRow('Mis à jour le', _formatDate(_project!.updatedAt!)),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // Section des équipes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Équipes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_projectTeams.isNotEmpty)
                  Text(
                    '${_projectTeams.length}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoadingTeams
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _projectTeams.isEmpty
                    ? const Text(
                        'Aucune équipe assignée à ce projet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _projectTeams.map((team) => Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              team.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          label: Text(team.name),
                          backgroundColor: Colors.grey[200],
                        )).toList(),
                      ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhasesWithTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Phases et Tâches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isLoadingPhases && _projectPhases.isEmpty)
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhasesScreen(
                        project: _project!,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadProjectPhases();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une phase'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingPhases)
          const Center(child: CircularProgressIndicator())
        else if (_projectPhases.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune phase définie pour ce projet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les phases vous permettent d\'organiser votre projet en étapes distinctes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhasesScreen(
                            project: _project!,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadProjectPhases();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une phase'),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(
            _projectPhases.length,
            (index) => _buildPhaseWithTasksCard(_projectPhases[index]),
          ),
        
        // Afficher les tâches sans phase à la fin
        if (!_isLoading && _tasks.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: 24),
              _buildTasksWithoutPhaseSection(),
            ],
          ),
      ],
    );
  }

  Widget _buildPhaseWithTasksCard(Phase phase) {
    final phaseStatus = PhaseStatus.fromValue(phase.status);
    final tasks = _tasks.where((task) => task.phaseId == phase.id).toList();
    final completedTasks = tasks.where((task) => TaskStatus.fromValue(task.status) == TaskStatus.completed).length;
    
    // Vérifier si cette phase est dépliée ou repliée
    final isExpanded = _expandedPhases[phase.id] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: phaseStatus.getColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la phase - cliquable pour replier/déplier
          InkWell(
            onTap: () {
              setState(() {
                _expandedPhases[phase.id] = !isExpanded;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: phaseStatus.getColor().withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: phaseStatus.getColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                phase.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: phaseStatus.getColor().withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: phaseStatus.getColor(),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                phaseStatus.getText(),
                                style: TextStyle(
                                  color: phaseStatus.getColor(),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (phase.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            phase.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Icône de flèche pour indiquer l'état replié/déplié
                  IconButton(
                    icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () {
                      setState(() {
                        _expandedPhases[phase.id] = !isExpanded;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhasesScreen(
                            project: _project!,
                            initialPhase: phase,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadProjectPhases();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Progression de la phase - toujours visible
          if (tasks.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, isExpanded ? 0 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progression: $completedTasks/${tasks.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${(completedTasks / tasks.length * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: tasks.isEmpty ? 0 : completedTasks / tasks.length,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(phaseStatus.getColor()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Liste des tâches - visible uniquement si déplié
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTasksSection(phase),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection(Phase phase) {
    final tasks = _tasks.where((task) => task.phaseId == phase.id).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tâches (${tasks.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskFormScreen(projectId: _project!.id, phaseId: phase.id),
                  ),
                );
                if (result == true) {
                  _loadProjectDetails();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Aucune tâche pour cette phase',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          ),
      ],
    );
  }

  Widget _buildTasksWithoutPhaseSection() {
    final tasksWithoutPhase = _tasks.where((task) => task.phaseId == null).toList();
    
    if (tasksWithoutPhase.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.task_alt, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Tâches sans phase (${tasksWithoutPhase.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskFormScreen(projectId: _project!.id),
                    ),
                  );
                  if (result == true) {
                    _loadProjectDetails();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasksWithoutPhase.length,
            itemBuilder: (context, index) {
              final task = tasksWithoutPhase[index];
              return _buildTaskCard(task);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final TaskStatus status = TaskStatus.fromValue(task.status);
    final TaskPriority priority = TaskPriority.fromValue(task.priority);
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(
                task: task,
                onTaskUpdated: (updatedTask) {
                  setState(() {
                    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
                    if (index != -1) {
                      _tasks[index] = updatedTask;
                    }
                  });
                },
                onTaskDeleted: (deletedTask) {
                  setState(() {
                    _tasks.removeWhere((t) => t.id == deletedTask.id);
                  });
                },
              ),
            ),
          );
          if (result == true) {
            _loadProjectDetails();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Indicateur de statut
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4, right: 8),
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: status == TaskStatus.completed 
                                      ? TextDecoration.lineThrough 
                                      : null,
                                  decorationColor: Colors.grey,
                                  color: status == TaskStatus.completed 
                                      ? Colors.grey 
                                      : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: status.color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status.displayName,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.assignedTo != null 
                              ? _userDisplayNames[task.assignedTo] ?? 'Utilisateur'
                              : 'Non assigné',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.dueDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.event, 
                          size: 16, 
                          color: task.dueDate!.isBefore(DateTime.now())
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(task.dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: task.dueDate!.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: priority.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: priority.color.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  priority.displayName,
                  style: TextStyle(
                    color: priority.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce projet ? Cette action supprimera également toutes les tâches associées et ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _projectService.deleteProject(_project!.id);
                if (mounted) {
                  Navigator.pop(context, true); // Retourner à l'écran précédent avec un résultat
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression du projet: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Budget',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BudgetAllocationScreen(
                      projectId: _project!.id,
                    ),
                  ),
                );
                if (result == true) {
                  _loadProjectBudget();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un budget'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingBudget)
          const Center(child: CircularProgressIndicator())
        else if (_projectTransactions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun budget défini pour ce projet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les budgets vous permettent de gérer les dépenses de votre projet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BudgetAllocationScreen(
                            projectId: _project!.id,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadProjectBudget();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un budget'),
                  ),
                ],
              ),
            ),
          )
        else
          BudgetSummaryWidget(
            transactions: _projectTransactions,
            onTransactionAdded: (transaction) {
              setState(() {
                _projectTransactions.add(transaction);
              });
            },
            onTransactionUpdated: (transaction) {
              setState(() {
                final index = _projectTransactions.indexWhere((t) => t.id == transaction.id);
                if (index != -1) {
                  _projectTransactions[index] = transaction;
                }
              });
            },
            onTransactionDeleted: (transaction) {
              setState(() {
                _projectTransactions.removeWhere((t) => t.id == transaction.id);
              });
            },
          ),
      ],
    );
  }
}
