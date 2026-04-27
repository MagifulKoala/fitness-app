import 'package:flutter/material.dart';
import '../models/exercise_link.dart';

class LinkRowWidget extends StatefulWidget {
  final ExerciseLink link;
  final void Function(ExerciseLink) onChanged;
  final VoidCallback onDelete;

  const LinkRowWidget({
    super.key,
    required this.link,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<LinkRowWidget> createState() => _LinkRowWidgetState();
}

class _LinkRowWidgetState extends State<LinkRowWidget> {
  late TextEditingController _labelCtrl;
  late TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.link.label);
    _urlCtrl = TextEditingController(text: widget.link.url);
    _labelCtrl.addListener(_notify);
    _urlCtrl.addListener(_notify);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(ExerciseLink(
      id: widget.link.id,
      label: _labelCtrl.text,
      url: _urlCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  isDense: true,
                  hintText: 'e.g. youtube.com/watch?v=...',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: 'Remove',
          onPressed: widget.onDelete,
        ),
      ],
    );
  }
}
