import 'package:flutter/material.dart';

class ProgressTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const ProgressTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: columns
            .map((c) => DataColumn(label: Text(c,
                style: const TextStyle(fontWeight: FontWeight.bold))))
            .toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: row.map((cell) => DataCell(Text(cell))).toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}
