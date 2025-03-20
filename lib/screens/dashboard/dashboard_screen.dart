import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../models/budget_model.dart';
import '../../models/budget_transaction_model.dart';
import '../../models/project_transaction_model.dart';
import '../../models/task_history_model.dart';
import '../../services/task_service.dart';
import '../../services/project_service/project_service.dart';
import '../../services/phase_service.dart';
import '../../services/budget_service.dart';
import '../../services/user_service.dart';
import '../../main.dart'; // Import pour utiliser MainAppScreen
import 'models/dashboard_chart_models.dart';
import 'sections/tasks_projects_section.dart';
import 'sections/phases_section.dart';
import 'sections/task_history_section.dart';
import 'widgets/cagnotte_webview.dart';
import 'widgets/modern_project_selector.dart';
import '../tasks/task_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TaskService _taskService = TaskService();
  final ProjectService _projectService = ProjectService();
  final PhaseService _phaseService = PhaseService();
  final BudgetService _budgetService = BudgetService();
  final UserService _userService = UserService();
  
  bool _isLoading = true;
  
  // Sélection par projet
  String? _selectedProjectId;
  bool _showAllProjects = true; // Afficher tous les projets par défaut
  
  // Obtenir le nom du projet sélectionné
  String get _selectedProjectName {
    if (_selectedProjectId == null || _projectsList.isEmpty) {
      return "";
    }
    
    final project = _projectsList.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => Project(
        id: "",
        name: "Projet inconnu",
        description: "",
        status: "active",
        createdBy: "",
        createdAt: DateTime.now(),
      ),
    );
    
    return project.name;
  }
  
  // Données brutes
  List<Task> _tasksList = [];
  List<Project> _projectsList = [];
  List<Phase> _phasesList = [];
  List<Budget> _budgetsList = [];
  List<BudgetTransaction> _budgetTransactionsList = [];
  List<ProjectTransaction> _projectTransactionsList = [];
  List<TaskHistory> _taskHistoryList = [];
  Map<String, String> _userDisplayNames = {};
  Map<String, Task> _tasksMap = {};

  // Données pour les graphiques
  List<TaskDistributionData> _tasksByStatusData = [];
  List<TaskDistributionData> _tasksByPriorityData = [];
  List<ProjectProgressData> _projectProgressData = [];
  List<TaskTimelineData> _upcomingTasksData = [];
  List<BudgetOverviewData> _budgetOverviewData = [];
  List<RecentTransactionData> _recentTransactionsData = [];
  List<PhaseProgressData> _phaseProgressData = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Chargement des projets
      _projectsList = await _projectService.getAllProjects();
      
      // Chargement des données selon le projet sélectionné ou tous les projets
      if (!_showAllProjects && _selectedProjectId != null) {
        // Charger les tâches du projet sélectionné
        _tasksList = await _taskService.getTasksByProject(_selectedProjectId!);
        
        // Charger les phases du projet sélectionné
        _phasesList = await _phaseService.getPhasesByProject(_selectedProjectId!);
        
        // Charger les données budgétaires du projet sélectionné
        _budgetsList = await _budgetService.getProjectBudgets(_selectedProjectId!);
        _budgetTransactionsList = await _budgetService.getRecentTransactions(10);
        _projectTransactionsList = await _budgetService.getTransactionsByProject(_selectedProjectId!);
        
        // Charger l'historique des tâches pour le projet sélectionné
        final allTasksInProject = await _taskService.getTasksByProject(_selectedProjectId!);
        _tasksMap = {for (var task in allTasksInProject) task.id: task};
        
        // On récupère l'historique pour chaque tâche du projet
        _taskHistoryList = [];
        for (var task in allTasksInProject) {
          final history = await _projectService.getTaskHistory(task.id);
          _taskHistoryList.addAll(history);
        }
        
        // Limiter à 50 entrées d'historique les plus récentes
        _taskHistoryList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (_taskHistoryList.length > 50) {
          _taskHistoryList = _taskHistoryList.sublist(0, 50);
        }
      } else {
        // Charger toutes les données
        _tasksList = await _taskService.getAllTasks();
        _phasesList = await _phaseService.getAllPhases();
        _budgetsList = await _budgetService.getBudgets();
        _budgetTransactionsList = await _budgetService.getRecentTransactions(10);
        _projectTransactionsList = [];
        
        // Créer un mapping des tâches
        _tasksMap = {for (var task in _tasksList) task.id: task};
        
        // Charger l'historique des tâches récentes (limité à 50)
        _taskHistoryList = [];
        // On récupère les 10 tâches les plus récentes pour limiter le volume de données
        final recentTasks = List<Task>.from(_tasksList)
          ..sort((a, b) => b.updatedAt?.compareTo(a.updatedAt ?? a.createdAt) ?? 
                            b.createdAt.compareTo(a.createdAt));
        final tasksToFetch = recentTasks.take(20).toList();
        
        for (var task in tasksToFetch) {
          final history = await _projectService.getTaskHistory(task.id);
          _taskHistoryList.addAll(history);
        }
        
        // Limiter à 50 entrées d'historique les plus récentes
        _taskHistoryList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (_taskHistoryList.length > 50) {
          _taskHistoryList = _taskHistoryList.sublist(0, 50);
        }
      }
      
      // Préparation des données pour les charts et widgets
      _prepareTasksByStatusData(_tasksList);
      _prepareTasksByPriorityData(_tasksList);
      _prepareProjectProgressData(_projectsList, _phasesList, _tasksList);
      _prepareUpcomingTasksData(_tasksList);
      _preparePhaseProgressData(_phasesList, _tasksList);
      _prepareBudgetOverviewData(_projectsList);
      _prepareRecentTransactionsData(_projectTransactionsList);
      
      // Chargement des noms d'utilisateurs
      final userIds = <String>{};
      for (var history in _taskHistoryList) {
        userIds.add(history.userId);
      }
      
      if (userIds.isNotEmpty) {
        _userDisplayNames = await _userService.getUsersDisplayNames(userIds.toList());
      }
      
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des données: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _prepareTasksByStatusData(List<Task> tasks) {
    // Comptage des tâches par statut
    final Map<String, int> statusCount = {};
    for (var task in tasks) {
      if (statusCount.containsKey(task.status)) {
        statusCount[task.status] = statusCount[task.status]! + 1;
      } else {
        statusCount[task.status] = 1;
      }
    }
    
    // Conversion en format pour le graphique
    _tasksByStatusData = statusCount.entries.map((entry) {
      return TaskDistributionData(
        label: _getStatusLabel(entry.key),  // Conversion du statut en libellé lisible
        count: entry.value,
        color: _getStatusColor(entry.key),
      );
    }).toList();
  }
  
  void _prepareTasksByPriorityData(List<Task> tasks) {
    // Comptage des tâches par priorité
    final Map<int, int> priorityCount = {};
    for (var task in tasks) {
      if (priorityCount.containsKey(task.priority)) {
        priorityCount[task.priority] = priorityCount[task.priority]! + 1;
      } else {
        priorityCount[task.priority] = 1;
      }
    }
    
    // Conversion en format pour le graphique
    _tasksByPriorityData = priorityCount.entries.map((entry) {
      return TaskDistributionData(
        label: _getPriorityLabel(entry.key),
        count: entry.value,
        color: _getPriorityColor(entry.key),
      );
    }).toList();
  }
  
  void _prepareProjectProgressData(List<Project> projects, List<Phase> phases, List<Task> tasks) {
    _projectProgressData = projects.map((project) {
      // Calcul du pourcentage de progression
      final projectPhases = phases.where((phase) => phase.projectId == project.id).toList();
      final projectTasks = tasks.where((task) => task.projectId == project.id).toList();
      
      double progressPercentage = 0;
      if (projectTasks.isNotEmpty) {
        final completedTasks = projectTasks.where((task) => 
          task.status.toLowerCase() == 'terminée' || 
          task.status.toLowerCase() == 'completed'
        ).length;
        progressPercentage = (completedTasks / projectTasks.length) * 100;
      }
      
      return ProjectProgressData(
        projectName: project.name,
        projectId: project.id,
        progressPercentage: progressPercentage,
        budgetUsagePercentage: project.budgetUsagePercentage,
        progressColor: _getProgressColor(progressPercentage),
      );
    }).toList();
  }
  
  void _prepareUpcomingTasksData(List<Task> tasks) {
    // Filtrer les tâches à venir (non terminées et avec une date d'échéance)
    final upcomingTasks = tasks.where((task) => 
      task.status.toLowerCase() != 'terminée' && 
      task.status.toLowerCase() != 'completed' &&
      task.dueDate != null
    ).toList();
    
    // Trier par date d'échéance
    upcomingTasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    
    // Limiter à 10 tâches
    final limitedTasks = upcomingTasks.take(10).toList();
    
    _upcomingTasksData = limitedTasks.map((task) {
      return TaskTimelineData(
        taskId: task.id,
        taskTitle: task.title,
        dueDate: task.dueDate!,
        priority: task.priority,
        status: task.status,
      );
    }).toList();
  }
  
  void _preparePhaseProgressData(List<Phase> phases, List<Task> tasks) {
    _phaseProgressData = phases.map((phase) {
      // Calcul du pourcentage de progression
      final phaseTasks = tasks.where((task) => task.phaseId == phase.id).toList();
      
      double progressPercentage = 0;
      if (phaseTasks.isNotEmpty) {
        final completedTasks = phaseTasks.where((task) => 
          task.status.toLowerCase() == 'terminée' || 
          task.status.toLowerCase() == 'completed'
        ).length;
        progressPercentage = (completedTasks / phaseTasks.length) * 100;
      }
      
      return PhaseProgressData(
        phaseId: phase.id,
        phaseName: phase.name,
        projectId: phase.projectId,
        projectName: phase.projectName ?? 'Projet inconnu',
        progressPercentage: progressPercentage,
        status: phase.status,
        statusColor: _getPhaseStatusColor(phase.status),
      );
    }).toList();
  }
  
  void _prepareBudgetOverviewData(List<Project> projects) {
    _budgetOverviewData = projects
      .where((project) => project.budgetAllocated != null && project.budgetAllocated! > 0)
      .map((project) {
        final budgetUsagePercentage = project.budgetUsagePercentage;
        
        return BudgetOverviewData(
          projectName: project.name,
          projectId: project.id,
          allocatedBudget: project.budgetAllocated ?? 0,
          usedBudget: project.budgetConsumed ?? 0,
          color: _getBudgetColor(budgetUsagePercentage),
        );
      }).toList();
  }
  
  void _prepareRecentTransactionsData(List<ProjectTransaction> transactions) {
    _recentTransactionsData = transactions.map((transaction) {
      return RecentTransactionData(
        id: transaction.id,
        description: transaction.description,
        amount: transaction.amount,
        date: transaction.transactionDate,
        category: transaction.category ?? (transaction.amount > 0 ? 'income' : 'expense'),
        isIncome: transaction.amount > 0,
      );
    }).toList();
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'à faire':
      case 'todo':
        return Colors.grey;
      case 'en cours':
      case 'in progress':
      case 'inprogress':
      case 'in_progress':
      case 'inProgress':
        return Colors.blue;
      case 'terminée':
      case 'completed':
        return Colors.green;
      case 'en revision':
      case 'review':
        return Colors.orange;
      case 'annulée':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }
  
  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 0: // Basse
        return Colors.green;
      case 1: // Moyenne
        return Colors.blue;
      case 2: // Haute
        return Colors.orange;
      case 3: // Urgente
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 0:
        return 'Basse';
      case 1:
        return 'Moyenne';
      case 2:
        return 'Haute';
      case 3:
        return 'Urgente';
      default:
        return 'Inconnue';
    }
  }
  
  Color _getProgressColor(double percentage) {
    if (percentage < 30) {
      return Colors.red;
    } else if (percentage < 70) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
  
  Color _getBudgetColor(double percentage) {
    if (percentage < 70) {
      return Colors.green;
    } else if (percentage < 90) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  Color _getPhaseStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'non démarré':
      case 'not started':
        return Colors.grey;
      case 'en cours':
      case 'in progress':
        return Colors.blue;
      case 'terminé':
      case 'completed':
        return Colors.green;
      case 'en attente':
      case 'on hold':
        return Colors.orange;
      case 'annulé':
      case 'cancelled':
        return Colors.red;
      default:
        return const Color.fromARGB(255, 215, 111, 234);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'à faire':
      case 'todo':
        return 'À faire';
      case 'en cours':
      case 'in progress':
      case 'inprogress':
      case 'in_progress':
      case 'inProgress':
        return 'En cours';
      case 'terminée':
      case 'completed':
        return 'Terminée';
      case 'en revision':
      case 'review':
        return 'En révision';
      case 'annulée':
      case 'cancelled':
        return 'Annulée';
      default:
        return status; // Si inconnu, on garde le statut original
    }
  }

  void _navigateToProjectDetails(String projectId) {
    Navigator.pushNamed(
      context,
      '/project-details',
      arguments: projectId,
    ).then((_) => _loadDashboardData());
  }

  void _navigateToTaskDetails(String taskId) {
    final task = _tasksMap[taskId];
    if (task != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(
            task: task,
            onTaskUpdated: (updatedTask) {
              // Mettre à jour la tâche dans la liste
              setState(() {
                final index = _tasksList.indexWhere((t) => t.id == updatedTask.id);
                if (index >= 0) {
                  _tasksList[index] = updatedTask;
                  _tasksMap[updatedTask.id] = updatedTask;
                }
                // Recharger les données du dashboard
                _loadDashboardData();
              });
            },
          ),
        ),
      );
    }
  }

  void _navigateToPhaseDetails(String phaseId) {
    Navigator.pushNamed(
      context,
      '/phase-details',
      arguments: phaseId,
    ).then((_) => _loadDashboardData());
  }

  void _navigateToProjectsList() {
    // Utilisation de la navigation basée sur l'index pour accéder à l'écran des projets
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainAppScreen(initialIndex: 1), // Index 1 correspond à ProjectsScreen
        ),
      );
    }
  }

  void _navigateToTasksList() {
    // Pour les tâches, on utilise la route nommée existante si disponible
    Navigator.pushNamed(context, '/tasks').then((_) => _loadDashboardData());
  }

  void _navigateToPhasesList() {
    // Redirection vers la page des projets qui contient les phases
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainAppScreen(initialIndex: 1), // Index 1 correspond à ProjectsScreen
        ),
      );
    }
  }

  void _navigateToBudgetScreen() {
    // Utilisation de la navigation basée sur l'index pour accéder à l'écran des finances
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainAppScreen(initialIndex: 5), // Index 5 correspond à FinanceDashboardScreen
        ),
      );
    }
  }

  void _navigateToTransactions() {
    // Redirection vers la page des finances qui contient les transactions
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainAppScreen(initialIndex: 5), // Index 5 correspond à FinanceDashboardScreen
        ),
      );
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadDashboardData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tableau de bord actualisé')),
    );
  }

  void _showProjectSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: ModernProjectSelector(
              projects: _projectsList,
              selectedProjectId: _selectedProjectId,
              showAllProjects: _showAllProjects,
              onProjectSelected: (projectId, showAll) {
                setState(() {
                  _showAllProjects = showAll;
                  _selectedProjectId = projectId;
                });
                _loadDashboardData();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    
                    // Section des tâches et projets
                    SizedBox(
                      height: 598, // Hauteur ajustée
                      child: TasksProjectsSection(
                        tasksByStatusData: _tasksByStatusData,
                        tasksByPriorityData: _tasksByPriorityData,
                        projectProgressData: _projectProgressData,
                        upcomingTasksData: _upcomingTasksData,
                        onProjectTap: _navigateToProjectDetails,
                        onTaskTap: _navigateToTaskDetails,
                        onSeeAllProjects: _navigateToProjectsList,
                        onSeeAllTasks: _navigateToTasksList,
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Section des phases
                    SizedBox(
                      height: 300, // Hauteur ajustée
                      child: PhasesSection(
                        phaseProgressData: _phaseProgressData,
                        onSeeAllPhases: _navigateToPhasesList,
                        onPhaseTap: _navigateToPhaseDetails,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Section budget et finances
                    SizedBox(
                      height: 600, 
                      child: CagnotteWebView(
                        title: 'Cagnotte en ligne',
                        onSeeAllPressed: _navigateToBudgetScreen,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Section historique des tâches
                    SizedBox(
                      height: 400,
                      child: TaskHistorySection(
                        taskHistoryData: _taskHistoryList,
                        userDisplayNames: _userDisplayNames,
                        tasksMap: _tasksMap,
                        onSeeAllHistory: null, // Ajoutez une fonction si besoin d'avoir un écran dédié
                        onTaskTap: _navigateToTaskDetails,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    final now = DateTime.now();
    String greeting;
    
    if (now.hour < 12) {
      greeting = 'Bonjour';
    } else if (now.hour < 18) {
      greeting = 'Bon après-midi';
    } else {
      greeting = 'Bonsoir';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$greeting !',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Bouton de sélection de projet
            if (_projectsList.isNotEmpty)
              ProjectSelectorButton(
                onPressed: _showProjectSelector,
                showAllProjects: _showAllProjects,
                projectName: _selectedProjectName,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Bienvenue sur votre tableau de bord',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (!_showAllProjects && _selectedProjectId != null)
              Expanded(
                child: Text(
                  ' - ${_selectedProjectName}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    // Calculer le nombre de tâches terminées
    final int completedTasks = _tasksList.where((task) => 
      task.status.toLowerCase() == 'completed' || 
      task.status.toLowerCase() == 'terminée'
    ).length;
    
    // Calculer le nombre de phases en cours
    final int inProgressPhases = _phasesList.where((phase) => 
      phase.status.toLowerCase() == 'en cours' || 
      phase.status.toLowerCase() == 'in progress' ||
      phase.status.toLowerCase() == 'in_progress'
    ).length;
    
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      children: [
        _buildSummaryCard(
          title: 'Total Projets',
          value: _projectsList.length.toString(),
          icon: Icons.folder,
          color: Colors.blue,
          onTap: _navigateToProjectsList,
        ),
        _buildSummaryCard(
          title: 'Tâches terminées',
          value: '$completedTasks/${_tasksList.length}',
          icon: Icons.task_alt,
          color: Colors.green,
          onTap: _navigateToTasksList,
        ),
        _buildSummaryCard(
          title: 'Phases en cours',
          value: inProgressPhases.toString(),
          icon: Icons.timeline,
          color: Colors.orange,
          onTap: _navigateToPhasesList,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SummaryCardWidget(
      title: title,
      value: value,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

class SummaryCardWidget extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SummaryCardWidget({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  State<SummaryCardWidget> createState() => _SummaryCardWidgetState();
}

class _SummaryCardWidgetState extends State<SummaryCardWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            widget.value,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Étiquette transparente qui apparaît lors du clic
              if (_isPressed)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
