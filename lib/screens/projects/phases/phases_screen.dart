import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/phase_model.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../services/phase_service/phase_service.dart';
import '../../../services/project_service/project_service.dart';
import '../../../widgets/islamic_patterns.dart';
import 'phase_form.dart';
import 'phase_detail_screen.dart';

class PhasesScreen extends StatefulWidget {
  final Project project;
  final Phase? initialPhase;

  const PhasesScreen({
    super.key,
    required this.project,
    this.initialPhase,
  });

  @override
  State<PhasesScreen> createState() => _PhasesScreenState();
}

class _PhasesScreenState extends State<PhasesScreen> {
  final PhaseService _phaseService = PhaseService();
  final ProjectService _projectService = ProjectService();
  
  List<Phase> _phases = [];
  Map<String, List<Task>> _tasksByPhase = {};
  List<Task> _tasksWithoutPhase = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Si une phase initiale est fournie, ouvrir directement le formulaire d'édition
    if (widget.initialPhase != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPhaseForm(widget.initialPhase);
      });
    }
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Charger les phases
      final phases = await _phaseService.getPhasesByProject(widget.project.id);
      
      // Charger les tâches du projet
      final tasks = await _projectService.getTasksByProject(widget.project.id);
      
      // Organiser les tâches par phase
      final tasksByPhase = <String, List<Task>>{};
      final tasksWithoutPhase = <Task>[];
      
      for (final task in tasks) {
        if (task.phaseId != null) {
          if (tasksByPhase[task.phaseId!] != null) {
            tasksByPhase[task.phaseId!]!.add(task);
          } else {
            tasksByPhase[task.phaseId!] = [task];
          }
        } else {
          tasksWithoutPhase.add(task);
        }
      }
      
      setState(() {
        _phases = phases;
        _tasksByPhase = tasksByPhase;
        _tasksWithoutPhase = tasksWithoutPhase;
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
  
  void _showAddPhaseDialog() {
    // Appeler _showPhaseForm avec null pour créer une nouvelle phase
    _showPhaseForm(null);
  }
  
  void _showEditPhaseDialog(Phase phase) {
    showDialog(
      context: context,
      builder: (context) => PhaseForm(
        projectId: widget.project.id,
        phase: phase,
        onPhaseUpdated: (updatedPhase) {
          setState(() {
            final index = _phases.indexWhere((p) => p.id == updatedPhase.id);
            if (index != -1) {
              _phases[index] = updatedPhase;
            }
          });
        },
      ),
    );
  }
  
  Future<void> _deletePhase(Phase phase) async {
    try {
      await _phaseService.deletePhase(phase.id);
      
      setState(() {
        _phases.removeWhere((p) => p.id == phase.id);
        _tasksByPhase.remove(phase.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phase supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la suppression de la phase: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression de la phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _reorderPhases(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final phase = _phases.removeAt(oldIndex);
    _phases.insert(newIndex, phase);
    
    try {
      await _phaseService.reorderPhases(_phases);
    } catch (e) {
      print('Erreur lors de la réorganisation des phases: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la réorganisation des phases: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showPhaseForm(Phase? phase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhaseForm(
        projectId: widget.project.id,
        phase: phase,
        orderIndex: phase == null ? _phases.length : phase.orderIndex,
        onPhaseCreated: (newPhase) {
          setState(() {
            _phases.add(newPhase);
            _phases.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          });
          Navigator.of(context).pop();
          _loadData();
        },
        onPhaseUpdated: (updatedPhase) {
          setState(() {
            final index = _phases.indexWhere((p) => p.id == updatedPhase.id);
            if (index != -1) {
              _phases[index] = updatedPhase;
            }
          });
          Navigator.of(context).pop();
          _loadData();
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Phases - ${widget.project.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPhaseDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _phases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: IslamicPatternPlaceholder(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Aucune phase pour ce projet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cliquez sur le bouton + pour ajouter une phase',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddPhaseDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une phase'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Phases du projet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: _phases.length,
                        onReorder: _reorderPhases,
                        itemBuilder: (context, index) {
                          final phase = _phases[index];
                          final tasks = _tasksByPhase[phase.id] ?? [];
                          final phaseStatus = PhaseStatus.fromValue(phase.status);
                          
                          return Card(
                            key: Key(phase.id),
                            margin: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12.0 : 24.0,
                              vertical: 8.0,
                            ),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PhaseDetailScreen(
                                      project: widget.project,
                                      phase: phase,
                                    ),
                                  ),
                                ).then((_) => _loadData());
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: phaseStatus.getColor().withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: phaseStatus.getColor(),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      phase.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      phase.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Chip(
                                          label: Text(
                                            phaseStatus.getText(),
                                            style: TextStyle(
                                              color: phaseStatus.getColor(),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          backgroundColor: phaseStatus.getColor().withOpacity(0.2),
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton(
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit),
                                                  SizedBox(width: 8),
                                                  Text('Modifier'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Supprimer', style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showPhaseForm(phase);
                                            } else if (value == 'delete') {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Supprimer la phase'),
                                                  content: const Text(
                                                    'Êtes-vous sûr de vouloir supprimer cette phase ? '
                                                    'Les tâches associées à cette phase seront dissociées mais pas supprimées.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('Annuler'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        _deletePhase(phase);
                                                      },
                                                      child: const Text(
                                                        'Supprimer',
                                                        style: TextStyle(color: Colors.red),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (tasks.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tâches (${tasks.length})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 40,
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: tasks.length > 3 ? 3 : tasks.length,
                                              itemBuilder: (context, index) {
                                                final task = tasks[index];
                                                return Container(
                                                  margin: const EdgeInsets.only(right: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      task.title,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          if (tasks.length > 3)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                '+ ${tasks.length - 3} autres tâches',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_tasksWithoutPhase.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[200],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tâches sans phase',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _tasksWithoutPhase.length,
                                itemBuilder: (context, index) {
                                  final task = _tasksWithoutPhase[index];
                                  return Card(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      width: 200,
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            task.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
