import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';

class TaskService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Récupère toutes les tâches
  Future<List<Task>> getAllTasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .order('created_at', ascending: false);

      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches: $e');
      return [];
    }
  }

  // Récupère les tâches associées à l'utilisateur actuel
  Future<List<Task>> getTasksByUser() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('assigned_to', userId)
          .order('created_at', ascending: false);

      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de l\'utilisateur: $e');
      return [];
    }
  }

  // Récupère les tâches associées à un projet spécifique
  Future<List<Task>> getTasksByProject(String projectId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches du projet: $e');
      return [];
    }
  }

  // Récupère les tâches associées à une phase spécifique
  Future<List<Task>> getTasksByPhase(String phaseId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('phase_id', phaseId)
          .order('created_at', ascending: false);

      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de la phase: $e');
      return [];
    }
  }

  // Crée une nouvelle tâche
  Future<Task?> createTask(Task task) async {
    try {
      final response = await _supabase
          .from('tasks')
          .insert(task.toJson())
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Erreur lors de la création de la tâche: $e');
      return null;
    }
  }

  // Met à jour une tâche existante
  Future<Task?> updateTask(Task task) async {
    try {
      final response = await _supabase
          .from('tasks')
          .update(task.toJson())
          .eq('id', task.id)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Erreur lors de la mise à jour de la tâche: $e');
      return null;
    }
  }

  // Supprime une tâche
  Future<bool> deleteTask(String taskId) async {
    try {
      await _supabase.from('tasks').delete().eq('id', taskId);
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de la tâche: $e');
      return false;
    }
  }
}
