import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/dashboard_chart_models.dart';

class TaskDistributionChart extends StatelessWidget {
  final List<TaskDistributionData> data;
  final String title;
  final bool showLabels;
  final bool animate;

  const TaskDistributionChart({
    Key? key,
    required this.data,
    required this.title,
    this.showLabels = true,
    this.animate = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: data.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune donnée disponible',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 171, 170, 170),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : _buildPieChart(),
            ),
            if (showLabels) const SizedBox(height: 8),
            if (showLabels) _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            // Logique pour gérer les interactions
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: _buildSections(),
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final total = data.fold<int>(0, (sum, item) => sum + item.count);
    
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final percentage = total > 0 ? (item.count / total) * 100 : 0;
      
      return PieChartSectionData(
        color: item.color,
        value: item.count.toDouble(),
        title: percentage >= 10 ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: 20,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 73, 72, 72),
        ),
      );
    }).toList();
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 7,
      children: data.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${item.label} (${item.count})',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[800],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
