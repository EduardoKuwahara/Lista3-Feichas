import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const PerfilApp());

class PerfilApp extends StatelessWidget {
  const PerfilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Perfil de Usuario',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const PerfilPage(),
    );
  }
}

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = false;
  String? _feedback;
  int? _editingId;
  List<Map<String, dynamic>> _profiles = [];

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _feedback = null;
    });

    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/profiles'));
      if (response.statusCode != 200) throw Exception();

      final data = jsonDecode(response.body) as List<dynamic>;
      _profiles = data.cast<Map<String, dynamic>>();

      if (_editingId == null) {
        if (_profiles.isNotEmpty) {
          final first = _profiles.first;
          _nameController.text = (first['name'] as String?) ?? '';
          _emailController.text = (first['email'] as String?) ?? '';
        } else {
          _nameController.clear();
          _emailController.clear();
        }
      }
    } catch (_) {
      _feedback = 'Nao foi possivel carregar os perfis.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _feedback = null;
    });

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      };

      final response = _editingId == null
          ? await http.post(
              Uri.parse('$_baseUrl/api/profiles'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
          : await http.put(
              Uri.parse('$_baseUrl/api/profiles/$_editingId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );

      if (response.statusCode != 200 && response.statusCode != 201)
        throw Exception();

      _editingId = null;
      _feedback = 'Perfil salvo com sucesso.';
      await _loadProfiles();
    } catch (_) {
      _feedback = 'Erro ao salvar perfil.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    _editingId = (profile['id'] as num?)?.toInt();
    _nameController.text = (profile['name'] as String?) ?? '';
    _emailController.text = (profile['email'] as String?) ?? '';
    setState(() {});
  }

  Future<void> _deleteProfile(int id) async {
    setState(() {
      _loading = true;
      _feedback = null;
    });

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/profiles/$id'),
      );
      if (response.statusCode != 204) throw Exception();

      if (_editingId == id) {
        _editingId = null;
        _nameController.clear();
        _emailController.clear();
      }

      _feedback = 'Perfil excluido com sucesso.';
      await _loadProfiles();
    } catch (_) {
      _feedback = 'Erro ao excluir perfil.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForm() {
    _editingId = null;
    _nameController.clear();
    _emailController.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      border: const OutlineInputBorder(),
                      suffixIcon: _editingId == null
                          ? null
                          : const Icon(Icons.edit),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe o nome'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty || !email.contains('@')) {
                        return 'Informe um e-mail valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _saveProfile,
                          child: Text(
                            _editingId == null ? 'Salvar' : 'Atualizar',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _loading ? null : _clearForm,
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _loading ? null : _loadProfiles,
                    child: const Text('Recarregar lista'),
                  ),
                ),
              ],
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 8),
              Text(_feedback!),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Lista de perfis',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _profiles.isEmpty
                  ? const Center(child: Text('Nenhum perfil cadastrado.'))
                  : ListView.separated(
                      itemCount: _profiles.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(profile['name'] as String? ?? ''),
                          subtitle: Text(profile['email'] as String? ?? ''),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editProfile(profile),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteProfile(
                                  (profile['id'] as num?)?.toInt() ?? 0,
                                ),
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
