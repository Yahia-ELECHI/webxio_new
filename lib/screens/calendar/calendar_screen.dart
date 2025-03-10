import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/project_service/project_service.dart';
import '../../models/task_model.dart';
import '../../widgets/islamic_patterns.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ProjectService _projectService = ProjectService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<Task> _allTasks = [];
  Map<DateTime, List<Task>> _events = {};
  List<Task> _selectedEvents = [];
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }
  
  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final tasks = await _projectService.getAllTasks();
      
      // Organiser les tâches par date d'échéance
      final events = <DateTime, List<Task>>{};
      
      for (final task in tasks) {
        if (task.dueDate != null) {
          final date = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );
          
          if (events[date] != null) {
            events[date]!.add(task);
          } else {
            events[date] = [task];
          }
        }
      }
      
      setState(() {
        _allTasks = tasks;
        _events = events;
        _isLoading = false;
        
        // Sélectionner les événements du jour actuel
        if (_selectedDay != null) {
          _selectedEvents = _getEventsForDay(_selectedDay!);
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des tâches: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des tâches: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  List<Task> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }
  
  // Obtenir la couleur de priorité la plus élevée pour un jour donné
  Color _getMarkerColorForDay(DateTime day) {
    final tasks = _getEventsForDay(day);
    if (tasks.isEmpty) return const Color(0xFF1F4E5F); // Couleur par défaut
    
    // Trouver la priorité la plus élevée parmi les tâches du jour
    int highestPriority = 0;
    for (final task in tasks) {
      final priority = task.priority;
      if (priority > highestPriority) {
        highestPriority = priority;
      }
    }
    
    // Retourner la couleur correspondant à la priorité la plus élevée
    return TaskPriority.fromValue(highestPriority).color;
  }
  
  // Générer les marqueurs pour un jour donné avec les couleurs de priorité
  List<Widget> _buildEventsMarkerForDay(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return [];
    
    // Regrouper les tâches par priorité
    final Map<int, int> priorityCounts = {};
    for (final task in events) {
      final priority = task.priority;
      priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
    }
    
    // Créer un marqueur pour chaque priorité présente (au maximum 3)
    final List<Widget> markers = [];
    // Trier les priorités de la plus haute à la plus basse
    final sortedPriorities = priorityCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    
    // Limiter à 3 marqueurs au maximum
    final displayPriorities = sortedPriorities.take(3).toList();
    
    for (final priority in displayPriorities) {
      markers.add(
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TaskPriority.fromValue(priority).color,
          ),
        ),
      );
    }
    
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 24.0),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 28),
                        const SizedBox(width: 16),
                        Text(
                          'Calendrier',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadTasks,
                          tooltip: 'Actualiser',
                        ),
                      ],
                    ),
                  ),
                  
                  // Calendrier
                  Card(
                    margin: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 24.0,
                      vertical: 8.0,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        eventLoader: _getEventsForDay,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                            _selectedEvents = _getEventsForDay(selectedDay);
                          });
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return null;
                            
                            return Positioned(
                              bottom: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildEventsMarkerForDay(date),
                              ),
                            );
                          },
                        ),
                        calendarStyle: CalendarStyle(
                          markersMaxCount: 3,
                          markerSize: 8,
                          markerDecoration: const BoxDecoration(
                            color: Color(0xFF1F4E5F),
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: const Color(0xFF1F4E5F).withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Color(0xFF1F4E5F),
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonDecoration: BoxDecoration(
                            color: const Color(0xFF1F4E5F),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          formatButtonTextStyle: const TextStyle(color: Colors.white),
                          titleCentered: true,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Titre de la section des événements
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16.0 : 28.0,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedDay != null
                              ? 'Tâches du ${DateFormat.yMMMMd('fr_FR').format(_selectedDay!)}'
                              : 'Sélectionnez une date',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedEvents.length} tâche${_selectedEvents.length != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Liste des événements du jour sélectionné
                  Expanded(
                    child: _selectedEvents.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.event_busy,
                                size: 48,
                                color: Color(0xFF1F4E5F),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 120,
                                height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    IslamicPatternBackground(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune tâche pour cette date',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sélectionnez une autre date ou ajoutez une nouvelle tâche',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12.0 : 24.0,
                            ),
                            itemCount: _selectedEvents.length,
                            itemBuilder: (context, index) {
                              final task = _selectedEvents[index];
                              return _buildTaskCard(task);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTaskCard(Task task) {
    // Déterminer la couleur en fonction de la priorité
    final priorityColors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.red,
    ];
    
    final priorityColor = task.priority >= 0 && task.priority < priorityColors.length
        ? priorityColors[task.priority]
        : Colors.grey;
    
    // Déterminer l'icône en fonction du statut
    IconData statusIcon;
    Color statusColor;
    
    switch (task.status.toLowerCase()) {
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusIcon = Icons.pending;
        statusColor = Colors.orange;
        break;
      case 'blocked':
        statusIcon = Icons.block;
        statusColor = Colors.red;
        break;
      default:
        statusIcon = Icons.circle_outlined;
        statusColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: priorityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: priorityColor.withOpacity(0.2),
          child: Icon(
            statusIcon,
            color: statusColor,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              task.description.isNotEmpty
                  ? task.description
                  : 'Aucune description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  task.dueDate != null
                      ? DateFormat.yMMMd('fr_FR').format(task.dueDate!)
                      : 'Pas de date limite',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: priorityColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            _getPriorityText(task.priority),
            style: TextStyle(
              color: priorityColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          // Naviguer vers les détails de la tâche
        },
      ),
    );
  }
  
  String _getPriorityText(int priority) {
    switch (priority) {
      case 0:
        return 'Faible';
      case 1:
        return 'Normale';
      case 2:
        return 'Élevée';
      case 3:
        return 'Urgente';
      default:
        return 'Inconnue';
    }
  }
}
