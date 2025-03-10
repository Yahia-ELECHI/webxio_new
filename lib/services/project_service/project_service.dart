import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/task_history_model.dart';
import '../../models/phase_model.dart';

class ProjectService {
  final SupabaseClient _client = SupabaseConfig.client;
  final String _projectsTable = 'projects';
  final String _tasksTable = 'tasks';
  final String _phasesTable = 'phases';
  final String _taskHistoryTable = 'task_history';

  // Récupérer tous les projets
  Future<List<Project>> getAllProjects() async {
    try {
      final response = await _client
          .from(_projectsTable)
          .select()
          .order('created_at', ascending: false);
      
      return response.map((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des projets: $e');
      rethrow;
    }
  }

  // Récupérer les projets d'un utilisateur
  Future<List<Project>> getProjectsByUser(String userId) async {
    try {
      // 1. Récupérer les projets créés par l'utilisateur
      final createdProjects = await _client
          .from(_projectsTable)
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);
      
      // 2. Récupérer les projets associés aux équipes de l'utilisateur
      final teamProjectsResponse = await _client
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      final teamIds = teamProjectsResponse.map<String>((json) => json['team_id'] as String).toList();
      
      List<dynamic> teamProjects = [];
      if (teamIds.isNotEmpty) {
        final teamProjectsIdsResponse = await _client
            .from('team_projects')
            .select('project_id')
            .inFilter('team_id', teamIds);
        
        final projectIds = teamProjectsIdsResponse.map<String>((json) => json['project_id'] as String).toList();
        
        if (projectIds.isNotEmpty) {
          teamProjects = await _client
              .from(_projectsTable)
              .select()
              .inFilter('id', projectIds)
              .neq('created_by', userId) // Exclure les projets déjà récupérés
              .order('created_at', ascending: false);
        }
      }
      
      // 3. Combiner les deux listes
      final allProjects = [...createdProjects, ...teamProjects];
      
      return allProjects.map((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des projets de l\'utilisateur: $e');
      rethrow;
    }
  }

  // Récupérer un projet par son ID
  Future<Project> getProjectById(String projectId) async {
    try {
      final response = await _client
          .from(_projectsTable)
          .select()
          .eq('id', projectId)
          .single();
      
      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération du projet: $e');
      rethrow;
    }
  }

  // Créer un nouveau projet
  Future<Project> createProject(Project project) async {
    try {
      final response = await _client
          .from(_projectsTable)
          .insert(project.toJson())
          .select()
          .single();
      
      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la création du projet: $e');
      rethrow;
    }
  }

  // Mettre à jour un projet
  Future<Project> updateProject(Project project) async {
    try {
      final response = await _client
          .from(_projectsTable)
          .update(project.toJson())
          .eq('id', project.id)
          .select()
          .single();
      
      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la mise à jour du projet: $e');
      rethrow;
    }
  }

  // Supprimer un projet
  Future<void> deleteProject(String projectId) async {
    try {
      // Supprimer d'abord toutes les tâches associées au projet
      await _client
          .from(_tasksTable)
          .delete()
          .eq('project_id', projectId);
      
      // Puis supprimer le projet
      await _client
          .from(_projectsTable)
          .delete()
          .eq('id', projectId);
    } catch (e) {
      print('Erreur lors de la suppression du projet: $e');
      rethrow;
    }
  }

  // Récupérer toutes les tâches d'un projet
  Future<List<Task>> getTasksByProject(String projectId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .eq('project_id', projectId)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      
      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches du projet: $e');
      rethrow;
    }
  }

  // Récupérer les tâches assignées à un utilisateur
  Future<List<Task>> getTasksByUser(String userId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .eq('assigned_to', userId)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      
      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de l\'utilisateur: $e');
      rethrow;
    }
  }

  // Récupérer une tâche par son ID
  Future<Task> getTaskById(String taskId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .eq('id', taskId)
          .single();
      
      return Task.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération de la tâche: $e');
      rethrow;
    }
  }

  // Créer une nouvelle tâche
  Future<Task> createTask(Task task) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .insert(task.toJson())
          .select()
          .single();
      
      return Task.fromJson(response);
    } catch (e) {
      print('Erreur lors de la création de la tâche: $e');
      rethrow;
    }
  }

  // Mettre à jour une tâche
  Future<Task> updateTask(Task task, {Task? oldTask}) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .update(task.toJson())
          .eq('id', task.id)
          .select()
          .single();
      
      final updatedTask = Task.fromJson(response);
      
      // Si nous avons l'ancienne version de la tâche, enregistrer les changements dans l'historique
      if (oldTask != null) {
        await _recordTaskChanges(oldTask, updatedTask);
      }
      
      return updatedTask;
    } catch (e) {
      print('Erreur lors de la mise à jour de la tâche: $e');
      rethrow;
    }
  }

  // Mettre à jour le statut d'une tâche
  Future<Task> updateTaskStatus(String taskId, String newStatus) async {
    try {
      // Récupérer la tâche avant la mise à jour
      final oldTask = await getTaskById(taskId);
      
      // Mise à jour du statut
      final response = await _client
          .from(_tasksTable)
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', taskId)
          .select()
          .single();
      
      final updatedTask = Task.fromJson(response);
      
      // Enregistrer le changement dans l'historique
      await _addTaskHistoryEntry(
        taskId: taskId,
        fieldName: 'status',
        oldValue: oldTask.status,
        newValue: newStatus,
      );
      
      return updatedTask;
    } catch (e) {
      print('Erreur lors de la mise à jour du statut de la tâche: $e');
      rethrow;
    }
  }

  // Enregistrer les changements apportés à une tâche dans l'historique
  Future<void> _recordTaskChanges(Task oldTask, Task newTask) async {
    try {
      // Vérifier les changements de statut
      if (oldTask.status != newTask.status) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'status',
          oldValue: oldTask.status,
          newValue: newTask.status,
        );
      }
      
      // Vérifier les changements de priorité
      if (oldTask.priority != newTask.priority) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'priority',
          oldValue: oldTask.priority.toString(),
          newValue: newTask.priority.toString(),
        );
      }
      
      // Vérifier les changements d'assignation
      if (oldTask.assignedTo != newTask.assignedTo) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'assigned_to',
          oldValue: oldTask.assignedTo,
          newValue: newTask.assignedTo ?? '',
        );
      }
      
      // Vérifier les changements de titre
      if (oldTask.title != newTask.title) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'title',
          oldValue: oldTask.title,
          newValue: newTask.title,
        );
      }
      
      // Vérifier les changements de description
      if (oldTask.description != newTask.description) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'description',
          oldValue: oldTask.description,
          newValue: newTask.description,
        );
      }
      
      // Vérifier les changements de date d'échéance
      final oldDueDate = oldTask.dueDate?.toIso8601String();
      final newDueDate = newTask.dueDate?.toIso8601String();
      if (oldDueDate != newDueDate) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'due_date',
          oldValue: oldDueDate,
          newValue: newDueDate ?? '',
        );
      }
      
      // Vérifier les changements de phase
      if (oldTask.phaseId != newTask.phaseId) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'phase_id',
          oldValue: oldTask.phaseId,
          newValue: newTask.phaseId ?? '',
        );
      }
    } catch (e) {
      print('Erreur lors de l\'enregistrement des changements dans l\'historique: $e');
      // Ne pas relancer l'exception pour ne pas perturber la mise à jour de la tâche
    }
  }

  // Ajouter une entrée dans l'historique des tâches
  Future<void> _addTaskHistoryEntry({
    required String taskId,
    required String fieldName,
    String? oldValue,
    required String newValue,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        print('Utilisateur non authentifié, impossible d\'ajouter l\'entrée d\'historique');
        return;
      }
      
      await _client.from(_taskHistoryTable).insert({
        'task_id': taskId,
        'user_id': userId,
        'field_name': fieldName,
        'old_value': oldValue,
        'new_value': newValue,
      });
    } catch (e) {
      print('Erreur lors de l\'ajout de l\'entrée d\'historique: $e');
      // Ne pas relancer l'exception pour ne pas perturber la mise à jour de la tâche
    }
  }

  // Récupérer l'historique d'une tâche
  Future<List<TaskHistory>> getTaskHistory(String taskId) async {
    try {
      final response = await _client
          .from(_taskHistoryTable)
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: false);
      
      return response.map((json) => TaskHistory.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération de l\'historique de la tâche: $e');
      rethrow;
    }
  }

  // Supprimer une tâche
  Future<void> deleteTask(String taskId) async {
    try {
      await _client
          .from(_tasksTable)
          .delete()
          .eq('id', taskId);
    } catch (e) {
      print('Erreur lors de la suppression de la tâche: $e');
      rethrow;
    }
  }

  // Récupérer toutes les tâches
  Future<List<Task>> getAllTasks() async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      
      print('Réponse brute de getAllTasks: $response');
      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération de toutes les tâches: $e');
      rethrow;
    }
  }

  // Récupérer les tâches d'une phase
  Future<List<Task>> getTasksByPhase(String phaseId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .eq('phase_id', phaseId);

      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de la phase: $e');
      rethrow;
    }
  }

  // Récupérer toutes les phases
  Future<List<Phase>> getAllPhases() async {
    try {
      final response = await _client
          .from(_phasesTable)
          .select()
          .order('order_index', ascending: true);
      
      return response.map<Phase>((json) => Phase.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des phases: $e');
      rethrow;
    }
  }

  // Récupérer les phases d'un projet
  Future<List<Phase>> getPhasesByProject(String projectId) async {
    try {
      final response = await _client
          .from(_phasesTable)
          .select()
          .eq('project_id', projectId)
          .order('order_index', ascending: true);
      
      return response.map<Phase>((json) => Phase.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des phases du projet: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget alloué d'un projet
  Future<Project> updateProjectBudgetAllocation(String projectId, double amount) async {
    try {
      // Récupérer le projet actuel
      final project = await getProjectById(projectId);
      
      // Calculer le nouveau montant alloué
      final double newBudgetAllocated = (project.budgetAllocated ?? 0) + amount;
      
      // Mettre à jour le projet
      final updatedProject = project.copyWith(
        budgetAllocated: newBudgetAllocated,
        updatedAt: DateTime.now().toUtc(),
      );
      
      return await updateProject(updatedProject);
    } catch (e) {
      print('Erreur lors de la mise à jour du budget alloué: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget consommé d'un projet
  Future<Project> updateProjectBudgetConsumption(String projectId, double amount) async {
    try {
      // Récupérer le projet actuel
      final project = await getProjectById(projectId);
      
      // Calculer le nouveau montant consommé
      final double newBudgetConsumed = (project.budgetConsumed ?? 0) + amount;
      
      // Mettre à jour le projet
      final updatedProject = project.copyWith(
        budgetConsumed: newBudgetConsumed,
        updatedAt: DateTime.now().toUtc(),
      );
      
      return await updateProject(updatedProject);
    } catch (e) {
      print('Erreur lors de la mise à jour du budget consommé: $e');
      rethrow;
    }
  }

  // Obtenir les statistiques budgétaires d'un projet
  Future<Map<String, dynamic>> getProjectBudgetStatistics(String projectId) async {
    try {
      // Récupérer le projet
      final project = await getProjectById(projectId);
      
      // Récupérer les tâches du projet pour calculer le budget alloué et consommé par tâche
      final tasks = await getTasksByProject(projectId);
      
      // Calculer le budget alloué et consommé par les tâches
      double tasksBudgetAllocated = 0;
      double tasksBudgetConsumed = 0;
      
      for (var task in tasks) {
        tasksBudgetAllocated += task.budgetAllocated ?? 0;
        tasksBudgetConsumed += task.budgetConsumed ?? 0;
      }
      
      // Récupérer les phases du projet pour calculer le budget alloué et consommé par phase
      final phases = await _client
          .from('phases')
          .select()
          .eq('project_id', projectId)
          .order('order_index', ascending: true);
      
      double phasesBudgetAllocated = 0;
      double phasesBudgetConsumed = 0;
      
      for (var phase in phases) {
        phasesBudgetAllocated += (phase['budget_allocated'] ?? 0).toDouble();
        phasesBudgetConsumed += (phase['budget_consumed'] ?? 0).toDouble();
      }
      
      // Calculer le pourcentage d'utilisation
      double budgetUsagePercentage = 0;
      if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
        budgetUsagePercentage = ((project.budgetConsumed ?? 0) / project.budgetAllocated!) * 100;
      }
      
      return {
        'project_id': projectId,
        'project_name': project.name,
        'budget_allocated': project.budgetAllocated ?? 0,
        'budget_consumed': project.budgetConsumed ?? 0,
        'budget_remaining': (project.budgetAllocated ?? 0) - (project.budgetConsumed ?? 0),
        'budget_usage_percentage': budgetUsagePercentage,
        'tasks_budget_allocated': tasksBudgetAllocated,
        'tasks_budget_consumed': tasksBudgetConsumed,
        'phases_budget_allocated': phasesBudgetAllocated,
        'phases_budget_consumed': phasesBudgetConsumed,
        'is_budget_overrun': (project.budgetConsumed ?? 0) > (project.budgetAllocated ?? 0),
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques budgétaires: $e');
      rethrow;
    }
  }
}
