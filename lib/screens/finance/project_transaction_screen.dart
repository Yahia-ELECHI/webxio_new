import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/project_model.dart';
import '../../models/project_transaction_model.dart';
import '../../services/project_finance_service.dart';
import '../../services/project_service/project_service.dart';
import '../../utils/snackbar_helper.dart';

class ProjectTransactionScreen extends StatefulWidget {
  final String? initialProjectId;
  final String? projectId;
  final String? phaseId;
  final String? taskId;

  const ProjectTransactionScreen({
    Key? key,
    this.initialProjectId,
    this.projectId,
    this.phaseId,
    this.taskId,
  }) : super(key: key);

  @override
  _ProjectTransactionScreenState createState() => _ProjectTransactionScreenState();
}

class _ProjectTransactionScreenState extends State<ProjectTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  final ProjectFinanceService _financeService = ProjectFinanceService();
  final ProjectService _projectService = ProjectService();
  
  bool _isLoading = true;
  String? _errorMessage;
  
  List<Project> _projects = [];
  
  String? _selectedProjectId;
  String? _selectedPhaseId;
  String? _selectedTaskId;
  
  Project? _selectedProject;
  
  String _selectedCategory = 'expense';
  String? _selectedSubcategory;
  DateTime _transactionDate = DateTime.now();
  
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  
  // Catégories et sous-catégories
  final Map<String, List<String>> _categoryOptions = {
    'expense': [
      'Matériaux',
      'Main-d\'œuvre',
      'Équipement',
      'Services',
      'Frais administratifs',
      'Transport',
      'Imprévus',
      'Autres dépenses'
    ],
    'income': [
      'Paiement client',
      'Subvention',
      'Remboursement',
      'Revenu divers'
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId ?? widget.projectId;
    _selectedPhaseId = widget.phaseId;
    _selectedTaskId = widget.taskId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final projects = await _projectService.getAllProjects();
      
      setState(() {
        _projects = projects;
        
        // Si les valeurs initiales n'étaient pas définies, sélectionner les premiers éléments par défaut
        if (_selectedProjectId == null && projects.isNotEmpty) {
          _selectedProjectId = projects.first.id;
        }
        
        _updateSelectedItems();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données: $e';
        _isLoading = false;
      });
    }
  }

  void _updateSelectedItems() {
    if (_projects.isEmpty) {
      _selectedProject = null;
    } else {
      _selectedProject = _projects.firstWhere(
        (project) => project.id == _selectedProjectId,
        orElse: () => _projects.first,
      );
    }
    
    if (_selectedProject != null) {
      _selectedProjectId = _selectedProject!.id;
      
      // Initialiser la sous-catégorie si elle n'est pas définie
      if (_selectedSubcategory == null && _categoryOptions[_selectedCategory]!.isNotEmpty) {
        _selectedSubcategory = _categoryOptions[_selectedCategory]!.first;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final amount = double.parse(_amountController.text.replaceAll(',', '.'));
        final note = _noteController.text.trim();
        
        // Créer la transaction
        await _financeService.createTransaction(
          _selectedProjectId!,
          _selectedPhaseId,
          _selectedTaskId,
          amount,
          note,
          _transactionDate,
          _selectedCategory,
          _selectedSubcategory,
        );
        
        if (!mounted) return;
        SnackBarHelper.showSuccessSnackBar(
          context, 
          'Transaction ajoutée avec succès'
        );
        
        // Réinitialiser le formulaire
        _amountController.clear();
        _noteController.clear();
        setState(() {
          _transactionDate = DateTime.now();
        });
      } catch (e) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur lors de la création de la transaction: ${e.toString()}'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter une transaction'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nouvelle transaction',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enregistrez une entrée ou sortie d\'argent pour un projet spécifique.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Type de transaction (entrée/sortie)
                        const Text(
                          'Type de transaction',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Dépense'),
                                value: 'expense',
                                groupValue: _selectedCategory,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategory = value!;
                                    _selectedSubcategory = _categoryOptions[value]!.first;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Revenu'),
                                value: 'income',
                                groupValue: _selectedCategory,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategory = value!;
                                    _selectedSubcategory = _categoryOptions[value]!.first;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Sélection du projet
                        const Text(
                          'Informations générales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              _updateSelectedItems();
                              
                              // Réinitialiser les phases et tâches
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
                        
                        // Catégorie et sous-catégorie
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Catégorie',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          value: _selectedSubcategory,
                          items: _categoryOptions[_selectedCategory]!.map((subcategory) {
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez sélectionner une catégorie';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Date de la transaction
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _transactionDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            
                            if (date != null) {
                              setState(() {
                                _transactionDate = date;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_transactionDate),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Montant et description
                        const Text(
                          'Détails de la transaction',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Montant (€)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.euro),
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
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          minLines: 2,
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Veuillez saisir une description';
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
                            child: const Text('Enregistrer la transaction'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
