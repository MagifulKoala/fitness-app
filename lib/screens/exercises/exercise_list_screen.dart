import 'package:flutter/material.dart';
import '../../core/app_logger.dart';
import '../../models/exercise.dart';
import '../../repositories/exercise_repository.dart';
import 'exercise_detail_screen.dart';
import 'exercise_form_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final ExerciseRepository exerciseRepo;

  const ExerciseListScreen({super.key, required this.exerciseRepo});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  List<Exercise> _exercises = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = _query.isEmpty
          ? await widget.exerciseRepo.getAll()
          : await widget.exerciseRepo.search(_query);
      setState(() {
        _exercises = results;
        _loading = false;
      });
    } catch (e, st) {
      log.e('[ExerciseList] load error', error: e, stackTrace: st);
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or alias…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _exercises.isEmpty
                    ? const Center(child: Text('No exercises found.'))
                    : ListView.builder(
                        itemCount: _exercises.length,
                        itemBuilder: (ctx, i) {
                          final ex = _exercises[i];
                          return ListTile(
                            title: Text(ex.name),
                            subtitle: ex.aliases.isNotEmpty
                                ? Text(ex.aliases.join(', '))
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => ExerciseDetailScreen(
                                    exercise: ex,
                                    exerciseRepo: widget.exerciseRepo,
                                  ),
                                ),
                              );
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseFormScreen(
                exerciseRepo: widget.exerciseRepo,
              ),
            ),
          );
          _load();
        },
      ),
    );
  }
}
