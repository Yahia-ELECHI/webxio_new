import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/budget_model.dart';
import '../../models/budget_transaction_model.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../services/budget_service.dart';
import '../../services/project_service/project_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../projects/project_detail_screen.dart'; // Importer l'écran de détail du projet depuis le bon chemin
import 'budget_form_screen.dart';
import 'transaction_form_screen.dart';
import 'transaction_list_screen.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> with SingleTickerProviderStateMixin {
  final BudgetService _budgetService = BudgetService();
  final ProjectService _projectService = ProjectService();
  final PhaseService _phaseService = PhaseService();
  
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Budget> _budgets = [];
  List<BudgetTransaction> _recentTransactions = [];
  List<Project> _projects = [];
  List<Project> _projectsWithBudgetAlert = [];
  
  // États pour les graphiques interactifs
  int? _touchedExpenseIndex;
  int? _touchedIncomeIndex;
  
  // Filtres
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Statistiques financières
  double _totalBudget = 0;
  double _totalSpent = 0;
  double _totalRemaining = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Charger les budgets
      final budgets = await _budgetService.getAllBudgets();
      
      // Charger les projets
      final projects = await _projectService.getAllProjects();
      
      // Charger les transactions récentes (les 20 dernières)
      final transactions = await _budgetService.getAllTransactions();
      final recentTransactions = transactions.take(20).toList();
      
      // Trouver les projets avec dépassement de budget (alerte)
      final projectsWithAlert = projects.where((project) {
        // Calculer les entrées et sorties d'argent pour ce projet
        double projectIncome = 0.0;
        double projectExpenses = 0.0;
        
        for (final transaction in transactions) {
          if (transaction.projectId == project.id) {
            if (transaction.amount > 0) {
              projectIncome += transaction.amount;
            } else {
              projectExpenses += transaction.amount.abs();
            }
          }
        }
        
        // Recalculer le budget total en incluant les entrées
        final totalBudget = (project.budgetAllocated ?? 0) + projectIncome;
        
        // Dépassement si dépenses > budget total (incluant entrées supplémentaires)
        return projectExpenses > totalBudget;
      }).toList();
      
      // Calculer les statistiques financières
      // Méthode 1: Calcul basé sur les current_amount des budgets et les transactions
      final totalInitialBudget = budgets.fold(0.0, (sum, budget) => sum + budget.initialAmount);
      final totalIncomeTransactions = transactions.where((t) => t.amount > 0).fold(0.0, (sum, t) => sum + t.amount);
      final totalBudget = totalInitialBudget + totalIncomeTransactions;
      final totalSpent = transactions.where((t) => t.amount < 0).fold(0.0, (sum, t) => sum + t.amount.abs());
      final totalRemaining = totalBudget - totalSpent;
      
      // Vérification du calcul - si les soldes actuels sont corrects, ils devraient être égaux à totalRemaining
      final totalCurrentAmount = budgets.fold(0.0, (sum, budget) => sum + budget.currentAmount);
      print('Vérification totalRemaining: $totalRemaining vs totalCurrentAmount: $totalCurrentAmount');
      
      setState(() {
        _budgets = budgets;
        _projects = projects;
        _recentTransactions = recentTransactions;
        _projectsWithBudgetAlert = projectsWithAlert;
        _totalBudget = totalBudget;
        _totalSpent = totalSpent;
        _totalRemaining = totalRemaining;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des données: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord financier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.0,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14.0,
          ),
          tabs: const [
            Tab(text: 'Vue d\'ensemble'),
            Tab(text: 'Projets'),
            Tab(text: 'Alertes'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BudgetFormScreen(),
            ),
          );
          
          if (result == true) {
            _loadData();
          }
        },
        tooltip: 'Ajouter un budget',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildProjectsTab(),
                _buildAlertsTab(),
              ],
            ),
    );
  }
  
  Widget _buildOverviewTab() {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartes de résumé financier
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Budget total',
                    currencyFormat.format(_totalBudget),
                    Icons.account_balance,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Dépenses',
                    currencyFormat.format(_totalSpent),
                    Icons.money_off,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Restant',
                    currencyFormat.format(_totalRemaining),
                    Icons.monetization_on,
                    _totalRemaining >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Graphique de répartition des dépenses
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Répartition des dépenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildExpensesChart(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Graphique de répartition des entrées
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Répartition des entrées',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildIncomesChart(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Transactions récentes
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transactions récentes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TransactionListScreen(),
                              ),
                            );
                          },
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _recentTransactions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Aucune transaction récente')),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentTransactions.length > 5 ? 5 : _recentTransactions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _buildTransactionItem(_recentTransactions[index]);
                          },
                        ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransactionFormScreen(),
                          ),
                        ).then((value) {
                          if (value != null) {
                            _loadData();
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle transaction'),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Budgets actuels
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Budgets',
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
                                builder: (context) => const BudgetFormScreen(),
                              ),
                            );
                            
                            if (result == true) {
                              _loadData();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _budgets.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Aucun budget défini')),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _budgets.length > 3 ? 3 : _budgets.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _buildBudgetItem(_budgets[index]);
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesChart() {
    // Grouper les transactions par catégorie et sous-catégorie
    final Map<String, double> expensesByCategory = {};
    
    // Définition des couleurs
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    
    for (final transaction in _recentTransactions.where((t) => t.amount < 0)) {
      // Utiliser la sous-catégorie si disponible, sinon la catégorie
      String displayCategory;
      if (transaction.subcategory != null && transaction.subcategory!.isNotEmpty) {
        displayCategory = transaction.subcategory!;
      } else {
        // Traduire la catégorie anglaise en français pour l'affichage
        if (transaction.category == 'expense') {
          displayCategory = 'Dépense';
        } else if (transaction.category == 'income') {
          displayCategory = 'Entrée';
        } else {
          displayCategory = transaction.category;
        }
      }
      
      final amount = transaction.amount.abs();
      
      if (expensesByCategory.containsKey(displayCategory)) {
        expensesByCategory[displayCategory] = expensesByCategory[displayCategory]! + amount;
      } else {
        expensesByCategory[displayCategory] = amount;
      }
    }
    
    // Si aucune dépense, afficher un message
    if (expensesByCategory.isEmpty) {
      return const Center(
        child: Text('Aucune dépense pour la période sélectionnée'),
      );
    }
    
    // Convertir en données pour le graphique
    final List<PieChartSectionData> sections = [];
    
    int colorIndex = 0;
    List<String> categories = expensesByCategory.keys.toList();
    expensesByCategory.forEach((category, amount) {
      final percentage = (amount / _totalSpent) * 100;
      final isTouched = colorIndex == _touchedExpenseIndex;
      final double radius = isTouched ? 55 : 45;
      final double fontSize = isTouched ? 16.0 : 13.0;
      final double opacity = isTouched ? 1.0 : 0.8;
      
      sections.add(
        PieChartSectionData(
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          color: colors[colorIndex % colors.length].withOpacity(opacity),
          radius: radius,
          titleStyle: TextStyle(
            color: colors[colorIndex % colors.length],
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            shadows: [
              Shadow(
                color: Colors.white,
                blurRadius: 3,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          badgeWidget: null,
          titlePositionPercentageOffset: 1.8,
          showTitle: true,
        ),
      );
      
      colorIndex++;
    });
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedExpenseIndex = null;
                      return;
                    }
                    _touchedExpenseIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              centerSpaceColor: Colors.grey[100],
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: expensesByCategory.entries.map((entry) {
              final index = categories.indexOf(entry.key);
              final color = colors[index % colors.length];
              final isTouched = index == _touchedExpenseIndex;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _touchedExpenseIndex = _touchedExpenseIndex == index ? null : index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(isTouched ? 8.0 : 4.0),
                  decoration: BoxDecoration(
                    color: isTouched ? color.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isTouched ? 16 : 12,
                        height: isTouched ? 16 : 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: isTouched
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key} (${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(entry.value)})',
                        style: TextStyle(
                          fontSize: isTouched ? 14 : 13,
                          fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomesChart() {
    // Grouper les transactions par catégorie et sous-catégorie
    final Map<String, double> incomesByCategory = {};
    
    // Ajouter le budget initial comme une catégorie
    double totalInitial = _budgets.fold(0.0, (sum, budget) => sum + budget.initialAmount);
    if (totalInitial > 0) {
      incomesByCategory['Budget initial'] = totalInitial;
    }
    
    // Définition des couleurs
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.blueGrey,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    
    for (final transaction in _recentTransactions.where((t) => t.amount > 0)) {
      // Utiliser la sous-catégorie si disponible, sinon la catégorie
      String displayCategory;
      if (transaction.subcategory != null && transaction.subcategory!.isNotEmpty) {
        displayCategory = transaction.subcategory!;
      } else {
        // Traduire la catégorie anglaise en français pour l'affichage
        if (transaction.category == 'expense') {
          displayCategory = 'Dépense';
        } else if (transaction.category == 'income') {
          displayCategory = 'Entrée';
        } else {
          displayCategory = transaction.category;
        }
      }
      
      final amount = transaction.amount;
      
      if (incomesByCategory.containsKey(displayCategory)) {
        incomesByCategory[displayCategory] = incomesByCategory[displayCategory]! + amount;
      } else {
        incomesByCategory[displayCategory] = amount;
      }
    }
    
    // Si aucune entrée, afficher un message
    if (incomesByCategory.isEmpty) {
      return const Center(
        child: Text('Aucune entrée pour la période sélectionnée'),
      );
    }
    
    // Convertir en données pour le graphique
    final List<PieChartSectionData> sections = [];
    
    int colorIndex = 0;
    List<String> categories = incomesByCategory.keys.toList();
    incomesByCategory.forEach((category, amount) {
      final percentage = (amount / _totalBudget) * 100;
      final isTouched = colorIndex == _touchedIncomeIndex;
      final double radius = isTouched ? 55 : 45;
      final double fontSize = isTouched ? 16.0 : 13.0;
      final double opacity = isTouched ? 1.0 : 0.8;
      
      sections.add(
        PieChartSectionData(
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          color: colors[colorIndex % colors.length].withOpacity(opacity),
          radius: radius,
          titleStyle: TextStyle(
            color: colors[colorIndex % colors.length],
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            shadows: [
              Shadow(
                color: Colors.white,
                blurRadius: 3,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          badgeWidget: null,
          titlePositionPercentageOffset: 1.8,
          showTitle: true,
        ),
      );
      
      colorIndex++;
    });
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIncomeIndex = null;
                      return;
                    }
                    _touchedIncomeIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              centerSpaceColor: Colors.grey[100],
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: incomesByCategory.entries.map((entry) {
              final index = categories.indexOf(entry.key);
              final color = colors[index % colors.length];
              final isTouched = index == _touchedIncomeIndex;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _touchedIncomeIndex = _touchedIncomeIndex == index ? null : index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(isTouched ? 8.0 : 4.0),
                  decoration: BoxDecoration(
                    color: isTouched ? color.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isTouched ? 16 : 12,
                        height: isTouched ? 16 : 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: isTouched
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key} (${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(entry.value)})',
                        style: TextStyle(
                          fontSize: isTouched ? 14 : 13,
                          fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(BudgetTransaction transaction) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final bool isIncome = transaction.amount > 0;
    final color = isIncome ? Colors.green : Colors.red;
    
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(
          isIncome ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: color,
        ),
      ),
      title: Text(
        transaction.description,
        style: const TextStyle(fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('dd/MM/yyyy').format(transaction.transactionDate),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Text(
        currencyFormat.format(transaction.amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionFormScreen(
              transaction: transaction,
            ),
          ),
        ).then((value) {
          if (value != null) {
            _loadData();
          }
        });
      },
    );
  }

  Widget _buildBudgetItem(Budget budget) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Calculer le montant des entrées d'argent sur ce budget
    final income = _recentTransactions
        .where((t) => t.budgetId == budget.id && t.amount > 0)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    // Calculer le montant consommé sur ce budget
    final consumed = _recentTransactions
        .where((t) => t.budgetId == budget.id && t.amount < 0)
        .fold(0.0, (sum, t) => sum + t.amount.abs());
    
    // Budget total = initial + entrées
    final totalBudget = budget.initialAmount + income;
    
    // Calculer le pourcentage d'utilisation
    final percentage = totalBudget > 0 
        ? (consumed / totalBudget) * 100 
        : 0.0;
    
    // Limiter le pourcentage à 100 pour l'affichage
    final displayPercentage = percentage > 100 ? 100.0 : percentage;
    
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              budget.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 8),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetFormScreen(budget: budget),
                ),
              );
              
              if (result == true) {
                _loadData();
              }
            },
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: displayPercentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 80 
                  ? (percentage > 100 ? Colors.red : Colors.orange)
                  : Colors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currencyFormat.format(consumed)} sur ${currencyFormat.format(totalBudget)} (${percentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 12,
              color: percentage > 100 ? Colors.red : Colors.grey[600],
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionListScreen(budgetId: budget.id),
          ),
        );
      },
    );
  }

  Widget _buildProjectsTab() {
    if (_projects.isEmpty) {
      return const Center(
        child: Text('Aucun projet trouvé'),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          return _buildProjectBudgetCard(_projects[index]);
        },
      ),
    );
  }
  
  Widget _buildProjectBudgetCard(Project project) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Calculer les entrées et sorties d'argent pour ce projet
    double projectIncome = 0.0;
    double projectExpenses = 0.0;
    for (final transaction in _recentTransactions) {
      if (transaction.projectId == project.id) {
        if (transaction.amount > 0) {
          projectIncome += transaction.amount;
        } else {
          projectExpenses += transaction.amount.abs();
        }
      }
    }
    
    // Recalculer le budget total en incluant les entrées
    final totalBudget = (project.budgetAllocated ?? 0) + projectIncome;
    
    // Calculer le montant restant (budget total - dépenses)
    final remainingBudget = totalBudget - projectExpenses;
    
    // Calculer le pourcentage d'utilisation
    final percentage = totalBudget > 0 
        ? (projectExpenses / totalBudget) * 100 
        : 0.0;
    
    // Déterminer la couleur en fonction du pourcentage
    final Color statusColor;
    if (percentage > 100) {
      statusColor = Colors.red;
    } else if (percentage > 80) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: percentage > 100 
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (percentage > 100)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Dépassement',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percentage > 100 ? 1.0 : percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget alloué: ${currencyFormat.format(totalBudget)}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dépenses: ${currencyFormat.format(projectExpenses)}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Restant: ${currencyFormat.format(remainingBudget)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remainingBudget < 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Transactions'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionListScreen(projectId: project.id),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Transaction'),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionFormScreen(
                          projectId: project.id,
                        ),
                      ),
                    );
                    
                    if (result != null) {
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAlertsTab() {
    if (_projectsWithBudgetAlert.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune alerte de dépassement de budget',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tous les projets sont dans les limites budgétaires',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projectsWithBudgetAlert.length,
        itemBuilder: (context, index) {
          final project = _projectsWithBudgetAlert[index];
          return _buildBudgetAlertCard(project);
        },
      ),
    );
  }
  
  Widget _buildBudgetAlertCard(Project project) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Calculer les entrées et sorties d'argent pour ce projet
    double projectIncome = 0.0;
    double projectExpenses = 0.0;
    for (final transaction in _recentTransactions) {
      if (transaction.projectId == project.id) {
        if (transaction.amount > 0) {
          projectIncome += transaction.amount;
        } else {
          projectExpenses += transaction.amount.abs();
        }
      }
    }
    
    // Recalculer le budget total en incluant les entrées
    final totalBudget = (project.budgetAllocated ?? 0) + projectIncome;
    
    // Calculer le pourcentage d'utilisation
    final percentage = totalBudget > 0 
        ? (projectExpenses / totalBudget) * 100 
        : 0.0;
    
    // Calculer le montant du dépassement
    final overBudgetAmount = projectExpenses - totalBudget > 0 ? projectExpenses - totalBudget : 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.red, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alerte de dépassement: ${project.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dépassement: ${currencyFormat.format(overBudgetAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Budget initial: ${currencyFormat.format(project.budgetAllocated ?? 0)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Entrées supplémentaires: ${currencyFormat.format(projectIncome)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dépenses actuelles: ${currencyFormat.format(projectExpenses)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pourcentage utilisé: ${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Actions recommandées:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text('• Réviser le budget alloué au projet'),
            const Text('• Vérifier les dépenses récentes'),
            const Text('• Discuter des ajustements avec l\'équipe'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Voir les transactions'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionListScreen(projectId: project.id),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Détails du projet'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailScreen(projectId: project.id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
