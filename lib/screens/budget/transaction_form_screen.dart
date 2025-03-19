import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../models/task_model.dart';
import '../../models/project_transaction_model.dart';
import '../../services/project_finance_service.dart';
import '../../services/project_service/project_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/constants.dart';

class TransactionFormScreen extends StatefulWidget {
  final ProjectTransaction? transaction; // Si null, c'est une nouvelle transaction
  final String? projectId; // ID du projet pour une nouvelle transaction
  final String? phaseId; // ID de la phase pour une nouvelle transaction
  final String? taskId; // ID de la tâche pour une nouvelle transaction

  const TransactionFormScreen({
    Key? key, 
    this.transaction, 
    this.projectId,
    this.phaseId,
    this.taskId,
  }) : super(key: key);

  @override
  _TransactionFormScreenState createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _projectFinanceService = ProjectFinanceService();
  final _projectService = ProjectService();
  
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isIncomeTransaction = true;
  
  DateTime _transactionDate = DateTime.now();
  String? _selectedProjectId;
  String? _selectedPhaseId;
  String? _selectedTaskId;
  String _selectedCategory = 'Autre';
  String? _selectedSubcategory;
  
  List<Project> _projects = [];
  List<Phase> _phases = [];
  List<Task> _tasks = [];
  final Map<String, List<String>> _categories = {
    'Entrée': ['Don', 'Virement','Vente de livres','Cours en ligne', 'Cagnotte en ligne', 'Waqf','Remboursement', 'Dotation', 'Subvention', 'Autre'],
    'Construction': ['Terrassement', 'Fondations', 'Gros œuvre', 'Second œuvre', 'Toiture', 'Façades', 'Aménagements extérieurs', 'Équipements techniques', 'Finitions', 'Mobilier', 'Honoraires architecte', 'Études techniques', 'Permis et autorisations', 'Autre'],
    'Éducatif': ['Matériel pédagogique', 'Bibliothèque', 'Équipement multimédia', 'Fournitures scolaires', 'Livres religieux', 'Formation enseignants', 'Activités parascolaires', 'Autre'],
    'Ressources': ['Matériel', 'Licences logicielles', 'Formation', 'Services externes', 'Équipements spécialisés', 'Autre'],
    'Personnel': ['Salaires', 'Primes', 'Freelance', 'Consultants', 'Corps enseignant', 'Personnel administratif', 'Agents d\'entretien', 'Autre'],
    'Marketing': ['Publicité', 'Relations publiques', 'Événements', 'Supports marketing', 'Journées portes ouvertes', 'Communication digitale', 'Autre'],
    'Opérations': ['Location', 'Utilities', 'Assurances', 'Maintenance', 'Entretien bâtiment', 'Sécurité', 'Autre'],
    'Finance': ['Taxes', 'Frais bancaires', 'Intérêts', 'Assurances spécifiques', 'Autre'],
    'Autre': ['Divers'],
  };
  List<String> _subcategories = [];
  List<String> _entriesCategories = ['Entrée'];
  List<String> _expensesCategories = ['Construction', 'Éducatif', 'Ressources', 'Personnel', 'Marketing', 'Opérations', 'Finance', 'Autre'];

  @override
  void initState() {
    super.initState();
    _initFormData();
    _loadProjects();
  }

  Future<void> _initFormData() async {
    if (widget.transaction != null) {
      _isEditing = true;
      _descriptionController.text = widget.transaction!.description;
      _amountController.text = widget.transaction!.amount.abs().toString();
      _isIncomeTransaction = widget.transaction!.amount > 0;
      _transactionDate = widget.transaction!.transactionDate;
      _selectedProjectId = widget.transaction!.projectId;
      _selectedPhaseId = widget.transaction!.phaseId;
      _selectedTaskId = widget.transaction!.taskId;
      
      // Convertir les catégories de la base de données en catégories d'affichage
      if (widget.transaction!.category == 'income') {
        _selectedCategory = 'Entrée';
      } else if (widget.transaction!.category == 'expense') {
        // Utiliser une catégorie de dépense par défaut si aucune sous-catégorie n'est spécifiée
        _selectedCategory = widget.transaction!.subcategory != null 
            ? _getCategoryForSubcategory(widget.transaction!.subcategory!) 
            : 'Ressources';
      } else {
        _selectedCategory = widget.transaction!.category;
      }
      
      _selectedSubcategory = widget.transaction!.subcategory;
      
      // Initialiser les sous-catégories en fonction de la catégorie sélectionnée
      _updateSubcategories(_selectedCategory);
    } else {
      _selectedProjectId = widget.projectId;
      _selectedPhaseId = widget.phaseId;
      _selectedTaskId = widget.taskId;
      _updateSubcategories(_isIncomeTransaction ? 'Entrée' : 'Ressources');
    }
  }

  // Méthode pour trouver la catégorie principale correspondant à une sous-catégorie
  String _getCategoryForSubcategory(String subcategory) {
    for (var entry in _categories.entries) {
      if (entry.value.contains(subcategory)) {
        return entry.key;
      }
    }
    return 'Autre';
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _projectService.getAllProjects();
      print('Projets récupérés: ${projects.length}');
      
      // Afficher les IDs et noms des projets pour déboguer
      for (var project in projects) {
        print('Projet trouvé: ${project.id} - ${project.name} - créé par: ${project.createdBy}');
      }
      
      final phases = await _projectService.getAllPhases();
      final tasks = await _projectService.getAllTasks();
      
      setState(() {
        _projects = projects;
        _phases = phases;
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: ${e.toString()}');
      SnackBarHelper.showErrorSnackBar(
        context, 
        'Erreur lors du chargement des données: ${e.toString()}'
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateSubcategories(String category) {
    setState(() {
      _selectedCategory = category;
      _subcategories = _categories[category] ?? [];
      _selectedSubcategory = _subcategories.isNotEmpty ? _subcategories.first : null;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final description = _descriptionController.text.trim();
        double amount = double.parse(_amountController.text.replaceAll(',', '.'));
        if (!_isIncomeTransaction) {
          amount = -amount; // Montant négatif pour les dépenses
        }

        if (_isEditing) {
          // Mettre à jour la transaction existante
          final updatedTransaction = widget.transaction!.copyWith(
            description: description,
            amount: amount,
            category: _selectedCategory == 'Entrée' ? 'income' : _selectedCategory,
            subcategory: _selectedSubcategory,
            projectId: _selectedProjectId,
            phaseId: _selectedPhaseId,
            taskId: _selectedTaskId,
            transactionDate: _transactionDate,
            updatedAt: DateTime.now(),
          );
          
          await _projectFinanceService.updateTransaction(updatedTransaction);
          
          if (!mounted) return;
          SnackBarHelper.showSuccessSnackBar(
            context, 
            'Transaction mise à jour avec succès'
          );
          Navigator.pop(context, updatedTransaction);
        } else {
          // Créer une nouvelle transaction
          final newTransaction = await _projectFinanceService.createTransaction(
            _selectedProjectId!,
            _selectedPhaseId,
            _selectedTaskId,
            amount,
            description,
            _transactionDate,
            _selectedCategory == 'Entrée' ? 'income' : _selectedCategory,
            _selectedSubcategory,
          );
          
          if (!mounted) return;
          SnackBarHelper.showSuccessSnackBar(
            context, 
            'Transaction créée avec succès'
          );
          Navigator.pop(context, newTransaction);
        }
      } catch (e) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur: ${e.toString()}'
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('fr', 'FR'),
    );

    if (pickedDate != null) {
      setState(() {
        _transactionDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la transaction' : 'Nouvelle transaction'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations de la transaction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Type de transaction (entrée/sortie)
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Entrée'),
                            value: true,
                            groupValue: _isIncomeTransaction,
                            onChanged: (value) {
                              setState(() {
                                _isIncomeTransaction = value!;
                                // Mettre à jour les catégories disponibles
                                _updateSubcategories(_isIncomeTransaction ? 'Entrée' : 'Ressources');
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Sortie'),
                            value: false,
                            groupValue: _isIncomeTransaction,
                            onChanged: (value) {
                              setState(() {
                                _isIncomeTransaction = value!;
                                // Mettre à jour les catégories disponibles
                                _updateSubcategories(_isIncomeTransaction ? 'Entrée' : 'Ressources');
                              });
                            },
                            activeColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir une description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Montant
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Montant (€)',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          _isIncomeTransaction ? Icons.arrow_upward : Icons.arrow_downward,
                          color: _isIncomeTransaction ? Colors.green : Colors.red,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir un montant';
                        }
                        final amount = double.tryParse(value.replaceAll(',', '.'));
                        if (amount == null || amount <= 0) {
                          return 'Le montant doit être un nombre positif';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date de la transaction
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date de la transaction',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_transactionDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Catégorisation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Catégorie
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: _selectedCategory,
                      items: (_isIncomeTransaction ? _entriesCategories : _expensesCategories)
                          .map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _updateSubcategories(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner une catégorie';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Sous-catégorie
                    if (_subcategories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Sous-catégorie',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.bookmark),
                        ),
                        value: _selectedSubcategory,
                        items: _subcategories.map((subcategory) {
                          return DropdownMenuItem<String>(
                            value: subcategory,
                            child: Text(subcategory),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubcategory = value;
                          });
                        },
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Attribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Projet
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Projet',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      value: _selectedProjectId,
                      items: _projects.map((project) {
                        return DropdownMenuItem<String>(
                          value: project.id,
                          child: Text(project.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectId = value;
                          _selectedPhaseId = null;
                          _selectedTaskId = null;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner un projet';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phase
                    if (_selectedProjectId != null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Phase',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.linear_scale),
                        ),
                        value: _selectedPhaseId,
                        items: _phases.where((phase) => phase.projectId == _selectedProjectId).map((phase) {
                          return DropdownMenuItem<String>(
                            value: phase.id,
                            child: Text(phase.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPhaseId = value;
                            _selectedTaskId = null;
                          });
                        },
                        validator: (value) {
                          if (_selectedProjectId != null && (value == null || value.isEmpty)) {
                            return 'Veuillez sélectionner une phase';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    // Tâche
                    if (_selectedProjectId != null && _selectedPhaseId != null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Tâche',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.check_box),
                        ),
                        value: _selectedTaskId,
                        items: _tasks.where((task) => task.projectId == _selectedProjectId && task.phaseId == _selectedPhaseId).map((task) {
                          return DropdownMenuItem<String>(
                            value: task.id,
                            child: Text(task.title),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTaskId = value;
                          });
                        },
                        validator: (value) {
                          if (_selectedProjectId != null && _selectedPhaseId != null && (value == null || value.isEmpty)) {
                            return 'Veuillez sélectionner une tâche';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                        child: Text(_isEditing ? 'Mettre à jour' : 'Créer'),
                      ),
                    ),
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () {
                              // Afficher une boîte de dialogue de confirmation
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Supprimer la transaction'),
                                  content: const Text(
                                    'Êtes-vous sûr de vouloir supprimer cette transaction ? Cette action ne peut pas être annulée.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        try {
                                          await _projectFinanceService.deleteTransaction(widget.transaction!.id);
                                          if (!mounted) return;
                                          SnackBarHelper.showSuccessSnackBar(
                                            context, 
                                            'Transaction supprimée avec succès'
                                          );
                                          Navigator.pop(context, {'deleted': true, 'transactionId': widget.transaction!.id});
                                        } catch (e) {
                                          SnackBarHelper.showErrorSnackBar(
                                            context, 
                                            'Erreur lors de la suppression: ${e.toString()}'
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _isLoading = false;
                                            });
                                          }
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Supprimer'),
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
