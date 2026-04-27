import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const FrequenciaApp());

class FrequenciaApp extends StatelessWidget {
  const FrequenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Registro de Frequencia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const FrequenciaPage(),
    );
  }
}

class Attendance {
  final int id;
  final String name;

  const Attendance({required this.id, required this.name});

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
    );
  }
}

class FrequenciaPage extends StatefulWidget {
  const FrequenciaPage({super.key});

  @override
  State<FrequenciaPage> createState() => _FrequenciaPageState();
}

class _FrequenciaPageState extends State<FrequenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<Attendance> _attendances = [];
  bool _loading = false;
  int? _editingId;

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/attendance'));
      if (response.statusCode != 200) throw Exception();
      final list = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _attendances = list
            .map((item) => Attendance.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitName() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = {'name': _nameController.text.trim()};
    setState(() => _loading = true);
    try {
      final response = _editingId == null
          ? await http.post(
              Uri.parse('$_baseUrl/api/attendance'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
          : await http.put(
              Uri.parse('$_baseUrl/api/attendance/$_editingId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );
      if (response.statusCode != 201 && response.statusCode != 200)
        throw Exception();
      _editingId = null;
      _nameController.clear();
      await _loadAttendance();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editName(Attendance attendance) async {
    _editingId = attendance.id;
    _nameController.text = attendance.name;
    setState(() {});
  }

  Future<void> _deleteName(int id) async {
    setState(() => _loading = true);
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/attendance/$id'),
      );
      if (response.statusCode != 204) throw Exception();
      if (_editingId == id) {
        _editingId = null;
        _nameController.clear();
      }
      await _loadAttendance();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Frequencia')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        border: const OutlineInputBorder(),
                        suffixIcon: _editingId == null
                            ? null
                            : const Icon(Icons.edit),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe um nome'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submitName,
                    child: Text(_editingId == null ? 'Adicionar' : 'Atualizar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            _editingId = null;
                            _nameController.clear();
                            setState(() {});
                          },
                    child: const Text('Limpar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _attendances.isEmpty
                  ? const Center(child: Text('Nenhum nome registrado.'))
                  : ListView.separated(
                      itemCount: _attendances.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _attendances[index];
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(item.name),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editName(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteName(item.id),
                              ),
                            ],
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
