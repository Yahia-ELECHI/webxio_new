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
import '../../services/project_finance_service.dart';
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
  final ProjectFinanceService _projectFinanceService = ProjectFinanceService();
  
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
        
        // En mode projet spécifique, récupérer uniquement les transactions du projet
        _projectTransactionsList = await _projectFinanceService.getProjectTransactions(_selectedProjectId!);
        
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
        
        // Charger toutes les transactions accessibles par l'utilisateur
        _projectTransactionsList = await _projectFinanceService.getAllProjectTransactions();
        
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
      
      // Calcul du pourcentage d'utilisation du budget basé sur les transactions accessibles
      double budgetUsagePercentage = 0;
      
      if (_projectTransactionsList.isNotEmpty) {
        final projectTransactions = _projectTransactionsList.where((tx) => tx.projectId == project.id).toList();
        
        // Si on a trouvé des transactions pour ce projet, calculer le pourcentage d'utilisation
        if (projectTransactions.isNotEmpty) {
          // Calculer les dépenses (expenses)
          double usedBudget = projectTransactions
              .where((tx) => !tx.isIncome)
              .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
          
          // Calculer les revenus (income)
          double totalRevenues = projectTransactions
              .where((tx) => tx.isIncome)
              .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
          
          // Si nous avons des revenus, calculer le pourcentage par rapport aux revenus
          if (totalRevenues > 0) {
            budgetUsagePercentage = (usedBudget / totalRevenues) * 100;
          } else if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
            // Sinon, utiliser le budget alloué comme référence si disponible
            budgetUsagePercentage = (usedBudget / project.budgetAllocated!) * 100;
          } else {
            // Si pas de revenus et pas de budget alloué, montrer le pourcentage en fonction des dépenses
            budgetUsagePercentage = usedBudget > 0 ? 100 : 0; // Si des dépenses existent sans revenus ni budget, 100%
          }
          budgetUsagePercentage = budgetUsagePercentage.clamp(0, 100);
        } else {
          // Si pas de transactions accessibles, utiliser la valeur par défaut du projet
          budgetUsagePercentage = project.budgetUsagePercentage;
        }
      } else {
        // Si pas de transactions accessibles, utiliser la valeur par défaut du projet
        budgetUsagePercentage = project.budgetUsagePercentage;
      }
      
      // Déterminer la couleur en fonction du pourcentage d'utilisation
      Color budgetStatusColor;
      if (budgetUsagePercentage < 50) {
        budgetStatusColor = Colors.green; // Moins de 50% du budget utilisé : vert
      } else if (budgetUsagePercentage < 75) {
        budgetStatusColor = Colors.orange; // Entre 50% et 75% : orange
      } else {
        budgetStatusColor = Colors.red; // Plus de 75% : rouge
      }
      
      return ProjectProgressData(
        projectName: project.name,
        projectId: project.id,
        progressPercentage: progressPercentage,
        budgetUsagePercentage: budgetUsagePercentage,
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
      
      // Calcul des informations budgétaires
      double? budgetAllocated = phase.budgetAllocated;
      double? budgetConsumed = phase.budgetConsumed;
      double? budgetUsagePercentage;
      Color? budgetStatusColor;
      
      // Si des infos budgétaires sont disponibles, calculer le pourcentage d'utilisation
      if (budgetAllocated != null && budgetAllocated > 0) {
        if (budgetConsumed != null) {
          budgetUsagePercentage = (budgetConsumed / budgetAllocated) * 100;
          
          // Déterminer la couleur en fonction du pourcentage d'utilisation
          if (budgetUsagePercentage < 50) {
            budgetStatusColor = Colors.green; // Moins de 50% du budget utilisé : vert
          } else if (budgetUsagePercentage < 75) {
            budgetStatusColor = Colors.orange; // Entre 50% et 75% : orange
          } else {
            budgetStatusColor = Colors.red; // Plus de 75% : rouge
          }
        }
      } else {
        // Essayer de calculer à partir des transactions si disponibles
        final phaseTransactions = _projectTransactionsList.where((tx) => tx.phaseId == phase.id).toList();
        
        if (phaseTransactions.isNotEmpty) {
          // Calculer le budget alloué à partir des transactions de revenu (income)
          double allocatedFromTransactions = phaseTransactions
              .where((tx) => tx.isIncome)
              .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
          
          // Calculer le budget consommé à partir des transactions de dépense (expense)
          double consumedFromTransactions = phaseTransactions
              .where((tx) => !tx.isIncome)
              .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
          
          if (allocatedFromTransactions > 0) {
            budgetAllocated = allocatedFromTransactions;
            budgetConsumed = consumedFromTransactions;
            budgetUsagePercentage = (consumedFromTransactions / allocatedFromTransactions) * 100;
            
            // Déterminer la couleur en fonction du pourcentage d'utilisation
            if (budgetUsagePercentage < 50) {
              budgetStatusColor = Colors.green; // Moins de 50% du budget utilisé : vert
            } else if (budgetUsagePercentage < 75) {
              budgetStatusColor = Colors.orange; // Entre 50% et 75% : orange
            } else {
              budgetStatusColor = Colors.red; // Plus de 75% : rouge
            }
          }
        }
      }
      
      return PhaseProgressData(
        phaseId: phase.id,
        phaseName: phase.name,
        projectId: phase.projectId,
        projectName: phase.projectName ?? 'Projet inconnu',
        progressPercentage: progressPercentage,
        status: phase.status,
        statusColor: _getPhaseStatusColor(phase.status),
        budgetAllocated: budgetAllocated,
        budgetConsumed: budgetConsumed,
        budgetUsagePercentage: budgetUsagePercentage,
        budgetStatusColor: budgetStatusColor,
      );
    }).toList();
  }
  
  void _prepareBudgetOverviewData(List<Project> projects) {
    
    // Filtrer les projets avec un budget alloué ou des transactions
    List<Project> relevantProjects = projects.where((project) {
      // Vérifier si le projet a un budget alloué
      bool hasBudget = project.budgetAllocated != null && project.budgetAllocated! > 0;
      
      // Vérifier si le projet a des transactions
      bool hasTransactions = _projectTransactionsList.any((tx) => tx.projectId == project.id);
      
      // Inclure le projet s'il a un budget ou des transactions
      return hasBudget || hasTransactions;
    }).toList();
    
    _budgetOverviewData = relevantProjects
      .map((project) {
        
        // Calcul du pourcentage d'utilisation du budget basé sur les transactions accessibles
        double usedBudget = 0;
        double budgetUsagePercentage = 0;
        
        if (_projectTransactionsList.isNotEmpty) {
          final projectTransactions = _projectTransactionsList.where((tx) => tx.projectId == project.id).toList();
          
          // Si on a trouvé des transactions pour ce projet, calculer le montant utilisé
          if (projectTransactions.isNotEmpty) {
            // Calculer les dépenses (expenses)
            usedBudget = projectTransactions
                .where((tx) => !tx.isIncome)
                .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
            
            // Calculer les revenus (income)
            double totalRevenues = projectTransactions
                .where((tx) => tx.isIncome)
                .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
            
            // Si nous avons des revenus, calculer le pourcentage par rapport aux revenus
            if (totalRevenues > 0) {
              budgetUsagePercentage = (usedBudget / totalRevenues) * 100;
            } else if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
              // Sinon, utiliser le budget alloué comme référence si disponible
              budgetUsagePercentage = (usedBudget / project.budgetAllocated!) * 100;
            } else {
              // Si pas de revenus et pas de budget alloué, montrer le pourcentage en fonction des dépenses
              budgetUsagePercentage = usedBudget > 0 ? 100 : 0; // Si des dépenses existent sans revenus ni budget, 100%
            }
            budgetUsagePercentage = budgetUsagePercentage.clamp(0, 100);
          } else {
            // Si pas de transactions accessibles, utiliser la valeur par défaut du projet
            usedBudget = project.budgetConsumed ?? 0;
            budgetUsagePercentage = project.budgetUsagePercentage;
          }
        } else {
          // Si pas de transactions accessibles, utiliser la valeur par défaut du projet
          usedBudget = project.budgetConsumed ?? 0;
          budgetUsagePercentage = project.budgetUsagePercentage;
        }
        
        // Déterminer la couleur en fonction du pourcentage d'utilisation
        Color budgetColor;
        if (budgetUsagePercentage < 50) {
          budgetColor = Colors.green; // Moins de 50% du budget utilisé : vert
        } else if (budgetUsagePercentage < 75) {
          budgetColor = Colors.orange; // Entre 50% et 75% : orange
        } else {
          budgetColor = Colors.red; // Plus de 75% : rouge
        }
        
        return BudgetOverviewData(
          projectName: project.name,
          projectId: project.id,
          allocatedBudget: project.budgetAllocated ?? 0,
          usedBudget: usedBudget,
          color: budgetColor,
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
    if (percentage < 50) {
      return Colors.green; // Moins de 50% du budget utilisé : vert
    } else if (percentage < 75) {
      return Colors.orange; // Entre 50% et 75% : orange
    } else {
      return Colors.red; // Plus de 75% : rouge
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
                      height: 730, 
                      child: TasksProjectsSection(
                        tasksByStatusData: _tasksByStatusData,
                        tasksByPriorityData: _tasksByPriorityData,
                        projectProgressData: _projectProgressData,
                        upcomingTasksData: _upcomingTasksData,
                        onSeeAllProjects: _navigateToProjectsList,
                        onSeeAllTasks: _navigateToTasksList,
                        onProjectTap: _navigateToProjectDetails,
                        onTaskTap: _navigateToTaskDetails,
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Section des phases
                    SizedBox(
                      height: 350, 
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
    
    // Utiliser LayoutBuilder pour s'adapter à différentes tailles d'écran
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapter la taille du texte en fonction de la largeur disponible
        final double titleFontSize = constraints.maxWidth < 350 ? 20 : 24;
        final double subtitleFontSize = constraints.maxWidth < 350 ? 14 : 16;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Première ligne avec salutation et sélecteur de projet
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Texte de salutation avec ellipsis pour éviter le débordement
                Flexible(
                  child: Text(
                    '$greeting !',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Espace flexible entre les éléments
                const SizedBox(width: 8),
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
            // Deuxième ligne avec le message de bienvenue
            Wrap(
              children: [
                Text(
                  'Bienvenue sur votre tableau de bord',
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!_showAllProjects && _selectedProjectId != null)
                  Text(
                    ' - ${_selectedProjectName}',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        );
      }
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
      phase.status.toLowerCase() == 'completed' ||
      phase.status.toLowerCase() == 'terminée'
    ).length;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ajuster le nombre de colonnes en fonction de la largeur
        int crossAxisCount = constraints.maxWidth < 600 ? 1 : 
                           constraints.maxWidth < 900 ? 2 : 3;
        
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 3.0,
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
              title: 'Phases terminées',
              value: '$inProgressPhases/${_phasesList.length}',
              icon: Icons.checklist_rounded,
              color: Colors.green,
              onTap: _navigateToPhasesList,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapter la taille des éléments en fonction de la largeur disponible
        final double availableWidth = constraints.maxWidth;
        final bool isSmallScreen = availableWidth < 200;
        final bool isMediumScreen = availableWidth >= 200 && availableWidth < 300;
        
        // Adapter la taille des éléments
        final double iconSize = isSmallScreen ? 16 : 20;
        final double containerSize = isSmallScreen ? 32 : 40;
        final double fontSize = isSmallScreen ? 11 : (isMediumScreen ? 12 : 14);
        final double titleFontSize = isSmallScreen ? 10 : (isMediumScreen ? 11 : 12);
        
        return GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Container(
                    width: containerSize,
                    height: containerSize,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: titleFontSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
