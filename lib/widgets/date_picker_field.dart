import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerField extends StatelessWidget {
  final DateTime date;
  final void Function(DateTime) onChanged;
  final String label;

  const DatePickerField({
    super.key,
    required this.date,
    required this.onChanged,
    this.label = 'Date',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(9999, 12, 31),
          selectableDayPredicate: null,
          currentDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(DateFormat('dd/MM/yy').format(date)),
      ),
    );
  }
}
