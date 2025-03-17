import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/team_model.dart';
import '../../models/task_history_model.dart';
import '../../models/attachment_model.dart';
import '../../models/budget_transaction_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/user_service.dart';
import '../../services/attachment_service.dart';
import '../../services/budget_service.dart';
import '../../widgets/budget_summary_widget.dart';
import '../../widgets/custom_app_bar.dart';
import '../budget/transaction_form_screen.dart';
import '../budget/transaction_list_screen.dart';
import 'task_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;
  final Function(Task)? onTaskDeleted;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final ProjectService _projectService = ProjectService();
  final TeamService _teamService = TeamService();
  final UserService _userService = UserService();
  final AttachmentService _attachmentService = AttachmentService();
  final BudgetService _budgetService = BudgetService();
  
  late Task _task;
  bool _isLoading = false;
  String? _errorMessage;
  List<Team> _assignedTeams = [];
  bool _loadingTeams = true;
  Map<String, String> _userDisplayNames = {};
  List<TaskHistory> _taskHistory = [];
  bool _loadingHistory = true;
  List<Attachment> _attachments = [];
  bool _loadingAttachments = true;
  List<BudgetTransaction> _taskTransactions = [];
  bool _loadingBudget = true;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadAssignedTeams();
    _loadUserDisplayNames();
    _loadTaskHistory();
    _loadAttachments();
    _loadTaskBudget();
  }

  Future<void> _loadAssignedTeams() async {
    try {
      final teams = await _teamService.getTeamsByTask(_task.id);
      setState(() {
        _assignedTeams = teams;
        _loadingTeams = false;
      });
    } catch (e) {
      setState(() {
        _loadingTeams = false;
        print('Erreur lors du chargement des équipes: $e');
      });
    }
  }

  Future<void> _loadUserDisplayNames() async {
    try {
      final userIds = <String>{_task.createdBy};
      if (_task.assignedTo != null) {
        userIds.add(_task.assignedTo!);
      }
      
      final displayNames = await _userService.getUsersDisplayNames(userIds.toList());
      setState(() {
        _userDisplayNames = displayNames;
      });
    } catch (e) {
      print('Erreur lors du chargement des noms d\'utilisateurs: $e');
    }
  }

  Future<void> _loadTaskHistory() async {
    try {
      final history = await _projectService.getTaskHistory(_task.id);
      setState(() {
        _taskHistory = history;
        _loadingHistory = false;
      });
      
      // Charger les noms des utilisateurs qui ont fait les modifications
      if (history.isNotEmpty) {
        final userIds = history.map((h) => h.userId).toSet().toList();
        final displayNames = await _userService.getUsersDisplayNames(userIds);
        setState(() {
          _userDisplayNames.addAll(displayNames);
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'historique de la tâche: $e');
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<void> _loadAttachments() async {
    try {
      final attachments = await _attachmentService.getAttachmentsByTask(_task.id);
      setState(() {
        _attachments = attachments;
        _loadingAttachments = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des pièces jointes: $e');
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _loadTaskBudget() async {
    try {
      final transactions = await _budgetService.getTransactionsByTask(_task.id);
      setState(() {
        _taskTransactions = transactions;
        _loadingBudget = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du budget: $e');
      setState(() {
        _loadingBudget = false;
      });
    }
  }

  Future<void> _refreshTaskDetails() async {
    try {
      final updatedTask = await _projectService.getTaskById(_task.id);
      setState(() {
        _task = updatedTask;
      });
      _loadAssignedTeams();
      _loadUserDisplayNames();
      _loadTaskHistory();
      _loadAttachments();
      _loadTaskBudget();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des détails de la tâche: $e';
      });
    }
  }

  Future<void> _updateTaskStatus(String status) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final updatedTask = await _projectService.updateTaskStatus(_task.id, status);
      
      setState(() {
        _task = updatedTask;
        _isLoading = false;
      });
      
      // Rafraîchir l'historique
      _loadTaskHistory();
      
      if (widget.onTaskUpdated != null) {
        widget.onTaskUpdated!(_task);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la mise à jour du statut: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _task.title,
        showLogo: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskFormScreen(
                      projectId: _task.projectId,
                      task: _task,
                    ),
                  ),
                );
                if (result == true) {
                  _refreshTaskDetails();
                }
              } else if (value == 'delete') {
                _showDeleteConfirmationDialog();
              }
            },
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
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshTaskDetails,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final TaskStatus status = TaskStatus.values.firstWhere(
      (s) => s.name == _task.status,
      orElse: () => TaskStatus.todo,
    );

    final TaskPriority priority = TaskPriority.fromValue(_task.priority);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _task.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.displayName,
                              style: TextStyle(
                                color: status.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priority.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              priority.displayName,
                              style: TextStyle(
                                color: priority.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _task.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Affichage de l'assignation individuelle si elle existe
                  if (_task.assignedTo != null)
                    _buildInfoRow('Assignée à', _userDisplayNames[_task.assignedTo!] ?? _task.assignedTo!),
                  
                  // Affichage des équipes assignées
                  if (_loadingTeams)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_assignedTeams.isNotEmpty) ...[
                    _buildInfoRow(
                      _assignedTeams.length > 1 ? 'Équipes assignées' : 'Équipe assignée',
                      _assignedTeams.map((team) => team.name).join(', ')
                    ),
                  ],
                  
                  if (_task.dueDate != null)
                    _buildInfoRow(
                      'Date d\'échéance',
                      _formatDate(_task.dueDate!),
                      _task.dueDate!.isBefore(DateTime.now()) ? Colors.red : null,
                    ),
                  _buildInfoRow('Créée par', _userDisplayNames[_task.createdBy] ?? _task.createdBy),
                  _buildInfoRow('Créée le', _formatDate(_task.createdAt)),
                  if (_task.updatedAt != null)
                    _buildInfoRow('Mise à jour le', _formatDate(_task.updatedAt!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusButton(TaskStatus.todo),
              _buildStatusButton(TaskStatus.inProgress),
              _buildStatusButton(TaskStatus.review),
              _buildStatusButton(TaskStatus.completed),
            ],
          ),
          
          // Section budget
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        tooltip: 'Ajouter une transaction',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionFormScreen(
                                taskId: _task.id,
                                phaseId: _task.phaseId,
                                projectId: _task.projectId,
                              ),
                            ),
                          );
                          
                          if (result != null) {
                            _loadTaskBudget();
                            _refreshTaskDetails();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _loadingBudget
                      ? const Center(child: CircularProgressIndicator())
                      : BudgetSummaryWidget(
                          budgetAllocated: _task.budgetAllocated,
                          budgetConsumed: _task.budgetConsumed,
                          transactions: _taskTransactions,
                          projectId: _task.projectId,
                          phaseId: _task.phaseId,
                          taskId: _task.id,
                          onTransactionAdded: (transaction) {
                            setState(() {
                              _taskTransactions.add(transaction);
                              // Mettre à jour le budget consommé si c'est une dépense
                              if (transaction.amount < 0) {
                                _task = _task.copyWith(
                                  budgetConsumed: (_task.budgetConsumed ?? 0) + transaction.amount.abs(),
                                );
                              }
                            });
                            _loadTaskBudget();
                          },
                          onTransactionUpdated: (transaction) {
                            setState(() {
                              final index = _taskTransactions.indexWhere((t) => t.id == transaction.id);
                              if (index != -1) {
                                _taskTransactions[index] = transaction;
                              }
                            });
                            _loadTaskBudget();
                            _refreshTaskDetails();
                          },
                          onTransactionDeleted: (transaction) {
                            setState(() {
                              _taskTransactions.removeWhere((t) => t.id == transaction.id);
                            });
                            _loadTaskBudget();
                            _refreshTaskDetails();
                          },
                        ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          _buildAttachmentsSection(),
          
          // Section historique des changements
          const SizedBox(height: 24),
          _buildTaskHistorySection(),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pièces jointes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add),
                  tooltip: 'Ajouter une pièce jointe',
                  onSelected: (value) async {
                    if (value == 'photo') {
                      await _takePhoto();
                    } else if (value == 'gallery') {
                      await _uploadImage();
                    } else if (value == 'document') {
                      await _uploadDocument();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'photo',
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt),
                          SizedBox(width: 8),
                          Text('Prendre une photo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'gallery',
                      child: Row(
                        children: [
                          Icon(Icons.photo_library),
                          SizedBox(width: 8),
                          Text('Choisir une image'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'document',
                      child: Row(
                        children: [
                          Icon(Icons.file_present),
                          SizedBox(width: 8),
                          Text('Ajouter un document'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingAttachments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_attachments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Aucune pièce jointe',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _attachments.length,
                itemBuilder: (context, index) {
                  final attachment = _attachments[index];
                  return _buildAttachmentItem(attachment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(Attachment attachment) {
    return InkWell(
      onTap: () => _openAttachment(attachment),
      onLongPress: () => _showAttachmentOptions(attachment),
      child: Container(
        decoration: BoxDecoration(
          color: attachment.getColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: attachment.getColor().withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (attachment.type == AttachmentType.image)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
              )
            else
              Icon(
                attachment.getIcon(),
                size: 40,
                color: attachment.getColor(),
              ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                attachment.name,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      final attachment = await _attachmentService.takePhoto(_task.id);
      
      if (attachment != null) {
        setState(() {
          _attachments.insert(0, attachment);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la prise de photo: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _uploadImage() async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      final attachment = await _attachmentService.uploadImageFromGallery(_task.id);
      
      if (attachment != null) {
        setState(() {
          _attachments.insert(0, attachment);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du téléchargement de l\'image: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _uploadDocument() async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      final attachment = await _attachmentService.uploadDocument(_task.id);
      
      if (attachment != null) {
        setState(() {
          _attachments.insert(0, attachment);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du téléchargement du document: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    try {
      // Afficher l'image directement dans l'application pour les pièces jointes de type image
      if (attachment.type == AttachmentType.image) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(attachment.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () async {
                      final Uri url = Uri.parse(attachment.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
              body: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Erreur: $error', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (attachment.type == AttachmentType.document && attachment.name.toLowerCase().endsWith('.pdf')) {
        // Utiliser WebView pour afficher le PDF directement depuis l'URL
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // Mise à jour de l'indicateur de progression
              },
              onPageStarted: (String url) {
                // La page commence à charger
              },
              onPageFinished: (String url) {
                // La page a fini de charger
              },
              onWebResourceError: (WebResourceError error) {
                _showErrorSnackBar('Erreur lors du chargement: ${error.description}');
              },
            ),
          )
          // Pour un PDF, nous utilisons Google PDF Viewer pour une meilleure compatibilité
          ..loadRequest(
            Uri.parse('https://docs.google.com/viewer?url=${Uri.encodeComponent(attachment.url)}&embedded=true'),
          );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(attachment.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () async {
                      final Uri url = Uri.parse(attachment.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
              body: WebViewWidget(controller: controller),
            ),
          ),
        );
      } else {
        // Pour les autres types, essayer d'ouvrir dans le navigateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ouverture de la pièce jointe...'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        final Uri url = Uri.parse(attachment.url);
        try {
          if (await canLaunchUrl(url)) {
            final bool launched = await launchUrl(
              url,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              _showErrorSnackBar('Impossible d\'ouvrir cette pièce jointe. Veuillez essayer de la télécharger manuellement.');
            }
          } else {
            _showErrorSnackBar('L\'URL ne peut pas être ouverte: ${url.toString()}');
          }
        } catch (e) {
          _showErrorSnackBar('Erreur lors de l\'ouverture: $e');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ouverture de la pièce jointe: $e');
    }
  }

  void _showAttachmentOptions(Attachment attachment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Ouvrir'),
              onTap: () {
                Navigator.pop(context);
                _openAttachment(attachment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                _shareAttachment(attachment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAttachment(attachment);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAttachment(Attachment attachment) async {
    try {
      final loadingDialog = _showLoadingDialog('Préparation du partage...');
      
      // Télécharger le fichier localement pour le partage
      final response = await http.get(Uri.parse(attachment.url));
      
      if (response.statusCode == 200) {
        // Obtenir le répertoire temporaire pour stocker le fichier
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${attachment.name}';
        
        // Sauvegarder le fichier
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Récupérer les informations du projet pour un meilleur contexte de partage
        String projectInfo = 'Projet: ${_task.projectId}';
        try {
          final project = await _projectService.getProjectById(_task.projectId);
          if (project != null) {
            projectInfo = 'Projet: ${project.name}';
          }
        } catch (e) {
          // En cas d'erreur, on garde l'ID du projet
          print('Erreur lors de la récupération du nom du projet: $e');
        }
        
        // Fermer le dialogue de chargement
        Navigator.pop(context); 
        
        // Générer un message de partage contextuel
        final taskInfo = 'Tâche: ${_task.title}';
        final shareMessage = 'Pièce jointe: ${attachment.name}\n$taskInfo\n$projectInfo';
        
        // Partager le fichier
        final result = await Share.shareXFiles(
          [XFile(filePath)],
          text: shareMessage,
          subject: 'Pièce jointe: ${attachment.name}',
        );
        
        if (result.status == ShareResultStatus.dismissed) {
          _showErrorSnackBar('Partage annulé');
        }
      } else {
        // Fermer le dialogue de chargement
        Navigator.pop(context);
        _showErrorSnackBar('Erreur lors du téléchargement du fichier pour le partage: ${response.statusCode}');
      }
    } catch (e) {
      // Gérer le cas où la boîte de dialogue est déjà fermée
      try {
        Navigator.pop(context);
      } catch (_) {}
      
      _showErrorSnackBar('Erreur lors du partage: $e');
    }
  }

  void _confirmDeleteAttachment(Attachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la pièce jointe'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette pièce jointe ? Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAttachment(attachment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      await _attachmentService.deleteAttachment(attachment);
      
      setState(() {
        _attachments.removeWhere((a) => a.id == attachment.id);
      });
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la suppression de la pièce jointe: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTaskHistorySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique des modifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_taskHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Aucune modification enregistrée',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: _taskHistory.map((historyEntry) => _buildHistoryItem(historyEntry)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(TaskHistory historyEntry) {
    final userName = _userDisplayNames[historyEntry.userId] ?? 'Utilisateur';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: historyEntry.getColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              historyEntry.getIcon(),
              size: 16,
              color: historyEntry.getColor(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  historyEntry.getDescription(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Par $userName le ${_formatDateTime(historyEntry.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? textColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textColor != null ? TextStyle(color: textColor) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(TaskStatus status) {
    final bool isCurrentStatus = _task.status == status.name;

    return ElevatedButton(
      onPressed: isCurrentStatus
          ? null
          : () => _updateTaskStatus(status.name),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrentStatus ? status.color : status.color.withOpacity(0.1),
        foregroundColor: isCurrentStatus ? Colors.white : status.color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(status.displayName),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la tâche'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette tâche ? Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _projectService.deleteTask(_task.id);
                if (widget.onTaskDeleted != null) {
                  widget.onTaskDeleted!(_task);
                }
                if (mounted) {
                  Navigator.pop(context, true); // Retourner à l'écran précédent avec un résultat
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression de la tâche: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Afficher un dialogue de chargement
  AlertDialog _showLoadingDialog(String message) {
    AlertDialog dialog = AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(message),
        ],
      ),
    );
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => dialog,
    );
    
    return dialog;
  }
}
