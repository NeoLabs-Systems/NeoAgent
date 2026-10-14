import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../src/error_text.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class RetrievalInspectorView extends StatefulWidget {
  final NeoAgentController controller;

  const RetrievalInspectorView({super.key, required this.controller});

  @override
  State<RetrievalInspectorView> createState() => _RetrievalInspectorViewState();
}

class _RetrievalInspectorViewState extends State<RetrievalInspectorView> {
  final _queryController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await widget.controller.inspectMemory(query);
      if (!mounted) return;
      setState(() {
        _results = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = formatCaughtError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appStrings.retrievalInspector),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      labelText: appStrings.query,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _inspect(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _inspect,
                  child: Text(appStrings.inspect),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_error != null)
              Text(appStrings.errorArg12(_error), style: const TextStyle(color: Colors.red))
            else if (_results != null)
              Expanded(
                child: ListView.builder(
                  itemCount: (_results!['results'] as List?)?.length ?? 0,
                  itemBuilder: (context, index) {
                    final item = _results!['results'][index];
                    final breakdown = item['scoreBreakdown'] ?? {};
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appStrings.scoreArg1(item['score']?.toStringAsFixed(3) ?? '?'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(appStrings.contentArg1(item['content'])),
                            const SizedBox(height: 8),
                            Text(appStrings.breakdown, style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(appStrings.semanticArg1(breakdown['semantic']?.toStringAsFixed(3))),
                            Text(appStrings.lexicalArg1(breakdown['lexical']?.toStringAsFixed(3))),
                            Text(appStrings.fullTextFtsArg1(breakdown['fullText']?.toStringAsFixed(3))),
                            Text(appStrings.entityArg1(breakdown['entity']?.toStringAsFixed(3))),
                            Text(appStrings.relationArg1(breakdown['relation']?.toStringAsFixed(3))),
                            Text(appStrings.candidateCountArg1(breakdown['candidateCount'])),
                            Text(appStrings.vectorRankArg1(breakdown['vectorCandidateRank'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
