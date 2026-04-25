import 'package:flutter/material.dart';
import 'batch_detail_common_widgets.dart';

class BatchAnalyticsTab extends StatelessWidget {
  final List<double> attendanceTrend;
  final List<double> performanceTrend;
  final List<double> revenueTrend;

  const BatchAnalyticsTab({
    super.key,
    required this.attendanceTrend,
    required this.performanceTrend,
    required this.revenueTrend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('analytics-tab'),
      children: [
        sectionCard(
          context,
          title: 'Attendance Graph',
          child: _miniBarGraph(attendanceTrend, const Color(0xFF354388)),
        ),
        sectionCard(
          context,
          title: 'Performance Graph',
          child: _miniBarGraph(performanceTrend, const Color(0xFFE5A100)),
        ),
        sectionCard(
          context,
          title: 'Revenue Graph',
          child: _miniBarGraph(revenueTrend, const Color(0xFFB6231B)),
        ),
      ],
    );
  }

  Widget _miniBarGraph(List<double> values, Color color) {
    final fixed = values.isEmpty ? [0.0] : values;
    final maxValue = fixed.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: fixed.map((value) {
          final height = maxValue <= 0
              ? 6.0
              : ((value / maxValue) * 70).clamp(6, 70).toDouble();
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
