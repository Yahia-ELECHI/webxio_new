import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';

class ProjectService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Récupère tous les projets
  Future<List<Project>> getProjects() async {
    try {
      final response = await _supabase
          .from('projects')
          .select()
          .order('created_at', ascending: false);

      return response.map<Project>((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des projets: $e');
      return [];
    }
  }

  // Récupère un projet spécifique par son ID
  Future<Project?> getProjectById(String projectId) async {
    try {
      final response = await _supabase
          .from('projects')
          .select()
          .eq('id', projectId)
          .single();

      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération du projet: $e');
      return null;
    }
  }

  // Crée un nouveau projet
  Future<Project?> createProject(Project project) async {
    try {
      final response = await _supabase
          .from('projects')
          .insert(project.toJson())
          .select()
          .single();

      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la création du projet: $e');
      return null;
    }
  }

  // Met à jour un projet existant
  Future<Project?> updateProject(Project project) async {
    try {
      final response = await _supabase
          .from('projects')
          .update(project.toJson())
          .eq('id', project.id)
          .select()
          .single();

      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la mise à jour du projet: $e');
      return null;
    }
  }

  // Supprime un projet
  Future<bool> deleteProject(String projectId) async {
    try {
      await _supabase.from('projects').delete().eq('id', projectId);
      return true;
    } catch (e) {
      print('Erreur lors de la suppression du projet: $e');
      return false;
    }
  }

  // Récupère les projets créés par l'utilisateur actuel
  Future<List<Project>> getProjectsByUser() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('projects')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      return response.map<Project>((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des projets de l\'utilisateur: $e');
      return [];
    }
  }

  // Récupère tous les projets, y compris ceux où l'utilisateur est collaborateur
  Future<List<Project>> getAllProjects() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Récupérer les projets où l'utilisateur est soit créateur, soit membre de l'équipe
      final response = await _supabase
          .from('projects')
          .select()
          .or('created_by.eq.$userId,team_members.cs.{$userId}')
          .order('created_at', ascending: false);

      return response.map<Project>((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération de tous les projets: $e');
      return [];
    }
  }

  // Met à jour le budget alloué et consommé d'un projet
  Future<bool> updateProjectBudget(String projectId, double? budgetAllocated, double? budgetConsumed) async {
    try {
      await _supabase
          .from('projects')
          .update({
            'budget_allocated': budgetAllocated,
            'budget_consumed': budgetConsumed,
          })
          .eq('id', projectId);
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget du projet: $e');
      return false;
    }
  }
}
