import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/ai_service.dart';

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
  List<FileSystemEntity> _reports = [];

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
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (directory.existsSync()) {
        final files = directory.listSync().where((file) {
          return file.path.endsWith('.csv') &&
              file.path.contains('Student_Health_Report');
        }).toList();

        files.sort((a, b) {
          return b.statSync().modified.compareTo(
            a.statSync().modified,
          ); // Newest first
        });

        if (mounted) {
          setState(() {
            _reports = files;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }
  }

  Future<void> _exportReport(FileSystemEntity file) async {
    try {
      final filename = file.uri.pathSegments.last;
      String newPath;

      if (Platform.isAndroid) {
        newPath = '/storage/emulated/0/Download/$filename';
      } else {
        // Desktop fallback
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          newPath = '${downloadsDir.path}${Platform.pathSeparator}$filename';
        } else {
          throw Exception('Could not find downloads directory');
        }
      }

      await File(file.path).copy(newPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to Downloads: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI Health Analysis',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (_isAnalyzing) ...[
                            const Spacer(),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _aiSummary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updates automatically every minute',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Summary Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildSummaryCard(
                    context,
                    'Total Students',
                    totalStudents.toString(),
                    Icons.people,
                    Colors.blue,
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

              const SizedBox(height: 24),
              Text(
                'Generated Reports',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),

              // Existing Reports List (retained)
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
                        final file = _reports[index];
                        final filename = file.uri.pathSegments.last;
                        final stat = file.statSync();

                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.description,
                              color: Colors.blue,
                            ),
                            title: Text(filename),
                            subtitle: Text(
                              'Created: ${DateFormat('MMM d, HH:mm').format(stat.modified)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.file_download),
                              tooltip: 'Export to Downloads',
                              onPressed: () => _exportReport(file),
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
