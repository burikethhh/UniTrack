import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../providers/providers.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/user_model.dart';

/// Analytics Tab - Charts and detailed statistics
class AnalyticsTab extends StatelessWidget {
  final AdminProvider adminProvider;

  const AnalyticsTab({super.key, required this.adminProvider});

  @override
  Widget build(BuildContext context) {
    final stats = adminProvider.statistics;
    final allUsers = adminProvider.allUsers;
    final theme = Theme.of(context);

    // Compute time-series data from all users
    final registrationTrend = _computeRegistrationTrend(allUsers);
    final activeUsersTrend = _computeActiveUsersTrend(allUsers);
    final retentionMetrics = _computeRetentionMetrics(allUsers);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Distribution Pie Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Distribution',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: stats.totalUsers == 0
                        ? const Center(child: Text('No users yet'))
                        : PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  value: stats.totalStudents.toDouble(),
                                  title: '${stats.totalStudents}',
                                  color: Colors.blue,
                                  radius: 55,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.totalStudentLeaders.toDouble(),
                                  title: '${stats.totalStudentLeaders}',
                                  color: Colors.green,
                                  radius: 55,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.totalOrgOfficers.toDouble(),
                                  title: '${stats.totalOrgOfficers}',
                                  color: Colors.orange,
                                  radius: 55,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: stats.totalAdmins.toDouble(),
                                  title: '${stats.totalAdmins}',
                                  color: Colors.purple,
                                  radius: 55,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _ChartLegend(color: Colors.blue, label: 'Students'),
                      _ChartLegend(
                          color: Colors.green, label: 'Student Leaders'),
                      _ChartLegend(
                          color: Colors.orange, label: 'Org Officers'),
                      _ChartLegend(color: Colors.purple, label: 'Admins'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Department Distribution Pie Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Users by Department',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (stats.usersByDepartment.isEmpty ||
                      stats.usersByDepartment.values.every((v) => v == 0))
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No department data available'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                          sections: stats.usersByDepartment.entries
                              .take(8)
                              .toList()
                              .asMap()
                              .entries
                              .map((e) {
                            final color =
                                Colors.primaries[e.value.key.hashCode %
                                    Colors.primaries.length];
                            return PieChartSectionData(
                              value: e.value.value.toDouble(),
                              title: '${e.value.value}',
                              color: color,
                              radius: 50,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          })
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children:
                          stats.usersByDepartment.entries.take(8).map((entry) {
                        final color =
                            Colors.primaries[entry.key.hashCode %
                                Colors.primaries.length];
                        return _ChartLegend(
                          color: color,
                          label: entry.key.length > 20
                              ? '${entry.key.substring(0, 18)}...'
                              : entry.key,
                        );
}).toList(),
                     ),
                   ],
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

          // Users by Campus Bar Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Users by Campus',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (stats.usersByCampus.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No campus data available'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY:
                              (stats.usersByCampus.values.isEmpty
                                      ? 1
                                      : stats.usersByCampus.values.reduce(
                                          (a, b) => a > b ? a : b,
                                        ))
                                  .toDouble() *
                              1.2,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final campus = stats.usersByCampus.keys
                                    .elementAt(group.x.toInt());
                                return BarTooltipItem(
                                  '${formatCampusName(campus)}\n${rod.toY.toInt()} users',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 ||
                                      idx >= stats.usersByCampus.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final campus = stats.usersByCampus.keys
                                      .elementAt(idx);
                                  final shortName = campus.length > 6
                                      ? '${campus.substring(0, 5)}.'
                                      : campus;
                                  return Text(
                                    shortName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            horizontalInterval: 5,
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: stats.usersByCampus.entries
                              .toList()
                              .asMap()
                              .entries
                              .map((e) {
                            final color =
                                Colors.primaries[e.value.key.hashCode %
                                    Colors.primaries.length];
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.value.toDouble(),
                                  color: color,
                                  width: 22,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ],
                            );
                          })
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Registration Trends - Line Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registration Trends (Last 30 Days)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: registrationTrend.isEmpty
                        ? const Center(child: Text('No registration data'))
                        : LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: (registrationTrend.length - 1).toDouble(),
                              minY: 0,
                              maxY: (_getMaxY(registrationTrend) * 1.2).clamp(1.0, double.infinity),
                              gridData: FlGridData(
                                drawVerticalLine: true,
                                horizontalInterval: _getMaxY(registrationTrend) > 10 ? 5 : 1,
                                verticalInterval: registrationTrend.length > 10 ? 5 : 1,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey.shade300,
                                  strokeWidth: 1,
                                ),
                                getDrawingVerticalLine: (value) => FlLine(
                                  color: Colors.grey.shade300,
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= registrationTrend.length) {
                                        return const SizedBox.shrink();
                                      }
                                      // Show label every 3-5 days
                                      final showLabel = registrationTrend.length > 15
                                          ? idx % 5 == 0
                                          : idx % 3 == 0;
                                      if (!showLabel) return const SizedBox.shrink();
                                      final date = DateTime.now().subtract(Duration(days: registrationTrend.length - 1 - idx));
                                      return Text(
                                        DateFormat('MM/dd').format(date),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: registrationTrend
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.blue,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: registrationTrend.length <= 15,
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: Colors.blue,
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.blue.withAlpha(30),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Daily Active Users Trend - Line Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Active Users (Last 30 Days)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: activeUsersTrend.isEmpty
                        ? const Center(child: Text('No activity data'))
                        : LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: (activeUsersTrend.length - 1).toDouble(),
                              minY: 0,
                              maxY: _getMaxY(activeUsersTrend) * 1.2,
                              gridData: FlGridData(
                                drawVerticalLine: true,
                                horizontalInterval: _getMaxY(activeUsersTrend) > 10 ? 5 : 1,
                                verticalInterval: activeUsersTrend.length > 10 ? 5 : 1,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey.shade300,
                                  strokeWidth: 1,
                                ),
                                getDrawingVerticalLine: (value) => FlLine(
                                  color: Colors.grey.shade300,
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < 0 || idx >= activeUsersTrend.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final showLabel = activeUsersTrend.length > 15
                                          ? idx % 5 == 0
                                          : idx % 3 == 0;
                                      if (!showLabel) return const SizedBox.shrink();
                                      final date = DateTime.now().subtract(Duration(days: activeUsersTrend.length - 1 - idx));
                                      return Text(
                                        DateFormat('MM/dd').format(date),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: activeUsersTrend
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.green,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: activeUsersTrend.length <= 15,
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: Colors.green,
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.green.withAlpha(30),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Retention Metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retention Metrics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _RetentionChip(
                          label: 'Day 1 Retention',
                          value: '${retentionMetrics.day1Retention.toStringAsFixed(1)}%',
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RetentionChip(
                          label: 'Day 7 Retention',
                          value: '${retentionMetrics.day7Retention.toStringAsFixed(1)}%',
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _RetentionChip(
                          label: 'Day 30 Retention',
                          value: '${retentionMetrics.day30Retention.toStringAsFixed(1)}%',
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RetentionChip(
                          label: 'Churn Rate (30d)',
                          value: '${retentionMetrics.churnRate.toStringAsFixed(1)}%',
                          color: Colors.red,
),
                    ),
],
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Notification Analytics
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Analytics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.send,
                        label: 'Total Sent',
                        value: '${stats.totalNotifications}',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.mark_email_read,
                        label: 'Opened',
                        value: '${stats.openedNotifications}',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.delivery_dining,
                        label: 'Delivered',
                        value: '${stats.deliveredNotifications}',
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.percent,
                        label: 'Open Rate',
                        value: '${stats.openRate.toStringAsFixed(1)}%',
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.percent,
                        label: 'Delivery Rate',
                        value: '${stats.deliveryRate.toStringAsFixed(1)}%',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.analytics_outlined,
                        label: 'Sent',
                        value: '${stats.sentNotifications}',
                        color: Colors.purple,
                      ),
                    ),
],
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Activity Overview Stat Chips
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.today,
                          label: 'Active Today',
                          value: '${stats.activeToday}',
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.wifi,
                          label: 'Online Now',
                          value: '${stats.onlineNow}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.date_range,
                          label: 'New This Week',
                          value: '${stats.newUsersThisWeek}',
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.calendar_month,
                          label: 'New This Month',
                          value: '${stats.newUsersThisMonth}',
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compute registration trend for last 30 days
  List<int> _computeRegistrationTrend(List<UserModel> users) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 29));
    final Map<int, int> dailyCounts = {};

    // Initialize all days to 0
    for (int i = 0; i < 30; i++) {
      dailyCounts[i] = 0;
    }

    for (final user in users) {
      final createdAt = user.createdAt;
      if (createdAt.isAfter(thirtyDaysAgo) && createdAt.isBefore(now.add(const Duration(days: 1)))) {
        final diff = now.difference(createdAt).inDays;
        final index = 29 - diff.clamp(0, 29);
        if (index >= 0 && index < 30) {
          dailyCounts[index] = (dailyCounts[index] ?? 0) + 1;
        }
      }
    }

    return List<int>.generate(30, (i) => dailyCounts[i] ?? 0);
  }

  // Compute daily active users trend for last 30 days
  List<int> _computeActiveUsersTrend(List<UserModel> users) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 29));
    final Map<int, int> dailyCounts = {};

    for (int i = 0; i < 30; i++) {
      dailyCounts[i] = 0;
    }

    for (final user in users) {
      final lastLogin = user.lastLoginAt;
      if (lastLogin != null && lastLogin.isAfter(thirtyDaysAgo) && lastLogin.isBefore(now.add(const Duration(days: 1)))) {
        final diff = now.difference(lastLogin).inDays;
        final index = 29 - diff.clamp(0, 29);
        if (index >= 0 && index < 30) {
          dailyCounts[index] = (dailyCounts[index] ?? 0) + 1;
        }
      }
    }

    return List<int>.generate(30, (i) => dailyCounts[i] ?? 0);
  }

  // Compute retention metrics
  _RetentionMetrics _computeRetentionMetrics(List<UserModel> users) {
    final now = DateTime.now();
    final totalUsers = users.length;

    if (totalUsers == 0) {
      return _RetentionMetrics(
        day1Retention: 0,
        day7Retention: 0,
        day30Retention: 0,
        churnRate: 0,
      );
    }

    // Day 1 retention: users who logged in within 1 day of creation
    int day1Retained = 0;
    int day7Retained = 0;
    int day30Retained = 0;

    for (final user in users) {
      if (user.lastLoginAt != null) {
        final diffDays = user.lastLoginAt!.difference(user.createdAt).inDays;
        if (diffDays <= 1) day1Retained++;
        if (diffDays <= 7) day7Retained++;
        if (diffDays <= 30) day30Retained++;
      }
    }

    // For users who haven't logged in recently, check if they were active within 30 days of creation
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    int churned = 0;
    for (final user in users) {
      // User is churned if they haven't logged in for 30+ days since creation
      if (user.lastLoginAt == null) {
        if (user.createdAt.isBefore(thirtyDaysAgo)) churned++;
      } else if (now.difference(user.lastLoginAt!).inDays > 30) {
        churned++;
      }
    }

    return _RetentionMetrics(
      day1Retention: totalUsers > 0 ? (day1Retained / totalUsers * 100) : 0,
      day7Retention: totalUsers > 0 ? (day7Retained / totalUsers * 100) : 0,
      day30Retention: totalUsers > 0 ? (day30Retained / totalUsers * 100) : 0,
      churnRate: totalUsers > 0 ? (churned / totalUsers * 100) : 0,
    );
  }

  double _getMaxY(List<int> data) {
    if (data.isEmpty) return 10;
    final max = data.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _RetentionMetrics {
  final double day1Retention;
  final double day7Retention;
  final double day30Retention;
  final double churnRate;

  _RetentionMetrics({
    required this.day1Retention,
    required this.day7Retention,
    required this.day30Retention,
    required this.churnRate,
  });
}

class _RetentionChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RetentionChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
