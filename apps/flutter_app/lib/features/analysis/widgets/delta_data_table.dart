import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analysis_provider.dart';

class DeltaDataTable extends ConsumerWidget {
  const DeltaDataTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceDeltasAsync = ref.watch(priceDeltasProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222938), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Price Monitor / مراقب الأسعار الحي',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () {},
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () {},
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF222938)),
          priceDeltasAsync.when(
            data: (deltas) {
              return Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: const Color(0xFF222938),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                    ),
                    dataRowMaxHeight: 64,
                    dataRowMinHeight: 64,
                    columns: const [
                      DataColumn(label: Text('Competitor')),
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Old Price')),
                      DataColumn(label: Text('New Price')),
                      DataColumn(label: Text('Delta')),
                      DataColumn(label: Text('Last Updated')),
                      DataColumn(label: Text('Source')),
                    ],
                    rows: deltas.map((delta) {
                      final isZeroDelta = delta.oldPrice == delta.newPrice;
                      
                      final deltaColor = isZeroDelta 
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                          : (delta.isIncrease ? Colors.redAccent : Colors.greenAccent);

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      delta.competitorName[0],
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  delta.competitorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(delta.productName)),
                          DataCell(
                            Text(
                              '${delta.oldPrice.toStringAsFixed(0)} SAR',
                              style: TextStyle(
                                decoration: !isZeroDelta ? TextDecoration.lineThrough : null,
                                color: !isZeroDelta 
                                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5) 
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${delta.newPrice.toStringAsFixed(0)} SAR',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: deltaColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isZeroDelta)
                                    Icon(
                                      delta.isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                                      size: 14,
                                      color: deltaColor,
                                    ),
                                  if (!isZeroDelta) const SizedBox(width: 4),
                                  Text(
                                    '${delta.deltaPercentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: deltaColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${DateTime.now().difference(delta.lastUpdatedAt).inMinutes} min ago',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 16),
                              onPressed: () {},
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error: $err'),
            ),
          ),
        ],
      ),
    );
  }
}
