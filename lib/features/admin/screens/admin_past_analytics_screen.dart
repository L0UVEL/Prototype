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
  String _selectedFilter = 'Daily';

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

  /// Get the date range based on the selected filter.
  ({DateTime start, DateTime end}) _getDateRange() {
    switch (_selectedFilter) {
      case 'Weekly':
        // Get the Monday of the week containing the selected date
        final weekday = _selectedDate.weekday; // 1=Mon, 7=Sun
        final monday = _selectedDate.subtract(Duration(days: weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        // Clamp end to yesterday at most
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final clampedEnd = sunday.isAfter(yesterday) ? yesterday : sunday;
        return (start: monday, end: clampedEnd);
      case 'Quarterly':
        // Quarter: Q1=Jan-Mar, Q2=Apr-Jun, Q3=Jul-Sep, Q4=Oct-Dec
        final quarterMonth = ((_selectedDate.month - 1) ~/ 3) * 3 + 1;
        final quarterStart = DateTime(_selectedDate.year, quarterMonth, 1);
        final quarterEnd = DateTime(_selectedDate.year, quarterMonth + 3, 0);
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final clampedEnd = quarterEnd.isAfter(yesterday) ? yesterday : quarterEnd;
        return (start: quarterStart, end: clampedEnd);
      default: // Daily
        return (start: _selectedDate, end: _selectedDate);
    }
  }

  /// Get a display label for the current date range.
  String _getDateRangeLabel() {
    final range = _getDateRange();
    switch (_selectedFilter) {
      case 'Weekly':
        return '${DateFormat('MMM d').format(range.start)} – ${DateFormat('MMM d, y').format(range.end)}';
      case 'Quarterly':
        final quarter = ((range.start.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${range.start.year} (${DateFormat('MMM').format(range.start)} – ${DateFormat('MMM').format(range.end)})';
      default:
        return DateFormat('EEEE, MMMM d, y').format(_selectedDate);
    }
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final healthService = context.read<HealthService>();

      List<Map<String, dynamic>> aggregatedSnapshot;

      if (_selectedFilter == 'Daily') {
        // Single day — existing behavior
        aggregatedSnapshot = await healthService.getHealthSnapshotForDate(_selectedDate);
      } else {
        // Multi-day aggregation (Weekly or Quarterly)
        final range = _getDateRange();
        List<DateTime> datesToSample = [];

        if (_selectedFilter == 'Weekly') {
          // Sample every day in the week
          var current = range.start;
          while (!current.isAfter(range.end)) {
            datesToSample.add(current);
            current = current.add(const Duration(days: 1));
          }
        } else {
          // Quarterly: sample one day per week to keep performance manageable
          var current = range.start;
          while (!current.isAfter(range.end)) {
            datesToSample.add(current);
            current = current.add(const Duration(days: 7));
          }
          // Always include the last day of the range
          if (datesToSample.isEmpty || datesToSample.last != range.end) {
            datesToSample.add(range.end);
          }
        }

        // Fetch snapshots for all sampled dates
        final List<List<Map<String, dynamic>>> allSnapshots = [];
        for (var date in datesToSample) {
          final snapshot = await healthService.getHealthSnapshotForDate(date);
          allSnapshots.add(snapshot);
        }

        // Aggregate: for each student, pick the worst status across all days
        aggregatedSnapshot = _aggregateSnapshots(allSnapshots);
      }

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

      for (var entry in aggregatedSnapshot) {
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
          _snapshot = aggregatedSnapshot;
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

  /// Aggregates multiple daily snapshots into one.
  /// For each student, the worst status across all days is kept.
  /// Priority: At Risk > Missed Check-in > Healthy > No Data
  List<Map<String, dynamic>> _aggregateSnapshots(
    List<List<Map<String, dynamic>>> allSnapshots,
  ) {
    // Map studentId -> best (worst) entry
    final Map<String, Map<String, dynamic>> studentMap = {};

    int statusPriority(String status) {
      switch (status) {
        case 'At Risk':
          return 3;
        case 'Missed Check-in':
          return 2;
        case 'Healthy':
          return 1;
        case 'No Data':
        default:
          return 0;
      }
    }

    for (var snapshot in allSnapshots) {
      for (var entry in snapshot) {
        final student = entry['student'] as User;
        final status = entry['status'] as String;
        final existing = studentMap[student.id];

        if (existing == null ||
            statusPriority(status) > statusPriority(existing['status'] as String)) {
          studentMap[student.id] = entry;
        }
      }
    }

    return studentMap.values.toList();
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
        return const Color(0xFFE65100);
      case 'No Data':
        return const Color(0xFF607D8B);
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
                  const SizedBox(height: 12),

                  // Filter Toggle (Daily / Weekly / Quarterly)
                  _buildFilterToggle(),
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
                        _getStatusColor('At Risk'),
                      ),
                      _buildSummaryCard(
                        'Missed Check-in',
                        _statusCounts['Missed Check-in'].toString(),
                        Icons.schedule,
                        _getStatusColor('Missed Check-in'),
                      ),
                      _buildSummaryCard(
                        'Healthy',
                        _statusCounts['Healthy'].toString(),
                        Icons.check_circle,
                        _getStatusColor('Healthy'),
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
                      _getStatusColor('At Risk'),
                      Icons.warning,
                    ),
                  if (_monitorStudents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStudentCategorySection(
                      'Missed Check-in',
                      _monitorStudents,
                      _getStatusColor('Missed Check-in'),
                      Icons.schedule,
                    ),
                  ],
                  if (_healthyStudents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStudentCategorySection(
                      'Healthy',
                      _healthyStudents,
                      _getStatusColor('Healthy'),
                      Icons.check_circle,
                    ),
                  ],
                  if (_noDataStudents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStudentCategorySection(
                      'No Data',
                      _noDataStudents,
                      _getStatusColor('No Data'),
                      Icons.help_outline,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'Daily',
            label: Text('Daily'),
            icon: Icon(Icons.today, size: 18),
          ),
          ButtonSegment(
            value: 'Weekly',
            label: Text('Weekly'),
            icon: Icon(Icons.date_range, size: 18),
          ),
          ButtonSegment(
            value: 'Quarterly',
            label: Text('Quarterly'),
            icon: Icon(Icons.calendar_view_month, size: 18),
          ),
        ],
        selected: {_selectedFilter},
        onSelectionChanged: (Set<String> selection) {
          setState(() {
            _selectedFilter = selection.first;
          });
          _loadSnapshot();
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF800000);
              }
              return Colors.transparent;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return Colors.grey.shade700;
            },
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          side: WidgetStateProperty.all(BorderSide.none),
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
                    _selectedFilter == 'Daily'
                        ? 'Viewing Analytics For'
                        : 'Viewing $_selectedFilter Analytics',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDateRangeLabel(),
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
