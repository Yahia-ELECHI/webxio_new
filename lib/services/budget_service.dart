import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../models/budget_transaction_model.dart';
import '../models/budget_allocation_model.dart';

class BudgetService {
  final _supabase = Supabase.instance.client;
  final _uuid = Uuid();

  // Récupérer tous les budgets créés par l'utilisateur actuel
  Future<List<Budget>> getAllBudgets() async {
    try {
      final response = await _supabase
          .from('budgets')
          .select()
          .order('start_date', ascending: false);

      return response.map<Budget>((json) => Budget.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des budgets: $e');
      rethrow;
    }
  }

  // Récupérer tous les budgets (alias de getAllBudgets pour maintenir la compatibilité)
  Future<List<Budget>> getBudgets() async {
    return getAllBudgets();
  }

  // Récupérer un budget par son ID
  Future<Budget> getBudgetById(String budgetId) async {
    try {
      final response = await _supabase
          .from('budgets')
          .select()
          .filter('id', 'eq', budgetId)
          .single();

      return Budget.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération du budget: $e');
      rethrow;
    }
  }

  // Créer un nouveau budget
  Future<Budget> createBudget(
    String name,
    String description,
    double initialAmount,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final budgetId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final budget = Budget(
        id: budgetId,
        name: name,
        description: description,
        initialAmount: initialAmount,
        currentAmount: initialAmount, // Initialement le montant actuel est égal au montant initial
        startDate: startDate,
        endDate: endDate,
        createdAt: now,
        createdBy: userId,
      );

      await _supabase.from('budgets').insert(budget.toJson());
      return budget;
    } catch (e) {
      print('Erreur lors de la création du budget: $e');
      rethrow;
    }
  }

  // Mettre à jour un budget
  Future<void> updateBudget(Budget budget) async {
    try {
      final updatedBudget = budget.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase
          .from('budgets')
          .update(updatedBudget.toJson())
          .filter('id', 'eq', budget.id);
    } catch (e) {
      print('Erreur lors de la mise à jour du budget: $e');
      rethrow;
    }
  }

  // Supprimer un budget
  Future<void> deleteBudget(String budgetId) async {
    try {
      await _supabase.from('budgets').delete().filter('id', 'eq', budgetId);
    } catch (e) {
      print('Erreur lors de la suppression du budget: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions d'un budget
  Future<List<BudgetTransaction>> getTransactionsByBudget(String budgetId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .filter('budget_id', 'eq', budgetId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions de l'utilisateur actuel
  Future<List<BudgetTransaction>> getAllTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .filter('created_by', 'eq', userId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par projet
  Future<List<BudgetTransaction>> getTransactionsByProject(String projectId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .filter('project_id', 'eq', projectId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour le projet: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par phase
  Future<List<BudgetTransaction>> getTransactionsByPhase(String phaseId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .filter('phase_id', 'eq', phaseId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la phase: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par tâche
  Future<List<BudgetTransaction>> getTransactionsByTask(String taskId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .filter('task_id', 'eq', taskId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la tâche: $e');
      rethrow;
    }
  }

  // Créer une nouvelle transaction
  Future<BudgetTransaction> createTransaction(
    String? budgetId,
    String? projectId,
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

      // Convertir la catégorie française en anglais pour la base de données
      String dbCategory;
      if (category == 'Entrée' || category == 'Dotation' || category == 'Virement' || 
          category == 'Remboursement' || category == 'Don') {
        dbCategory = 'income';
      } else {
        dbCategory = 'expense';
      }

      // Insertion directe en Map (similaire au TaskService)
      await _supabase.from('budget_transactions').insert({
        'id': transactionId,
        'budget_id': budgetId,
        'project_id': projectId,
        'phase_id': phaseId,
        'task_id': taskId,
        'amount': amount,
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
        'category': dbCategory,
        'subcategory': subcategory,
        'created_at': now.toIso8601String(),
        'created_by': userId,
      });

      // Créer un objet pour le retour
      final transaction = BudgetTransaction(
        id: transactionId,
        budgetId: budgetId,
        projectId: projectId,
        projectName: null, // On ne récupère plus les noms
        phaseId: phaseId,
        phaseName: null, // On ne récupère plus les noms
        taskId: taskId,
        taskName: null, // On ne récupère plus les noms
        amount: amount,
        description: description,
        transactionDate: transactionDate,
        category: dbCategory,
        subcategory: subcategory,
        createdAt: now,
        createdBy: userId,
      );

      return transaction;
    } catch (e) {
      print('Erreur lors de la création de la transaction: $e');
      rethrow;
    }
  }

  // Mettre à jour une transaction
  Future<void> updateTransaction(BudgetTransaction transaction) async {
    try {
      final updatedTransaction = transaction.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase
          .from('budget_transactions')
          .update(updatedTransaction.toJson())
          .filter('id', 'eq', transaction.id);
    } catch (e) {
      print('Erreur lors de la mise à jour de la transaction: $e');
      rethrow;
    }
  }

  // Supprimer une transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _supabase.from('budget_transactions').delete().filter('id', 'eq', transactionId);
    } catch (e) {
      print('Erreur lors de la suppression de la transaction: $e');
      rethrow;
    }
  }

  // Récupérer toutes les allocations budgétaires d'un budget
  Future<List<BudgetAllocation>> getAllocationsByBudget(String budgetId) async {
    try {
      final response = await _supabase
          .from('budget_allocations')
          .select()
          .filter('budget_id', 'eq', budgetId)
          .order('allocation_date', ascending: false);

      return response.map<BudgetAllocation>((json) => BudgetAllocation.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des allocations: $e');
      rethrow;
    }
  }

  // Récupérer toutes les allocations budgétaires d'un projet
  Future<List<BudgetAllocation>> getAllocationsByProject(String projectId) async {
    try {
      final response = await _supabase
          .from('budget_allocations')
          .select()
          .filter('project_id', 'eq', projectId)
          .order('allocation_date', ascending: false);

      return response.map<BudgetAllocation>((json) => BudgetAllocation.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des allocations: $e');
      rethrow;
    }
  }

  // Créer une nouvelle allocation budgétaire
  Future<BudgetAllocation> createBudgetAllocation(
    String budgetId,
    String projectId,
    double amount,
    DateTime allocationDate,
    String description,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final allocationId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final allocation = BudgetAllocation(
        id: allocationId,
        budgetId: budgetId,
        projectId: projectId,
        amount: amount,
        description: description,
        allocationDate: allocationDate,
        createdAt: now,
        createdBy: userId,
      );

      await _supabase.from('budget_allocations').insert(allocation.toJson());
      return allocation;
    } catch (e) {
      print('Erreur lors de la création de l\'allocation: $e');
      rethrow;
    }
  }

  // Mettre à jour une allocation budgétaire
  Future<void> updateAllocation(BudgetAllocation allocation) async {
    try {
      final updatedAllocation = allocation.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase
          .from('budget_allocations')
          .update(updatedAllocation.toJson())
          .filter('id', 'eq', allocation.id);
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'allocation: $e');
      rethrow;
    }
  }

  // Supprimer une allocation budgétaire
  Future<void> deleteAllocation(String allocationId) async {
    try {
      await _supabase.from('budget_allocations').delete().filter('id', 'eq', allocationId);
    } catch (e) {
      print('Erreur lors de la suppression de l\'allocation: $e');
      rethrow;
    }
  }

  // Allouer un budget à un projet
  Future<void> allocateBudgetToProject(String budgetId, String projectId, double amount, String description) async {
    try {
      // 1. Créer un enregistrement dans la table budget_allocations
      final allocationId = _uuid.v4();
      await _supabase.from('budget_allocations').insert({
        'id': allocationId,
        'budget_id': budgetId,
        'project_id': projectId,
        'amount': amount,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Créer une transaction pour le budget
      final transactionId = _uuid.v4();
      await _supabase.from('budget_transactions').insert({
        'id': transactionId,
        'budget_id': budgetId,
        'project_id': projectId,
        'amount': -amount, // Montant négatif car c'est une sortie du budget
        'description': 'Allocation au projet: $description',
        'transaction_date': DateTime.now().toIso8601String(),
        'category': 'Allocation',
        'subcategory': 'Projet',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Mettre à jour le budgetAllocated du projet
      final project = await _supabase
          .from('projects')
          .select('budget_allocated')
          .filter('id', 'eq', projectId)
          .single();
      
      double currentBudget = project['budget_allocated'] ?? 0.0;
      double newBudget = currentBudget + amount;
      
      await _supabase
          .from('projects')
          .update({'budget_allocated': newBudget})
          .filter('id', 'eq', projectId);

    } catch (e) {
      print('Erreur lors de l\'allocation du budget au projet: $e');
      rethrow;
    }
  }

  // Obtenir des statistiques sur les budgets
  Future<Map<String, dynamic>> getBudgetStatistics() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Récupérer tous les budgets
      final budgets = await getAllBudgets();
      
      // Récupérer toutes les transactions
      final transactions = await getAllTransactions();
      
      // Calculer le total des entrées et sorties
      double totalIncome = 0;
      double totalExpense = 0;
      
      for (var transaction in transactions) {
        if (transaction.amount > 0) {
          totalIncome += transaction.amount;
        } else {
          totalExpense += transaction.amount.abs();
        }
      }
      
      // Regrouper les transactions par catégorie
      Map<String, double> expensesByCategory = {};
      
      for (var transaction in transactions) {
        if (transaction.amount < 0) {
          if (expensesByCategory.containsKey(transaction.subcategory ?? transaction.category)) {
            expensesByCategory[transaction.subcategory ?? transaction.category] = 
                (expensesByCategory[transaction.subcategory ?? transaction.category] ?? 0) + transaction.amount.abs();
          } else {
            expensesByCategory[transaction.subcategory ?? transaction.category] = transaction.amount.abs();
          }
        }
      }
      
      return {
        'total_budgets': budgets.length,
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'net_balance': totalIncome - totalExpense,
        'expenses_by_category': expensesByCategory,
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques: $e');
      rethrow;
    }
  }

  // Récupérer les transactions récentes
  Future<List<BudgetTransaction>> getRecentTransactions(int limit) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .order('transaction_date', ascending: false)
          .limit(limit);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions récentes: $e');
      return [];
    }
  }
}
