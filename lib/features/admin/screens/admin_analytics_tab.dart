import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/report_helper_stub.dart'
    if (dart.library.io) '../../../core/utils/report_helper_io.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/ai_service.dart';
import 'admin_past_analytics_screen.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  Timer? _updateTimer;
  String _aiSummary = "Analyzing data...";
  String _lastDataHash = "";
  bool _isAnalyzing = false;
  List<dynamic> _reports = [];

  // State for analytics
  int _totalStudents = 0;
  Map<String, int> _statusCounts = {
    'Healthy': 0,
    'At Risk': 0,
    'Monitor': 0,
    'No Data': 0,
  };
  Map<String, int> _programCounts = {};
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
    // Initial analysis
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAnalyzeData();
    });

    // Auto-update every minute
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndAnalyzeData();
      _loadReports(); // Also refresh reports list periodically
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReports() async {
    if (kIsWeb) return;
    final files = await listHealthReports();
    if (mounted) {
      setState(() {
        _reports = files;
      });
    }
  }

  Future<void> _exportReport(dynamic file) async {
    if (kIsWeb) return;
    await exportHealthReport(file);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report exported to Downloads')),
      );
    }
  }

  Future<void> _checkAndAnalyzeData() async {
    if (!mounted) return;

    final healthService = context.read<HealthService>();

    try {
      final students = await healthService.getStudentsStream().first;
      final totalStudents = students.length;

      final Map<String, int> statusCounts = {
        'Healthy': 0,
        'At Risk': 0,
        'Monitor': 0,
        'No Data': 0,
      };
      final Map<String, int> programCounts = {};

      // Fetch logs for each student to calculate status
      for (var student in students) {
        final logs = await healthService.getDailyLogsStream(student.id).first;
        final statusData = healthService.calculateStudentStatus(logs);
        final status = statusData['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final program = student.program ?? 'Unknown';
        programCounts[program] = (programCounts[program] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _totalStudents = totalStudents;
          _statusCounts = statusCounts;
          _programCounts = programCounts;
          _isLoadingData = false;
        });
      }

      // Create a simple hash/string of the current data state to detect changes
      final currentDataHash =
          "Total:$totalStudents|Healthy:${statusCounts['Healthy']}|AtRisk:${statusCounts['At Risk']}|Monitor:${statusCounts['Monitor']}";

      if (currentDataHash != _lastDataHash) {
        _lastDataHash = currentDataHash;
        await _generateAISummary(totalStudents, statusCounts);
      }
    } catch (e) {
      debugPrint("Error analyzing data: $e");
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _generateAISummary(int total, Map<String, int> counts) async {
    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _aiSummary = "Updating analysis...";
    });

    try {
      final prompt =
          """
      Analyze the following student health data for a school dashboard.
      Total Students: $total
      Healthy: ${counts['Healthy']}
      At Risk: ${counts['At Risk']}
      Monitor: ${counts['Monitor']}
      No Data: ${counts['No Data']}
      
      Provide a 2-sentence summary of the overall health status of the student population.
      Focus on critical areas (At Risk/Monitor). Keep it professional and concise.
      """;

      final response = await context.read<AIService>().getResponse(prompt);

      if (mounted) {
        setState(() {
          _aiSummary = response;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSummary = "Unable to generate analysis at this time.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthService>(
      builder: (context, healthService, child) {
        if (_isLoadingData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Use cached state
        final totalStudents = _totalStudents;
        final statusCounts = _statusCounts;
        final programCounts = _programCounts;

        // Helper for status color
        Color getStatusColor(String status) {
          switch (status) {
            case 'Healthy':
              return const Color(0xFF388E3C);
            case 'At Risk':
              return const Color(0xFFD32F2F);
            case 'Monitor':
              return const Color(0xFFFFA000);
            case 'No Data':
              return const Color(0xFF9E9E9E);
            default:
              return Colors.grey;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Summary Card
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Health Analysis',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_isAnalyzing) ...[
                            const Spacer(),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _aiSummary,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Updates automatically every minute',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Past Analytics Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminPastAnalyticsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF800000).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.history,
                          color: Color(0xFF800000),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'View Past Analytics',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Browse historical health status data by date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildSummaryCard(
                    context,
                    'Total Students',
                    totalStudents.toString(),
                    Icons.people,
                    const Color(0xFF800000),
                  ),
                  _buildSummaryCard(
                    context,
                    'At Risk',
                    statusCounts['At Risk'].toString(),
                    Icons.warning,
                    Colors.red,
                  ),
                  _buildSummaryCard(
                    context,
                    'Monitor',
                    statusCounts['Monitor'].toString(),
                    Icons.visibility,
                    Colors.orange,
                  ),
                  _buildSummaryCard(
                    context,
                    'Healthy',
                    statusCounts['Healthy'].toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Status Distribution Chart (Pie Chart)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Health Status Distribution',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 40,
                            sections: statusCounts.entries.map((entry) {
                              return PieChartSectionData(
                                color: getStatusColor(entry.key),
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
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: statusCounts.entries.map((entry) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: getStatusColor(entry.key),
                              ),
                              const SizedBox(width: 4),
                              Text(entry.key),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Program Distribution
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Students per Program',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...programCounts.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value:
                                      entry.value /
                                      (totalStudents == 0 ? 1 : totalStudents),
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(entry.value.toString()),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              if (!kIsWeb) ...[
                const SizedBox(height: 24),
                Text(
                  'Generated Reports',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
              ],

              // Existing Reports List (retained)
              if (!kIsWeb)
                _reports.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No reports generated yet.'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final filename = report['name'];
                          final modified = report['modified'];

                          return Card(
                            child: ListTile(
                              onTap: () => _exportReport(report['entity']),
                              leading: const Icon(
                                Icons.description,
                                color: Color(0xFF800000),
                              ),
                              title: Text(filename),
                              subtitle: Text(
                                'Tap to export • ${DateFormat('MMM d, HH:mm').format(modified)}',
                              ),
                              trailing: const Icon(
                                Icons.file_download,
                                color: Color(0xFF800000),
                              ),
                            ),
                          );
                        },
                      ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
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
            ),
          ],
        ),
      ),
    );
  }
}
