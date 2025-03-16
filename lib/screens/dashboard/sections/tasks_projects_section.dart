import 'package:flutter/material.dart';
import '../widgets/task_distribution_chart.dart';
import '../widgets/project_progress_chart.dart';
import '../widgets/task_timeline_chart.dart';
import '../models/dashboard_chart_models.dart';

class TasksProjectsSection extends StatelessWidget {
  final List<TaskDistributionData> tasksByStatusData;
  final List<TaskDistributionData> tasksByPriorityData;
  final List<ProjectProgressData> projectProgressData;
  final List<TaskTimelineData> upcomingTasksData;
  final Function(String)? onProjectTap;
  final Function(String)? onTaskTap;
  final VoidCallback? onSeeAllProjects;
  final VoidCallback? onSeeAllTasks;

  const TasksProjectsSection({
    Key? key,
    required this.tasksByStatusData,
    required this.tasksByPriorityData,
    required this.projectProgressData,
    required this.upcomingTasksData,
    this.onProjectTap,
    this.onTaskTap,
    this.onSeeAllProjects,
    this.onSeeAllTasks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    if (isSmallScreen) {
      // Layout pour petit écran (empilé verticalement)
      return Column(
        children: [
          SizedBox(
            height: 215,
            child: Row(
              children: [
                Expanded(
                  child: TaskDistributionChart(
                    data: tasksByStatusData,
                    title: 'Tâches par statut',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TaskDistributionChart(
                    data: tasksByPriorityData,
                    title: 'Tâches par priorité',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 165,
            child: ProjectProgressChart(
              data: projectProgressData,
              title: 'Progression des projets',
              onSeeAllPressed: onSeeAllProjects,
              onProjectTap: onProjectTap,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 185,
            child: TaskTimelineChart(
              data: upcomingTasksData,
              title: 'Tâches à venir',
              onSeeAllPressed: onSeeAllTasks,
              onTaskTap: onTaskTap,
            ),
          ),
        ],
      );
    } else {
      // Layout pour grand écran (plus de colonnes)
      return Column(
        children: [
          SizedBox(
            height: 235,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: TaskTimelineChart(
                    data: upcomingTasksData,
                    title: 'Tâches à venir',
                    onSeeAllPressed: onSeeAllTasks,
                    onTaskTap: onTaskTap,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TaskDistributionChart(
                    data: tasksByStatusData,
                    title: 'Tâches par statut',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TaskDistributionChart(
                    data: tasksByPriorityData,
                    title: 'Tâches par priorité',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 235,
            child: ProjectProgressChart(
              data: projectProgressData,
              title: 'Progression des projets',
              onSeeAllPressed: onSeeAllProjects,
              onProjectTap: onProjectTap,
            ),
          ),
        ],
      );
    }
  }
}
