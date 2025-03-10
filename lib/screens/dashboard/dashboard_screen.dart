import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../models/budget_model.dart';
import '../../models/budget_transaction_model.dart';
import '../../services/task_service.dart';
import '../../services/project_service.dart';
import '../../services/phase_service.dart';
import '../../services/budget_service.dart';
import '../../main.dart'; // Import pour utiliser MainAppScreen
import 'models/dashboard_chart_models.dart';
import 'sections/tasks_projects_section.dart';
import 'sections/budget_finance_section.dart';
import 'sections/phases_section.dart';

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
  
  bool _isLoading = true;
  
  // Données brutes
  List<Task> _tasksList = [];
  List<Project> _projectsList = [];
  List<Phase> _phasesList = [];
  List<Budget> _budgetsList = [];
  List<BudgetTransaction> _transactionsList = [];

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
      // Chargement des projets, tâches et phases
      _projectsList = await _projectService.getProjects();
      _tasksList = await _taskService.getAllTasks();
      _phasesList = await _phaseService.getAllPhases();
      _budgetsList = await _budgetService.getBudgets();
      _transactionsList = await _budgetService.getRecentTransactions(10);
      
      // Charger les données budgétaires pour chaque projet
      for (var i = 0; i < _projectsList.length; i++) {
        final projectTransactions = await _budgetService.getTransactionsByProject(_projectsList[i].id);
        
        double allocated = 0;
        double consumed = 0;
        
        // Calculer l'allocation à partir des transactions positives
        final allocations = projectTransactions.where((t) => t.amount > 0);
        if (allocations.isNotEmpty) {
          allocated = allocations.fold(0, (sum, t) => sum + t.amount);
        }
        
        // Calculer la consommation à partir des transactions négatives
        final expenses = projectTransactions.where((t) => t.amount < 0);
        if (expenses.isNotEmpty) {
          consumed = expenses.fold(0, (sum, t) => sum + t.amount.abs());
        }
        
        // Mettre à jour le projet avec les valeurs calculées
        _projectsList[i] = _projectsList[i].copyWith(
          budgetAllocated: allocated > 0 ? allocated : _projectsList[i].budgetAllocated,
          budgetConsumed: consumed > 0 ? consumed : _projectsList[i].budgetConsumed,
        );
      }
      
      // Transformation des données pour les graphiques
      _prepareTasksByStatusData(_tasksList);
      _prepareTasksByPriorityData(_tasksList);
      _prepareProjectProgressData(_projectsList, _phasesList, _tasksList);
      _prepareUpcomingTasksData(_tasksList);
      _prepareBudgetOverviewData(_projectsList);
      _prepareRecentTransactionsData(_transactionsList);
      _preparePhaseProgressData(_phasesList, _tasksList);
      
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
  
  void _prepareRecentTransactionsData(List<BudgetTransaction> transactions) {
    _recentTransactionsData = transactions.map((transaction) {
      return RecentTransactionData(
        id: transaction.id,
        description: transaction.description,
        amount: transaction.amount,
        date: transaction.transactionDate,
        category: transaction.category,
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
      case 'en attente':
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
    Navigator.pushNamed(
      context,
      '/task-details',
      arguments: taskId,
    ).then((_) => _loadDashboardData());
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
                      height: 600, // Hauteur fixe pour cette section
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
                    
                    const SizedBox(height: 24),
                    
                    // Section des phases
                    SizedBox(
                      height: 400, // Hauteur fixe pour cette section
                      child: PhasesSection(
                        phaseProgressData: _phaseProgressData,
                        onSeeAllPhases: _navigateToPhasesList,
                        onPhaseTap: _navigateToPhaseDetails,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Section budget et finances
                    SizedBox(
                      height: 600, // Hauteur fixe pour cette section
                      child: BudgetFinanceSection(
                        budgetOverviewData: _budgetOverviewData,
                        recentTransactionsData: _recentTransactionsData,
                        onSeeAllBudget: _navigateToBudgetScreen,
                        onSeeAllTransactions: _navigateToTransactions,
                        onProjectTap: _navigateToProjectDetails,
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
        Text(
          '$greeting !',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bienvenue sur votre tableau de bord',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
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
                              fontSize: 18,
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
