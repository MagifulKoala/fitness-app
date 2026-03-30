import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/set_child.dart';

class SetRowWidget extends StatefulWidget {
  final SetChild set;
  final void Function(SetChild updated) onChanged;
  final VoidCallback onDelete;

  const SetRowWidget({
    super.key,
    required this.set,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<SetRowWidget> createState() => _SetRowWidgetState();
}

class _SetRowWidgetState extends State<SetRowWidget> {
  late TextEditingController _repsCtrl;
  late TextEditingController _weightCtrl;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _repsCtrl =
        TextEditingController(text: widget.set.reps.toString());
    _weightCtrl =
        TextEditingController(text: widget.set.weight.toString());
    _unit = widget.set.unit;
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final reps = int.tryParse(_repsCtrl.text) ?? widget.set.reps;
    final weight =
        double.tryParse(_weightCtrl.text) ?? widget.set.weight;
    widget.onChanged(widget.set.copyWith(
      reps: reps,
      weight: weight,
      unit: _unit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _repsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Reps',
              isDense: true,
            ),
            onChanged: (_) => _notify(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _weightCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Weight',
              isDense: true,
            ),
            onChanged: (_) => _notify(),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _unit,
          items: const [
            DropdownMenuItem(value: 'kg', child: Text('kg')),
            DropdownMenuItem(value: 'lbs', child: Text('lbs')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _unit = v);
              _notify();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: widget.onDelete,
          tooltip: 'Remove set',
        ),
      ],
    );
  }
}
