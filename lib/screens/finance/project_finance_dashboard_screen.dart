import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import 'dart:math';
import '../dashboard/widgets/modern_project_selector.dart';
import '../../models/project_transaction_model.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../models/team_model.dart';
import '../../services/project_finance_service.dart';
import '../../services/project_service/project_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../projects/project_detail_screen.dart';
import '../budget/transaction_form_screen.dart';

// Classe de données pour les graphiques circulaires
class ChartData {
  final String category;
  final double amount;
  final Color color;
  final String percentText;
  final String amountText;

  ChartData(this.category, this.amount, this.color, {
    required this.percentText,
    required this.amountText
  });
}

class ProjectFinanceDashboardScreen extends StatefulWidget {
  const ProjectFinanceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ProjectFinanceDashboardScreen> createState() => _ProjectFinanceDashboardScreenState();
}

class _ProjectFinanceDashboardScreenState extends State<ProjectFinanceDashboardScreen> with SingleTickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();
  final PhaseService _phaseService = PhaseService();
  final TeamService _teamService = TeamService();
  final ProjectFinanceService _projectFinanceService = ProjectFinanceService();
  final NotificationService _notificationService = NotificationService();
  
  late TabController _tabController;
  
  bool _isLoading = true;
  List<ProjectTransaction> _recentTransactions = [];
  List<ProjectTransaction> _projectTransactions = [];
  List<Project> _projects = [];
  List<Project> _projectsWithBalanceAlert = [];
  
  // États pour les équipes et visualisation des finances d'équipe
  bool _isAdmin = false;
  List<Team> _adminTeams = [];
  
  // Sélection par projet
  String? _selectedProjectId;
  bool _showAllProjects = true; // Afficher tous les projets par défaut
  
  // Obtenir le nom du projet sélectionné
  String get _selectedProjectName {
    if (_selectedProjectId == null || _projects.isEmpty) {
      return "";
    }
    
    final project = _projects.firstWhere(
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
  
  // Filtres
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Statistiques financières
  double _totalRevenues = 0;
  double _totalExpenses = 0;
  double _totalBalance = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final userId = _projectFinanceService.supabaseClient.auth.currentUser!.id;
      
      // Vérifier si l'utilisateur est administrateur d'une équipe
      final adminTeams = await _teamService.getUserAdminTeams(userId);
      final isAdmin = adminTeams.isNotEmpty;
      
      // Mise à jour des équipes admin de l'utilisateur
      setState(() {
        _adminTeams = adminTeams;
        _isAdmin = isAdmin;
      });
      
      // Charger les transactions selon le contexte (projet spécifique ou tous les projets)
      List<ProjectTransaction> projectTransactions;
      
      if (_selectedProjectId != null) {
        // Charger les transactions du projet sélectionné
        projectTransactions = await _projectFinanceService.getProjectProjectTransactions(_selectedProjectId!);
      } else {
        // Charger toutes les transactions auxquelles l'utilisateur a accès
        projectTransactions = await _projectFinanceService.getAllProjectTransactions();
      }
      
      // Extraire les transactions récentes (les 20 dernières)
      final recentTransactions = projectTransactions.take(20).toList();
      
      // Charger les projets
      final projects = await _projectService.getAllProjects();
      
      // Trouver les projets avec solde négatif (alerte)
      final projectsWithAlert = projects.where((project) {
        // Calculer les entrées et sorties d'argent pour ce projet
        double projectIncome = 0.0;
        double projectExpenses = 0.0;
        
        for (final transaction in projectTransactions) {
          if (transaction.projectId == project.id) {
            if (transaction.isIncome) {
              projectIncome += transaction.absoluteAmount;
            } else {
              projectExpenses += transaction.absoluteAmount;
            }
          }
        }
        
        // Un projet est en alerte si ses dépenses sont supérieures à ses revenus
        return projectExpenses > projectIncome;
      }).toList();
      
      // Calculer les statistiques financières
      final totalRevenues = projectTransactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
      final totalExpenses = projectTransactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
      final totalBalance = totalRevenues - totalExpenses;
      
      // Créer des notifications pour les projets en alerte (solde négatif)
      for (final project in projectsWithAlert) {
        // Calculer les entrées et sorties d'argent pour ce projet
        double projectIncome = 0.0;
        double projectExpenses = 0.0;
        
        for (final transaction in projectTransactions) {
          if (transaction.projectId == project.id) {
            if (transaction.isIncome) {
              projectIncome += transaction.absoluteAmount;
            } else {
              projectExpenses += transaction.absoluteAmount;
            }
          }
        }
        
        final projectBalance = projectIncome - projectExpenses;
        
        // Créer une notification pour le solde négatif
        if (projectBalance < 0) {
          final userId = _projectFinanceService.supabaseClient.auth.currentUser!.id;
          await _notificationService.createProjectBalanceAlertNotification(
            project.id,
            project.name,
            projectBalance,
            userId,
          );
        }
      }
      
      setState(() {
        _projectTransactions = projectTransactions;
        _projects = projects;
        _recentTransactions = recentTransactions;
        _projectsWithBalanceAlert = projectsWithAlert;
        _totalRevenues = totalRevenues;
        _totalExpenses = totalExpenses;
        _totalBalance = totalBalance;
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
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isAdmin && _selectedProjectId != null ? 48 : 48),
          child: Column(
            children: [
              // TabBar pour la navigation
              TabBar(
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
                  Tab(text: 'Finances des projets'),
                  Tab(text: 'Alertes'),
                  Tab(text: 'Transactions'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Affichage du sélecteur de projet uniquement pour les administrateurs
          if (_isAdmin) 
            ProjectSelectorButton(
              onPressed: _showProjectSelector,
              showAllProjects: _showAllProjects,
              projectName: _selectedProjectName,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionFormScreen(),
            ),
          );
          
          if (result != null) {
            _loadData();
          }
        },
        tooltip: 'Ajouter une transaction',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildProjectFinancesTab(),
                _buildAlertsTab(),
                _buildTransactionsTab(),
              ],
            ),
    );
  }
  
  // Méthode pour afficher le sélecteur de projet
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
              projects: _projects,
              selectedProjectId: _selectedProjectId,
              showAllProjects: _showAllProjects,
              onProjectSelected: (projectId, showAll) {
                setState(() {
                  _showAllProjects = showAll;
                  _selectedProjectId = projectId;
                });
                _loadData();
              },
            ),
          ),
        );
      },
    );
  }
  
  // Widget pour la carte de statistiques
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  // Onglet Vue d'ensemble
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
                    'Revenus',
                    currencyFormat.format(_totalRevenues),
                    Icons.arrow_upward,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Dépenses',
                    currencyFormat.format(_totalExpenses),
                    Icons.arrow_downward,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Solde',
                    currencyFormat.format(_totalBalance),
                    Icons.monetization_on,
                    _totalBalance >= 0 ? Colors.green : Colors.red,
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                            // Aller à l'onglet Transactions
                            _tabController.animateTo(3);
                          },
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecentTransactionsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Méthode pour construire le graphique des dépenses
  Widget _buildExpensesChart() {
    // Grouper les dépenses par catégorie
    final Map<String, double> expensesByCategory = {};
    
    for (final transaction in _projectTransactions) {
      if (!transaction.isIncome) {
        final category = transaction.category;
        if (expensesByCategory.containsKey(category)) {
          expensesByCategory[category] = expensesByCategory[category]! + transaction.absoluteAmount;
        } else {
          expensesByCategory[category] = transaction.absoluteAmount;
        }
      }
    }
    
    // Couleurs pour le graphique
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.brown,
    ];
    
    if (expensesByCategory.isEmpty) {
      return const Center(
        child: Text('Aucune dépense pour la période sélectionnée'),
      );
    }
    
    // Convertir en données pour le graphique
    final List<ChartData> chartData = [];
    
    int colorIndex = 0;
    expensesByCategory.forEach((category, amount) {
      final percentage = (amount / _totalExpenses) * 100;
      final chartDataItem = ChartData(
        category,
        amount,
        colors[colorIndex % colors.length],
        percentText: '${percentage.toStringAsFixed(1)}%',
        amountText: NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount),
      );
      
      chartData.add(chartDataItem);
      
      colorIndex++;
    });
    
    return SfCircularChart(
      series: <CircularSeries>[
        PieSeries(
          dataSource: chartData,
          xValueMapper: (data, index) => data.category,
          yValueMapper: (data, index) => data.amount, 
          pointColorMapper: (data, index) => data.color,
          dataLabelMapper: (data, index) => data.percentText,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
              length: '10%',
            ),
          ),
          enableTooltip: true,
          animationDuration: 1200,
          explode: true,
          explodeIndex: 0,
          explodeOffset: '5%',
          explodeGesture: ActivationMode.singleTap,
        ),
      ],
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }
  
  // Méthode pour construire le graphique des entrées
  Widget _buildIncomesChart() {
    // Grouper les entrées par catégorie
    final Map<String, double> incomesByCategory = {};
    
    for (final transaction in _projectTransactions) {
      if (transaction.isIncome) {
        final category = transaction.category;
        if (incomesByCategory.containsKey(category)) {
          incomesByCategory[category] = incomesByCategory[category]! + transaction.absoluteAmount;
        } else {
          incomesByCategory[category] = transaction.absoluteAmount;
        }
      }
    }
    
    // Couleurs pour le graphique
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.amber,
      Colors.pink,
      Colors.indigo,
      Colors.red,
      Colors.brown,
    ];
    
    if (incomesByCategory.isEmpty) {
      return const Center(
        child: Text('Aucune entrée pour la période sélectionnée'),
      );
    }
    
    // Convertir en données pour le graphique
    final List<ChartData> chartData = [];
    
    int colorIndex = 0;
    incomesByCategory.forEach((category, amount) {
      final percentage = (amount / _totalRevenues) * 100;
      final chartDataItem = ChartData(
        category,
        amount,
        colors[colorIndex % colors.length],
        percentText: '${percentage.toStringAsFixed(1)}%',
        amountText: NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount),
      );
      
      chartData.add(chartDataItem);
      
      colorIndex++;
    });
    
    return SfCircularChart(
      series: <CircularSeries>[
        PieSeries(
          dataSource: chartData,
          xValueMapper: (data, index) => data.category,
          yValueMapper: (data, index) => data.amount, 
          pointColorMapper: (data, index) => data.color,
          dataLabelMapper: (data, index) => data.percentText,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
              length: '10%',
            ),
          ),
          enableTooltip: true,
          animationDuration: 1200,
          explode: true,
          explodeIndex: 0,
          explodeOffset: '5%',
          explodeGesture: ActivationMode.singleTap,
        ),
      ],
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }
  
  // Méthode pour construire la liste des transactions récentes
  Widget _buildRecentTransactionsList() {
    if (_recentTransactions.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('Aucune transaction récente'),
        ),
      );
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length > 5 ? 5 : _recentTransactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final transaction = _recentTransactions[index];
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: transaction.isIncome ? Colors.green[100] : Colors.red[100],
            child: Icon(
              transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: transaction.isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            transaction.description.isNotEmpty ? transaction.description : 'Transaction sans description',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: transaction.projectName.isNotEmpty
              ? Text(
                  transaction.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                )
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isIncome ? '+' : '-'}${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(transaction.absoluteAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: transaction.isIncome ? Colors.green : Colors.red,
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy').format(transaction.transactionDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          onTap: () async {
            // Afficher le formulaire d'édition de la transaction
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransactionFormScreen(
                  transaction: transaction,
                ),
              ),
            );
            
            if (result != null) {
              _loadData();
            }
          },
        );
      },
    );
  }
  
  // Onglet Finances des projets
  Widget _buildProjectFinancesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: _projects.isEmpty
          ? const Center(child: Text('Aucun projet trouvé'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return _buildProjectFinanceCard(project);
              },
            ),
    );
  }
  
  // Méthode pour construire la carte de finance d'un projet
  Widget _buildProjectFinanceCard(Project project) {
    // Calculer les revenus et dépenses pour ce projet
    double projectIncome = 0.0;
    double projectExpenses = 0.0;
    
    for (final transaction in _projectTransactions) {
      if (transaction.projectId == project.id) {
        if (transaction.isIncome) {
          projectIncome += transaction.absoluteAmount;
        } else {
          projectExpenses += transaction.absoluteAmount;
        }
      }
    }
    
    final projectBalance = projectIncome - projectExpenses;
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Déterminer si le projet est en alerte (solde négatif)
    final bool isInAlert = projectBalance < 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isInAlert
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          if (isInAlert)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Solde négatif',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête du projet
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            project.description.isNotEmpty 
                                ? project.description 
                                : 'Aucune description',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Cartes de statistiques financières du projet
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Revenus',
                        currencyFormat.format(projectIncome),
                        Icons.arrow_upward,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Dépenses',
                        currencyFormat.format(projectExpenses),
                        Icons.arrow_downward,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Solde',
                        currencyFormat.format(projectBalance),
                        Icons.monetization_on,
                        projectBalance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Historique'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueGrey,
                        side: BorderSide(color: Colors.blueGrey.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        // Filtrer les transactions par projet et aller à l'onglet Transactions
                        setState(() {
                          _selectedProjectId = project.id;
                          _showAllProjects = false;
                        });
                        _loadData();
                        _tabController.animateTo(3); // Aller à l'onglet Transactions
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        // Ajouter une transaction pour ce projet
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionFormScreen(
                              projectId: project.id,
                              initialProjectId: project.id,
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
        ],
      ),
    );
  }
  
  // Onglet Alertes
  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: _projectsWithBalanceAlert.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune alerte',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tous vos projets ont un solde positif',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _projectsWithBalanceAlert.length,
              itemBuilder: (context, index) {
                final project = _projectsWithBalanceAlert[index];
                
                // Calculer les revenus et dépenses pour ce projet
                double projectIncome = 0.0;
                double projectExpenses = 0.0;
                
                for (final transaction in _projectTransactions) {
                  if (transaction.projectId == project.id) {
                    if (transaction.isIncome) {
                      projectIncome += transaction.absoluteAmount;
                    } else {
                      projectExpenses += transaction.absoluteAmount;
                    }
                  }
                }
                
                final projectBalance = projectIncome - projectExpenses;
                final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Alerte: Solde négatif',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  child: Text(
                                    project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Solde: ${currencyFormat.format(projectBalance)}',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Détails des finances
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  _buildFinanceDetailRow(
                                    'Revenus',
                                    currencyFormat.format(projectIncome),
                                    Icons.arrow_upward,
                                    Colors.green,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFinanceDetailRow(
                                    'Dépenses',
                                    currencyFormat.format(projectExpenses),
                                    Icons.arrow_downward,
                                    Colors.red,
                                  ),
                                  const Divider(height: 16),
                                  _buildFinanceDetailRow(
                                    'Différence',
                                    currencyFormat.format(projectBalance),
                                    Icons.warning,
                                    Colors.red.shade700,
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('Voir détails'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueGrey,
                                    side: BorderSide(color: Colors.blueGrey.shade200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedProjectId = project.id;
                                      _showAllProjects = false;
                                    });
                                    _loadData();
                                    _tabController.animateTo(3); // Aller à l'onglet Transactions
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Ajouter un revenu'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () async {
                                    // Ajouter une transaction pour ce projet
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TransactionFormScreen(
                                          projectId: project.id,
                                          initialProjectId: project.id,
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
                    ],
                  ),
                );
              },
            ),
    );
  }
  
  // Widget pour afficher une ligne détaillée des finances
  Widget _buildFinanceDetailRow(String label, String value, IconData icon, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? color : Colors.grey[800],
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
  
  // Onglet Transactions
  Widget _buildTransactionsTab() {
    if (_projectTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune transaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des transactions pour voir l\'historique ici',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une transaction'),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionFormScreen(),
                  ),
                );
                
                if (result != null) {
                  _loadData();
                }
              },
            ),
          ],
        ),
      );
    }
    
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Options de filtre
          Container(
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtre de date (à implémenter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Filtrer par type',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(text: 'Toutes'),
                    Tab(text: 'Revenus'),
                    Tab(text: 'Dépenses'),
                  ],
                ),
              ],
            ),
          ),
          
          // Contenu
          Expanded(
            child: TabBarView(
              children: [
                // Toutes les transactions
                _buildTransactionsList(_projectTransactions),
                // Revenus uniquement
                _buildTransactionsList(_projectTransactions.where((t) => t.isIncome).toList()),
                // Dépenses uniquement
                _buildTransactionsList(_projectTransactions.where((t) => !t.isIncome).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Méthode pour construire la liste des transactions
  Widget _buildTransactionsList(List<ProjectTransaction> transactions) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: transactions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            elevation: 1,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: transaction.isIncome ? Colors.green[100] : Colors.red[100],
                child: Icon(
                  transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: transaction.isIncome ? Colors.green : Colors.red,
                ),
              ),
              title: Text(
                transaction.description.isNotEmpty ? transaction.description : 'Transaction sans description',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        transaction.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(transaction.transactionDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (transaction.projectName.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.group_work, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          transaction.projectName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              trailing: Text(
                '${transaction.isIncome ? '+' : '-'}${currencyFormat.format(transaction.absoluteAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: transaction.isIncome ? Colors.green : Colors.red,
                  fontSize: 16,
                ),
              ),
              onTap: () async {
                // Afficher le formulaire d'édition de la transaction
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionFormScreen(
                      transaction: transaction,
                    ),
                  ),
                );
                
                if (result != null) {
                  _loadData();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
