import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const EstoqueApp());

class EstoqueApp extends StatelessWidget {
  const EstoqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle de Estoque',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const EstoquePage(),
    );
  }
}

class InventoryItem {
  final int id;
  final String name;
  final int quantity;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class EstoquePage extends StatefulWidget {
  const EstoquePage({super.key});

  @override
  State<EstoquePage> createState() => _EstoquePageState();
}

class _EstoquePageState extends State<EstoquePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _searchController = TextEditingController();
  List<InventoryItem> _items = [];
  bool _loading = false;
  int? _editingId;

  List<InventoryItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _items;
    }
    return _items
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/inventory'));
      if (response.statusCode != 200) throw Exception();
      final list = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _items = list
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'name': _nameController.text.trim(),
      'quantity': int.parse(_quantityController.text),
    };

    setState(() => _loading = true);
    try {
      final response = _editingId == null
          ? await http.post(
              Uri.parse('$_baseUrl/api/inventory'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
          : await http.put(
              Uri.parse('$_baseUrl/api/inventory/$_editingId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception();
      }
      _editingId = null;
      _nameController.clear();
      _quantityController.clear();
      await _loadItems();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editItem(InventoryItem item) async {
    _editingId = item.id;
    _nameController.text = item.name;
    _quantityController.text = item.quantity.toString();
    setState(() {});
  }

  Future<void> _deleteItem(int id) async {
    setState(() => _loading = true);
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/inventory/$id'),
      );
      if (response.statusCode != 204) throw Exception();
      if (_editingId == id) {
        _editingId = null;
        _nameController.clear();
        _quantityController.clear();
      }
      await _loadItems();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controle de Estoque')),
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
                      labelText: 'Produto',
                      border: const OutlineInputBorder(),
                      suffixIcon: _editingId == null
                          ? null
                          : const Icon(Icons.edit),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe o nome do produto'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null || parsed < 0) {
                        return 'Informe uma quantidade inteira >= 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submitItem,
                          child: Text(
                            _editingId == null
                                ? 'Salvar item'
                                : 'Atualizar item',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                _editingId = null;
                                _nameController.clear();
                                _quantityController.clear();
                                setState(() {});
                              },
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Pesquisar produto',
                hintText: 'Digite o nome do produto',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('Nenhum item cadastrado.'))
                  : _filteredItems.isEmpty
                  ? const Center(
                      child: Text('Nenhum produto encontrado para a pesquisa.'),
                    )
                  : ListView.separated(
                      itemCount: _filteredItems.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: Text(item.name),
                          subtitle: Text('Qtd: ${item.quantity}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editItem(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteItem(item.id),
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
