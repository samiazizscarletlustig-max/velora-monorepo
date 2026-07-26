import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/analytics_chart.dart';
import 'widgets/ai_analyst_panel.dart';
import 'widgets/delta_data_table.dart';
import 'providers/analysis_provider.dart';

class CompetitorAnalysisHub extends ConsumerStatefulWidget {
  const CompetitorAnalysisHub({super.key});

  @override
  ConsumerState<CompetitorAnalysisHub> createState() => _CompetitorAnalysisHubState();
}

class _CompetitorAnalysisHubState extends ConsumerState<CompetitorAnalysisHub> {
  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(competitorMetricsProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Row(
        children: [
          // If we had a global side nav, it would go here.
          // For now, we assume this is the main content area.
          Expanded(
            child: Column(
              children: [
                _buildHeader(context),
                const Divider(height: 1, color: Color(0xFF222938)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Chart Section
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B26),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF222938), width: 1),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Market Share Trend / اتجاه الحصة السوقية',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 32),
                              metricsAsync.when(
                                data: (metrics) {
                                  // Convert to ChartSeries
                                  final seriesList = metrics.map((m) {
                                    Color c;
                                    if (m.name.contains('Noon')) c = Colors.yellowAccent;
                                    else if (m.name.contains('Amazon')) c = Colors.blueAccent;
                                    else c = Colors.redAccent;

                                    return ChartSeries(
                                      name: m.name,
                                      color: c,
                                      data: m.historicalMarketShare.map((dp) {
                                        return ChartDataPoint(
                                          x: dp.date.millisecondsSinceEpoch.toDouble(),
                                          y: dp.value,
                                          xLabel: '${dp.date.day}/${dp.date.month}',
                                          yLabel: '${dp.value}%',
                                        );
                                      }).toList(),
                                    );
                                  }).toList();

                                  return AnalyticsChart(
                                    series: seriesList,
                                    height: 350,
                                  );
                                },
                                loading: () => const SizedBox(
                                  height: 350,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                                error: (err, stack) => SizedBox(
                                  height: 350,
                                  child: Center(child: Text('Error: $err')),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Split Layout for Desktop: AI Analyst (Right/Left) + Data Table
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                flex: 2,
                                child: DeltaDataTable(),
                              ),
                              const SizedBox(width: 32),
                              const Expanded(
                                flex: 1,
                                child: AiAnalystPanel(),
                              ),
                            ],
                          )
                        else
                          // Stacked for tablet/mobile
                          const Column(
                            children: [
                              DeltaDataTable(),
                              SizedBox(height: 32),
                              AiAnalystPanel(),
                            ],
                          ),
                          
                        const SizedBox(height: 64), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1A),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Analysis Hub',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                ),
                child: Text(
                  'BETA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.language),
                onPressed: () {
                  // TODO: Toggle language
                },
                tooltip: 'Toggle RTL/LTR',
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Run Diagnostics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
