import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project_transaction_model.dart';
import '../models/project_model.dart';
import 'project_service/project_service.dart';
import 'notification_service.dart';

class ProjectFinanceService {
  final _supabase = Supabase.instance.client;
  final _uuid = Uuid();
  final ProjectService _projectService = ProjectService();
  final NotificationService _notificationService = NotificationService();
  
  // Exposer le client Supabase pour permettre l'accès à l'utilisateur courant
  SupabaseClient get supabaseClient => _supabase;

  // Vérifier si l'utilisateur actuel est un administrateur d'une équipe
  Future<bool> isUserAdmin() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }
      
      // Vérifier si l'utilisateur est administrateur d'au moins une équipe
      final response = await _supabase
          .from('team_members')
          .select()
          .eq('user_id', userId)
          .eq('role', 'admin')
          .eq('status', 'active');
      
      return response.isNotEmpty; // Utilisateur est admin s'il a au moins une équipe où il est admin
    } catch (e) {
      print('Erreur lors de la vérification du statut d\'administrateur: $e');
      return false;
    }
  }

  // Récupérer toutes les transactions pour un projet spécifique
  Future<List<ProjectTransaction>> getProjectTransactions(String projectId) async {
    try {
      // Récupérer les informations du projet pour avoir le nom
      final project = await _projectService.getProjectById(projectId);
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('project_id', projectId)
          .order('transaction_date', ascending: false);

      final transactions = response.map<ProjectTransaction>((json) {
        // Ajouter le nom du projet aux données JSON
        json['project_name'] = project.name;
        return ProjectTransaction.fromJson(json);
      }).toList();

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour le projet: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions pour un projet spécifique
  Future<List<ProjectTransaction>> getProjectProjectTransactions(String projectId) async {
    try {
      // Récupérer les informations du projet pour avoir le nom
      final project = await _projectService.getProjectById(projectId);
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('project_id', projectId)
          .order('transaction_date', ascending: false);

      final transactions = response.map<ProjectTransaction>((json) {
        // Ajouter le nom du projet aux données JSON
        json['project_name'] = project.name;
        return ProjectTransaction.fromJson(json);
      }).toList();

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour le projet: $e');
      return [];
    }
  }

  // Récupérer toutes les transactions de l'utilisateur actuel
  Future<List<ProjectTransaction>> getAllTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('created_by', userId)
          .order('transaction_date', ascending: false);

      final List<ProjectTransaction> transactions = [];
      
      // Récupérer les noms des projets pour chaque transaction
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      rethrow;
    }
  }

  // Récupérer les transactions récentes (pour le tableau de bord)
  Future<List<ProjectTransaction>> getRecentTransactions(int limit) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('created_by', userId)
          .order('transaction_date', ascending: false)
          .limit(limit);

      final List<ProjectTransaction> transactions = [];
      
      // Récupérer les noms des projets pour chaque transaction
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions récentes: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par phase
  Future<List<ProjectTransaction>> getTransactionsByPhase(String phaseId) async {
    try {
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('phase_id', phaseId)
          .order('transaction_date', ascending: false);

      // Récupérer les projets et phases associés pour enrichir les données
      final List<ProjectTransaction> transactions = [];
      
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la phase: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par tâche
  Future<List<ProjectTransaction>> getTransactionsByTask(String taskId) async {
    try {
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('task_id', taskId)
          .order('transaction_date', ascending: false);

      // Récupérer les projets, phases et tâches associés pour enrichir les données
      final List<ProjectTransaction> transactions = [];
      
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la tâche: $e');
      rethrow;
    }
  }

  // Récupérer les transactions d'une équipe
  Future<List<ProjectTransaction>> getTeamTransactions(String teamId) async {
    try {
      // Récupérer les projets associés à l'équipe
      final projectsResponse = await _supabase
          .from('team_projects')
          .select('project_id')
          .eq('team_id', teamId);
      
      final projectIds = projectsResponse.map<String>((json) => json['project_id'] as String).toList();
      
      if (projectIds.isEmpty) {
        return [];
      }
      
      // Récupérer les transactions liées à ces projets individuellement
      List<ProjectTransaction> transactions = [];
      for (final projectId in projectIds) {
        final project = await _projectService.getProjectById(projectId);
        
        final response = await _supabase
            .from('budget_transactions') // Utilisation de la table existante
            .select()
            .eq('project_id', projectId)
            .order('transaction_date', ascending: false);
            
        for (final json in response) {
          json['project_name'] = project.name;
          transactions.add(ProjectTransaction.fromJson(json));
        }
      }
      
      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions de l\'équipe: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions de projet
  Future<List<ProjectTransaction>> getAllProjectTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .order('transaction_date', ascending: false);

      final List<ProjectTransaction> transactions = [];
      
      // Récupérer les noms des projets pour chaque transaction
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération de toutes les transactions: $e');
      return [];
    }
  }

  // Créer une nouvelle transaction de projet
  Future<ProjectTransaction> createTransaction(
    String projectId,
    String? phaseId,
    String? taskId,
    double amount,
    String description,
    DateTime transactionDate,
    String category,
    String? subcategory,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final transactionId = _uuid.v4();
      final now = DateTime.now().toUtc();
      
      // Récupérer les noms des entités associées
      String projectName = 'Projet non spécifié';
      String? phaseName;
      String? taskName;
      
      try {
        final project = await _projectService.getProjectById(projectId);
        projectName = project.name;
        
        // Calculer le nouveau solde du projet
        List<ProjectTransaction> projectTransactions = await getProjectProjectTransactions(projectId);
        
        double projectIncome = 0.0;
        double projectExpenses = 0.0;
        
        for (final transaction in projectTransactions) {
          if (transaction.isIncome) {
            projectIncome += transaction.absoluteAmount;
          } else {
            projectExpenses += transaction.absoluteAmount;
          }
        }
        
        // Ajouter la transaction actuelle
        if (category == 'income') {
          projectIncome += amount;
        } else {
          projectExpenses += amount.abs();
        }
        
        // Calculer le solde
        double projectBalance = projectIncome - projectExpenses;
        
        // Créer une notification si le solde devient négatif
        if (projectBalance < 0) {
          _notificationService.createProjectBalanceAlertNotification(
            project.id,
            project.name,
            projectBalance,
            project.createdBy,
          );
        }
      } catch (e) {
        print('Erreur lors de la récupération du projet: $e');
      }
      
      if (phaseId != null) {
        try {
          final phaseResponse = await _supabase
              .from('phases')
              .select()
              .eq('id', phaseId)
              .single();
          
          phaseName = phaseResponse['name'];
        } catch (e) {
          print('Erreur lors de la récupération de la phase: $e');
        }
      }
      
      if (taskId != null) {
        try {
          final taskResponse = await _supabase
              .from('tasks')
              .select()
              .eq('id', taskId)
              .single();
          
          taskName = taskResponse['name'];
        } catch (e) {
          print('Erreur lors de la récupération de la tâche: $e');
        }
      }

      final transaction = ProjectTransaction(
        id: transactionId,
        projectId: projectId,
        projectName: projectName,
        phaseId: phaseId,
        phaseName: phaseName,
        taskId: taskId,
        taskName: taskName,
        amount: category == 'expense' ? -amount.abs() : amount.abs(), // Montant négatif pour les dépenses
        description: description,
        transactionDate: transactionDate,
        category: category,
        subcategory: subcategory,
        createdAt: now,
        createdBy: userId,
      );

      // Convertir en format compatible avec la table existante
      final jsonData = transaction.toJson();
      
      // Adapter les noms de champs si nécessaire
      final dbData = {
        'id': jsonData['id'],
        'project_id': jsonData['project_id'],
        'phase_id': jsonData['phase_id'],
        'task_id': jsonData['task_id'],
        'amount': jsonData['amount'],
        'description': jsonData['description'],
        'transaction_date': jsonData['transaction_date'],
        'category': jsonData['category'],
        'subcategory': jsonData['subcategory'],
        'created_at': jsonData['created_at'],
        'updated_at': jsonData['updated_at'],
        'created_by': jsonData['created_by'],
      };

      await _supabase.from('budget_transactions').insert(dbData);

      return transaction;
    } catch (e) {
      print('Erreur lors de la création de la transaction: $e');
      rethrow;
    }
  }

  // Mettre à jour une transaction
  Future<void> updateTransaction(ProjectTransaction transaction) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now().toUtc();
      
      // Recalculer le solde du projet après la mise à jour
      List<ProjectTransaction> projectTransactions = await getProjectProjectTransactions(transaction.projectId);
      
      double projectIncome = 0.0;
      double projectExpenses = 0.0;
      
      // Exclure la transaction actuelle car elle sera remplacée
      for (final tx in projectTransactions) {
        if (tx.id != transaction.id) {
          if (tx.isIncome) {
            projectIncome += tx.absoluteAmount;
          } else {
            projectExpenses += tx.absoluteAmount;
          }
        }
      }
      
      // Ajouter la transaction mise à jour
      if (transaction.isIncome) {
        projectIncome += transaction.absoluteAmount;
      } else {
        projectExpenses += transaction.absoluteAmount;
      }
      
      // Calculer le nouveau solde
      double projectBalance = projectIncome - projectExpenses;
      
      // Si le solde devient négatif, envoyer une alerte
      if (projectBalance < 0) {
        try {
          final project = await _projectService.getProjectById(transaction.projectId);
          _notificationService.createProjectBalanceAlertNotification(
            project.id,
            project.name,
            projectBalance,
            project.createdBy,
          );
        } catch (e) {
          print('Erreur lors de la notification de solde négatif: $e');
        }
      }
      
      // Adapter pour la table existante
      final updatedData = {
        'project_id': transaction.projectId,
        'phase_id': transaction.phaseId,
        'task_id': transaction.taskId,
        'amount': transaction.amount,
        'description': transaction.description,
        'transaction_date': transaction.transactionDate.toIso8601String(),
        'category': transaction.category,
        'subcategory': transaction.subcategory,
        'updated_at': now.toIso8601String(),
      };

      await _supabase
          .from('budget_transactions')
          .update(updatedData)
          .eq('id', transaction.id);
    } catch (e) {
      print('Erreur lors de la mise à jour de la transaction: $e');
      rethrow;
    }
  }

  // Supprimer une transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      // Récupérer la transaction avant de la supprimer pour mettre à jour le projet
      final transactionResponse = await _supabase
          .from('budget_transactions')
          .select()
          .eq('id', transactionId)
          .single();
      
      final projectId = transactionResponse['project_id'] as String?;
      final amount = transactionResponse['amount'] as double;
      final category = transactionResponse['category'] as String;
      
      // Calculer l'impact sur le solde du projet
      if (projectId != null) {
        try {
          // Recalculer le solde après la suppression de cette transaction
          List<ProjectTransaction> projectTransactions = await getProjectProjectTransactions(projectId);
          
          double projectIncome = 0.0;
          double projectExpenses = 0.0;
          
          for (final transaction in projectTransactions) {
            // Exclure la transaction en cours de suppression
            if (transaction.id != transactionId) {
              if (transaction.isIncome) {
                projectIncome += transaction.absoluteAmount;
              } else {
                projectExpenses += transaction.absoluteAmount;
              }
            }
          }
          
          // Calculer le nouveau solde
          double projectBalance = projectIncome - projectExpenses;
          
          // Si le solde devient négatif après la suppression, envoyer une alerte
          if (projectBalance < 0) {
            final project = await _projectService.getProjectById(projectId);
            _notificationService.createProjectBalanceAlertNotification(
              project.id,
              project.name,
              projectBalance,
              project.createdBy,
            );
          }
        } catch (e) {
          print('Erreur lors de la mise à jour du solde du projet: $e');
        }
      }

      await _supabase
          .from('budget_transactions')
          .delete()
          .eq('id', transactionId);
    } catch (e) {
      print('Erreur lors de la suppression de la transaction: $e');
      rethrow;
    }
  }

  // Récupérer une transaction par son ID
  Future<ProjectTransaction> getTransactionById(String transactionId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('id', transactionId)
          .single();

      String projectName = 'Projet non spécifié';
      if (response['project_id'] != null) {
        try {
          final project = await _projectService.getProjectById(response['project_id']);
          projectName = project.name;
        } catch (e) {
          print('Erreur lors de la récupération du projet: $e');
        }
      }
      
      response['project_name'] = projectName;
      
      return ProjectTransaction.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération de la transaction: $e');
      rethrow;
    }
  }
  
  // Calculer le solde actuel d'un projet
  Future<double> calculateProjectBalance(String projectId) async {
    try {
      final transactions = await getProjectTransactions(projectId);
      double balance = 0;
      
      for (final transaction in transactions) {
        balance += transaction.amount;
      }
      
      return balance;
    } catch (e) {
      print('Erreur lors du calcul du solde du projet: $e');
      rethrow;
    }
  }
  
  // Obtenir des statistiques financières pour un projet
  Future<Map<String, dynamic>> getProjectFinanceStatistics(String projectId) async {
    try {
      final transactions = await getProjectTransactions(projectId);
      
      double totalIncome = 0;
      double totalExpense = 0;
      Map<String, double> expensesByCategory = {};
      Map<String, double> incomesByCategory = {};
      
      for (final transaction in transactions) {
        if (transaction.isIncome) {
          totalIncome += transaction.amount;
          
          final category = transaction.subcategory ?? transaction.category;
          incomesByCategory[category] = (incomesByCategory[category] ?? 0) + transaction.amount;
        } else {
          totalExpense += transaction.amount.abs();
          
          final category = transaction.subcategory ?? transaction.category;
          expensesByCategory[category] = (expensesByCategory[category] ?? 0) + transaction.amount.abs();
        }
      }
      
      return {
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'balance': totalIncome - totalExpense,
        'expenses_by_category': expensesByCategory,
        'incomes_by_category': incomesByCategory,
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques financières: $e');
      rethrow;
    }
  }
}
