import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/health_service.dart';
import '../../../core/models/user_model.dart';

class AdminPastAnalyticsScreen extends StatefulWidget {
  const AdminPastAnalyticsScreen({super.key});

  @override
  State<AdminPastAnalyticsScreen> createState() =>
      _AdminPastAnalyticsScreenState();
}

class _AdminPastAnalyticsScreenState extends State<AdminPastAnalyticsScreen> {
  late DateTime _selectedDate;
  bool _isLoading = true;
  List<Map<String, dynamic>> _snapshot = [];

  // Computed counts
  Map<String, int> _statusCounts = {
    'Healthy': 0,
    'At Risk': 0,
    'Missed Check-in': 0,
    'No Data': 0,
  };

  // Grouped student lists
  List<Map<String, dynamic>> _atRiskStudents = [];
  List<Map<String, dynamic>> _monitorStudents = [];
  List<Map<String, dynamic>> _healthyStudents = [];
  List<Map<String, dynamic>> _noDataStudents = [];

  @override
  void initState() {
    super.initState();
    // Default to yesterday
    _selectedDate = DateTime.now().subtract(const Duration(days: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSnapshot();
    });
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final healthService = context.read<HealthService>();
      final snapshot = await healthService.getHealthSnapshotForDate(_selectedDate);

      final Map<String, int> counts = {
        'Healthy': 0,
        'At Risk': 0,
        'Missed Check-in': 0,
        'No Data': 0,
      };

      final List<Map<String, dynamic>> atRisk = [];
      final List<Map<String, dynamic>> monitor = [];
      final List<Map<String, dynamic>> healthy = [];
      final List<Map<String, dynamic>> noData = [];

      for (var entry in snapshot) {
        final status = entry['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;

        switch (status) {
          case 'At Risk':
            atRisk.add(entry);
            break;
          case 'Missed Check-in':
            monitor.add(entry);
            break;
          case 'Healthy':
            healthy.add(entry);
            break;
          default:
            noData.add(entry);
        }
      }

      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _statusCounts = counts;
          _atRiskStudents = atRisk;
          _monitorStudents = monitor;
          _healthyStudents = healthy;
          _noDataStudents = noData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().subtract(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF800000),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2D2D2D),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadSnapshot();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Healthy':
        return const Color(0xFF388E3C);
      case 'At Risk':
        return const Color(0xFFD32F2F);
      case 'Missed Check-in':
        return const Color(0xFFFFA000);
      case 'No Data':
        return const Color(0xFF9E9E9E);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = _snapshot.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      appBar: AppBar(
        title: const Text(
          'Past Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Selector Card
                  _buildDateSelector(),
                  const SizedBox(height: 20),

                  // Summary Cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildSummaryCard(
                        'Total Students',
                        totalStudents.toString(),
                        Icons.people,
                        const Color(0xFF800000),
                      ),
                      _buildSummaryCard(
                        'At Risk',
                        _statusCounts['At Risk'].toString(),
                        Icons.warning,
                        const Color(0xFFD32F2F),
                      ),
                      _buildSummaryCard(
                        'Missed Check-in',
                        _statusCounts['Missed Check-in'].toString(),
                        Icons.visibility,
                        const Color(0xFFFFA000),
                      ),
                      _buildSummaryCard(
                        'Healthy',
                        _statusCounts['Healthy'].toString(),
                        Icons.check_circle,
                        const Color(0xFF388E3C),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pie Chart
                  _buildPieChart(totalStudents),
                  const SizedBox(height: 24),

                  // Student lists by category
                  if (_atRiskStudents.isNotEmpty)
                    _buildStudentCategorySection(
                      'At Risk',
                      _atRiskStudents,
                      const Color(0xFFD32F2F),
                      Icons.warning,
                    ),
                  if (_monitorStudents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStudentCategorySection(
                      'Missed Check-in',
                      _monitorStudents,
                      const Color(0xFFFFA000),
                      Icons.visibility,
                    ),
                  ],
                  if (_healthyStudents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStudentCategorySection(
                      'Healthy',
                      _healthyStudents,
                      const Color(0xFF388E3C),
                      Icons.check_circle,
                    ),
                  ],
                  if (_noDataStudents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStudentCategorySection(
                      'No Data',
                      _noDataStudents,
                      const Color(0xFF9E9E9E),
                      Icons.help_outline,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF800000), Color(0xFF5C0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF800000).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viewing Analytics For',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_calendar,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(int totalStudents) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF800000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pie_chart,
                    size: 20,
                    color: Color(0xFF800000),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Status Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: _statusCounts.entries
                      .where((entry) => entry.value > 0)
                      .map((entry) {
                    return PieChartSectionData(
                      color: _getStatusColor(entry.key),
                      value: entry.value.toDouble(),
                      title:
                          '${((entry.value / (totalStudents == 0 ? 1 : totalStudents)) * 100).toStringAsFixed(1)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12.0,
              runSpacing: 8.0,
              children: _statusCounts.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(entry.key),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key} (${entry.value})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCategorySection(
    String title,
    List<Map<String, dynamic>> students,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: title == 'At Risk',
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          title: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${students.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            ...students.map((entry) {
              final student = entry['student'] as User;
              final description = entry['description'] as String;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.person, color: color, size: 20),
                ),
                title: Text(
                  student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.studentId} • ${student.program ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                onTap: () {
                  context.go('/admin/student/${student.id}');
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
