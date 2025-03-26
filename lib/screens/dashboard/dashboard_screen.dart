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
import '../../services/cache_service.dart';
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
  final CacheService _cacheService = CacheService();

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
      // 1. Vérifier si des données complètes sont disponibles dans le cache
      final cachedProjects = _cacheService.getCachedProjects();
      final cachedTasks = _cacheService.getCachedTasks(null);
      final cachedPhases = _cacheService.getCachedPhases(null);
      final cachedTransactions = _cacheService.getCachedTransactions(null);

      // Si nous avons toutes les données principales en cache
      if (cachedProjects != null && cachedProjects.isNotEmpty &&
          cachedTasks != null && cachedTasks.isNotEmpty &&
          cachedPhases != null && cachedPhases.isNotEmpty) {

        // Afficher immédiatement les données du cache
        setState(() {
          _projectsList = cachedProjects.map((json) => Project.fromJson(json)).toList();
          _tasksList = cachedTasks.map((json) => Task.fromJson(json)).toList();
          _phasesList = cachedPhases.map((json) => Phase.fromJson(json)).toList();

          if (cachedTransactions != null && cachedTransactions.isNotEmpty) {
            _projectTransactionsList = cachedTransactions.map((json) => ProjectTransaction.fromJson(json)).toList();
          }

          // Créer mapping des tâches
          _tasksMap = {for (var task in _tasksList) task.id: task};

          // Mise à jour des graphiques avec les données disponibles
          _isLoading = false; // Marquer comme chargé avant de préparer les graphiques (pour afficher l'UI)
          
          // Lancer la préparation des graphiques de manière asynchrone
          _prepareAllChartData().then((_) {
            // Rafraîchir l'UI quand les données du budget planifié sont prêtes
            if (mounted) setState(() {});
          });
        });

        // 2. Continuer le chargement en arrière-plan (sans bloquer l'UI)
        _loadFullDataInBackground();
        return;
      }

      // Si pas de cache complet, charge normalement
      await _loadFullData();

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

  // Chargement complet des données (bloquant l'UI jusqu'à ce que tout soit chargé)
  Future<void> _loadFullData() async {
    try {
      // Chargement parallèle des données avec Future.wait pour optimiser le temps de chargement
      // (tous les appels API sont lancés en même temps)
      final results = await Future.wait([
        _projectService.getAllProjects(),
        _taskService.getAllTasks(),
        _phaseService.getAllPhases(),
        _projectFinanceService.getAllProjectTransactions(),
        _budgetService.getBudgets(),
        _budgetService.getRecentTransactions(10),
      ]);

      // Récupération des résultats avec cast explicite
      _projectsList = results[0] as List<Project>;
      _tasksList = results[1] as List<Task>;
      _phasesList = results[2] as List<Phase>;
      _projectTransactionsList = results[3] as List<ProjectTransaction>;
      _budgetsList = results[4] as List<Budget>;
      _budgetTransactionsList = results[5] as List<BudgetTransaction>;

      // Créer un mapping des tâches
      _tasksMap = {for (var task in _tasksList) task.id: task};

      // Charger l'historique des tâches récentes (limité à 50)
      await _loadTaskHistory();

      // Mettre en cache pour la prochaine visite
      if (_projectsList.isNotEmpty) {
        _cacheService.cacheProjects(_projectsList.map((p) => p.toJson()).toList());
      }

      if (_tasksList.isNotEmpty) {
        _cacheService.cacheTasks(null, _tasksList.map((t) => t.toJson()).toList());
      }

      if (_phasesList.isNotEmpty) {
        _cacheService.cachePhases(null, _phasesList.map((p) => p.toJson()).toList());
      }

      if (_projectTransactionsList.isNotEmpty) {
        _cacheService.cacheTransactions(null, _projectTransactionsList.map((t) => t.toJson()).toList());
      }

      // Préparation des données pour les charts et widgets
      await _prepareAllChartData();

    } catch (e) {
      print('Erreur lors du chargement complet des données: $e');
      rethrow;
    }
  }

  // Version non-bloquante du chargement complet qui s'exécute en arrière-plan
  Future<void> _loadFullDataInBackground() async {
    try {
      // Le même chargement mais en arrière-plan
      final results = await Future.wait([
        _projectService.getAllProjects(),
        _taskService.getAllTasks(),
        _phaseService.getAllPhases(),
        _projectFinanceService.getAllProjectTransactions(),
        _budgetService.getBudgets(),
        _budgetService.getRecentTransactions(10),
      ]);

      // Récupération des résultats avec cast explicite
      final projects = results[0] as List<Project>;
      final tasks = results[1] as List<Task>;
      final phases = results[2] as List<Phase>;
      final projectTransactions = results[3] as List<ProjectTransaction>;
      final budgets = results[4] as List<Budget>;
      final budgetTransactions = results[5] as List<BudgetTransaction>;

      // Mise en cache des nouvelles données
      if (projects.isNotEmpty) {
        _cacheService.cacheProjects(projects.map((p) => p.toJson()).toList());
      }

      if (tasks.isNotEmpty) {
        _cacheService.cacheTasks(null, tasks.map((t) => t.toJson()).toList());
      }

      if (phases.isNotEmpty) {
        _cacheService.cachePhases(null, phases.map((p) => p.toJson()).toList());
      }

      if (projectTransactions.isNotEmpty) {
        _cacheService.cacheTransactions(null, projectTransactions.map((t) => t.toJson()).toList());
      }

      // Si le widget est toujours monté, mettre à jour les données
      if (mounted) {
        setState(() {
          _projectsList = projects;
          _tasksList = tasks;
          _phasesList = phases;
          _projectTransactionsList = projectTransactions;
          _budgetsList = budgets;
          _budgetTransactionsList = budgetTransactions;

          // Créer un mapping des tâches
          _tasksMap = {for (var task in _tasksList) task.id: task};

          // Préparer toutes les données pour les graphiques
          _prepareAllChartData().then((_) {
            // Rafraîchir l'UI quand les données du budget planifié sont prêtes
            if (mounted) setState(() {});
          });
        });

        // Charger l'historique des tâches en arrière-plan et mettre à jour l'interface
        _loadTaskHistory().then((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    } catch (e) {
      // Silencieux en arrière-plan pour ne pas déranger l'utilisateur
      print('Erreur lors du chargement en arrière-plan: $e');
    }
  }

  // Méthode dédiée au chargement de l'historique des tâches
  Future<void> _loadTaskHistory() async {
    try {
      _taskHistoryList = [];

      // On récupère les tâches les plus récentes pour limiter le volume de données
      final recentTasks = List<Task>.from(_tasksList)
        ..sort((a, b) => b.updatedAt?.compareTo(a.updatedAt ?? a.createdAt) ??
                          b.createdAt.compareTo(a.createdAt));
      final tasksToFetch = recentTasks.take(20).toList();

      // Exécution parallèle des requêtes d'historique
      final historyFutures = tasksToFetch.map(
        (task) => _projectService.getTaskHistory(task.id)
      ).toList();

      final historyResults = await Future.wait(historyFutures);

      // Combiner tous les résultats
      for (var history in historyResults) {
        _taskHistoryList.addAll(history);
      }

      // Limiter à 50 entrées d'historique les plus récentes
      _taskHistoryList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (_taskHistoryList.length > 50) {
        _taskHistoryList = _taskHistoryList.sublist(0, 50);
      }

      // Chargement des noms d'utilisateurs
      final userIds = <String>{};
      for (var history in _taskHistoryList) {
        userIds.add(history.userId);
      }

      if (userIds.isNotEmpty) {
        _userDisplayNames = await _userService.getUsersDisplayNames(userIds.toList());
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'historique des tâches: $e');
    }
  }

  // Prépare toutes les données pour les graphiques et widgets
  Future<void> _prepareAllChartData() async {
    // Préfiltrer les données si un projet spécifique est sélectionné
    List<Task> filteredTasks = _tasksList;
    List<Phase> filteredPhases = _phasesList;
    List<ProjectTransaction> filteredTransactions = _projectTransactionsList;
    
    // Si un projet spécifique est sélectionné, filtrer toutes les données
    if (!_showAllProjects && _selectedProjectId != null) {
      // Filtrer les tâches du projet sélectionné
      filteredTasks = _tasksList.where((task) => task.projectId == _selectedProjectId).toList();
      // Filtrer les phases du projet sélectionné
      filteredPhases = _phasesList.where((phase) => phase.projectId == _selectedProjectId).toList();
      // Filtrer les transactions du projet sélectionné
      filteredTransactions = _projectTransactionsList.where((tx) => tx.projectId == _selectedProjectId).toList();
      
      print('Projet sélectionné: $_selectedProjectId - Filtrage appliqué');
      print('Tâches filtrées: ${filteredTasks.length}/${_tasksList.length}');
      print('Phases filtrées: ${filteredPhases.length}/${_phasesList.length}');
      print('Transactions filtrées: ${filteredTransactions.length}/${_projectTransactionsList.length}');
    } else {
      print('Tous les projets sont sélectionnés - Aucun filtrage appliqué');
    }

    _prepareTasksByStatusData(filteredTasks);
    _prepareTasksByPriorityData(filteredTasks);
    await _prepareProjectProgressData(_projectsList, filteredPhases, filteredTasks);
    _prepareUpcomingTasksData(filteredTasks);
    _preparePhaseProgressData(filteredPhases, filteredTasks);
    _prepareBudgetOverviewData(_projectsList);
    _prepareRecentTransactionsData(filteredTransactions);
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

  Future<void> _prepareProjectProgressData(List<Project> projects, List<Phase> phases, List<Task> tasks) async {
    // Liste temporaire pour stocker les résultats
    final List<ProjectProgressData> tempData = [];
    
    // Traiter chaque projet
    for (var project in projects) {
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
      double plannedBudgetUsagePercentage = 0; // Nouveau pourcentage par rapport au budget prévu
      double usedBudget = 0; // Montant des dépenses utilisé pour les deux calculs
      double totalRevenues = 0; // Montant des revenus (budget réel)

      // Récupérer le budget planifié directement depuis la base de données (sans cache)
      double plannedBudget = await _projectService.getProjectPlannedBudget(project.id);
      print('Budget planifié pour ${project.name} récupéré directement: $plannedBudget');

      if (_projectTransactionsList.isNotEmpty) {
        final projectTransactions = _projectTransactionsList.where((tx) => tx.projectId == project.id).toList();

        // Si on a trouvé des transactions pour ce projet, calculer le pourcentage d'utilisation
        if (projectTransactions.isNotEmpty) {
          // Calculer les dépenses (expenses)
          usedBudget = projectTransactions
              .where((tx) => !tx.isIncome)
              .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);

          // Calculer les revenus (income)
          totalRevenues = projectTransactions
              .where((tx) => tx.isIncome)
              .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);

          // Si nous avons des revenus, calculer le pourcentage par rapport aux revenus
          if (totalRevenues > 0) {
            budgetUsagePercentage = (usedBudget / totalRevenues) * 100;
          } else if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
            // Sinon, utiliser le budget alloué comme référence si disponible
            budgetUsagePercentage = (usedBudget / project.budgetAllocated!) * 100;
            totalRevenues = project.budgetAllocated ?? 0; // Utiliser le budget alloué comme total des revenus
          } else {
            // Si pas de revenus et pas de budget alloué, montrer le pourcentage en fonction des dépenses
            budgetUsagePercentage = usedBudget > 0 ? 100 : 0; // Si des dépenses existent sans revenus ni budget, 100%
            totalRevenues = usedBudget; // Par défaut, les revenus égalent les dépenses (budget consommé à 100%)
          }
          budgetUsagePercentage = budgetUsagePercentage.clamp(0, 100);
          
          // Calcul du pourcentage par rapport au budget prévu (statique)
          if (plannedBudget > 0) {
            plannedBudgetUsagePercentage = (usedBudget / plannedBudget) * 100;
            plannedBudgetUsagePercentage = plannedBudgetUsagePercentage.clamp(0, 100);
          } else {
            plannedBudgetUsagePercentage = 0;
          }
        } else {
          // Si pas de transactions accessibles, utiliser la valeur par défaut du projet
          budgetUsagePercentage = project.budgetUsagePercentage;
          
          // Calculer le pourcentage par rapport au budget prévu
          if (plannedBudget > 0 && project.budgetConsumed != null) {
            plannedBudgetUsagePercentage = (project.budgetConsumed! / plannedBudget) * 100;
            plannedBudgetUsagePercentage = plannedBudgetUsagePercentage.clamp(0, 100);
          } else {
            plannedBudgetUsagePercentage = 0;
          }
          
          // Utiliser les valeurs par défaut du projet
          if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
            totalRevenues = project.budgetAllocated!;
          }
          if (project.budgetConsumed != null) {
            usedBudget = project.budgetConsumed!;
          }
        }
      } else {
        // Si pas de transactions accessibles, utiliser la valeur par défaut du projet
        budgetUsagePercentage = project.budgetUsagePercentage;
        
        // Calculer le pourcentage par rapport au budget prévu
        if (plannedBudget > 0 && project.budgetConsumed != null) {
          plannedBudgetUsagePercentage = (project.budgetConsumed! / plannedBudget) * 100;
          plannedBudgetUsagePercentage = plannedBudgetUsagePercentage.clamp(0, 100);
        } else {
          plannedBudgetUsagePercentage = 0;
        }
        
        // Utiliser les valeurs par défaut du projet
        if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
          totalRevenues = project.budgetAllocated!;
        }
        if (project.budgetConsumed != null) {
          usedBudget = project.budgetConsumed!;
        }
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

      // Ajouter à la liste temporaire
      tempData.add(ProjectProgressData(
        projectName: project.name,
        projectId: project.id,
        progressPercentage: progressPercentage,
        budgetUsagePercentage: budgetUsagePercentage,
        plannedBudgetUsagePercentage: plannedBudgetUsagePercentage,
        budgetAmount: totalRevenues,
        plannedBudgetAmount: plannedBudget, 
        usedBudgetAmount: usedBudget,
        progressColor: _getProgressColor(progressPercentage),
      ));
    }
    
    // Mettre à jour la liste finale
    setState(() {
      _projectProgressData = tempData;
    });
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
    // Si un projet spécifique est sélectionné, ne garder que ce projet
    List<Project> relevantProjects = projects;
    if (!_showAllProjects && _selectedProjectId != null) {
      relevantProjects = projects.where((project) => project.id == _selectedProjectId).toList();
    }

    // Filtrer les projets avec un budget alloué ou des transactions
    relevantProjects = relevantProjects.where((project) {
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

          // Si on a trouvé des transactions pour ce projet, calculer le pourcentage d'utilisation
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
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadFullData();
    } catch (e) {
      print('Erreur lors du rafraîchissement des données: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du rafraîchissement des données: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        final double titleFontSize = constraints.maxWidth < 350 ? 20 : 20;
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
    // Filtrer les données en fonction du projet sélectionné
    List<Task> filteredTasks = _tasksList;
    List<Phase> filteredPhases = _phasesList;
    List<Project> relevantProjects = _projectsList;
    
    if (!_showAllProjects && _selectedProjectId != null) {
      filteredTasks = _tasksList.where((task) => task.projectId == _selectedProjectId).toList();
      filteredPhases = _phasesList.where((phase) => phase.projectId == _selectedProjectId).toList();
      relevantProjects = _projectsList.where((project) => project.id == _selectedProjectId).toList();
    }

    // Calculer le nombre de tâches terminées
    final int completedTasks = filteredTasks.where((task) =>
      task.status.toLowerCase() == 'completed' ||
      task.status.toLowerCase() == 'terminée'
    ).length;

    // Calculer le nombre de phases en cours
    final int inProgressPhases = filteredPhases.where((phase) =>
      phase.status.toLowerCase() == 'completed' ||
      phase.status.toLowerCase() == 'terminée'
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
          value: relevantProjects.length.toString(),
          icon: Icons.folder,
          color: Colors.blue,
          onTap: _navigateToProjectsList,
        ),
        _buildSummaryCard(
          title: 'Tâches',
          value: '$completedTasks/${filteredTasks.length}',
          icon: Icons.task_alt,
          color: Colors.green,
          onTap: _navigateToTasksList,
        ),
        _buildSummaryCard(
          title: 'Phases',
          value: '$inProgressPhases/${filteredPhases.length}',
          icon: Icons.checklist_rounded,
          color: Colors.green,
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
    // Récupérer la largeur de l'écran pour adapter la taille des éléments
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 400;
    final bool isMediumScreen = screenWidth >= 400 && screenWidth < 600;

    // Adapter la taille des éléments en fonction de la taille de l'écran
    final double iconSize = isSmallScreen ? 16 : 20;
    final double containerSize = isSmallScreen ? 32 : 40;
    final double fontSize = isSmallScreen ? 11 : (isMediumScreen ? 12 : 15);
    final double titleFontSize = isSmallScreen ? 10 : (isMediumScreen ? 11 : 12);
    final EdgeInsets padding = isSmallScreen 
        ? const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
        : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0);

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
                padding: padding,
                child: Row(
                  children: [
                    Container(
                      width: containerSize,
                      height: containerSize,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            widget.value,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Étiquette transparente qui apparaît lors du clic
              //if (_isPressed)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 8.0),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
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
