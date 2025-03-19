import 'package:flutter/material.dart';

class ProjectTransaction {
  final String id;
  final String projectId;
  final String projectName;  
  final String? phaseId;
  final String? phaseName;    
  final String? taskId;
  final String? taskName;     
  final double amount;
  final String description;
  final DateTime transactionDate;
  final String category;
  final String? subcategory;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  ProjectTransaction({
    required this.id,
    required this.projectId,
    required this.projectName,
    this.phaseId,
    this.phaseName,
    this.taskId,
    this.taskName,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.category,
    this.subcategory,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Convertir un objet JSON en objet ProjectTransaction
  factory ProjectTransaction.fromJson(Map<String, dynamic> json) {
    return ProjectTransaction(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      projectName: json['project_name'] as String? ?? 'Projet non spécifié',
      phaseId: json['phase_id'] as String?,
      phaseName: json['phase_name'] as String?,
      taskId: json['task_id'] as String?,
      taskName: json['task_name'] as String?,
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      description: json['description'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
    );
  }

  // Convertir un objet ProjectTransaction en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'project_name': projectName,
      'phase_id': phaseId,
      'phase_name': phaseName,
      'task_id': taskId,
      'task_name': taskName,
      'amount': amount,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'category': category,
      'subcategory': subcategory,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Créer une copie de l'objet ProjectTransaction avec des valeurs modifiées
  ProjectTransaction copyWith({
    String? id,
    String? projectId,
    String? projectName,
    String? phaseId,
    String? phaseName,
    String? taskId,
    String? taskName,
    double? amount,
    String? description,
    DateTime? transactionDate,
    String? category,
    String? subcategory,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ProjectTransaction(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      phaseId: phaseId ?? this.phaseId,
      phaseName: phaseName ?? this.phaseName,
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Vérifier si c'est une entrée d'argent
  bool get isIncome {
    return category == 'income';
  }

  // Vérifier si c'est une sortie d'argent
  bool get isExpense {
    return category == 'expense';
  }

  // Obtenir la valeur absolue du montant
  double get absoluteAmount {
    return amount.abs();
  }

  // Obtenir une couleur en fonction du type de transaction
  Color getAmountColor() {
    return isIncome ? Colors.green : Colors.red;
  }

  // Obtenir une icône en fonction du type de transaction
  IconData getAmountIcon() {
    return isIncome ? Icons.arrow_upward : Icons.arrow_downward;
  }
  
  // Crée une ProjectTransaction à partir d'une BudgetTransaction
  static ProjectTransaction fromBudgetTransaction(Map<String, dynamic> json) {
    return ProjectTransaction(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      projectName: json['project_name'] as String? ?? 'Projet non spécifié',
      phaseId: json['phase_id'] as String?,
      phaseName: json['phase_name'] as String?,
      taskId: json['task_id'] as String?,
      taskName: json['task_name'] as String?,
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      description: json['description'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
    );
  }
}

// Énumération pour les catégories de transactions
enum TransactionCategory {
  income,
  expense;

  String get displayName {
    switch (this) {
      case TransactionCategory.income:
        return 'Entrée';
      case TransactionCategory.expense:
        return 'Sortie';
    }
  }

  String toValue() {
    switch (this) {
      case TransactionCategory.income:
        return 'income';
      case TransactionCategory.expense:
        return 'expense';
    }
  }

  static TransactionCategory fromValue(String value) {
    switch (value) {
      case 'income':
        return TransactionCategory.income;
      case 'expense':
        return TransactionCategory.expense;
      default:
        return TransactionCategory.expense;
    }
  }

  Color get color {
    switch (this) {
      case TransactionCategory.income:
        return Colors.green;
      case TransactionCategory.expense:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionCategory.income:
        return Icons.arrow_upward;
      case TransactionCategory.expense:
        return Icons.arrow_downward;
    }
  }
}
