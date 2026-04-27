import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const DespesasApp());

class DespesasApp extends StatelessWidget {
  const DespesasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gerenciador de Despesas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const DespesasPage(),
    );
  }
}

class Expense {
  final int id;
  final String description;
  final double amount;

  const Expense({
    required this.id,
    required this.description,
    required this.amount,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: (json['id'] as num?)?.toInt() ?? 0,
      description: (json['description'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DespesasPage extends StatefulWidget {
  const DespesasPage({super.key});

  @override
  State<DespesasPage> createState() => _DespesasPageState();
}

class _DespesasPageState extends State<DespesasPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  List<Expense> _expenses = [];
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
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/expenses'));
      if (response.statusCode != 200) throw Exception();
      final list = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _expenses = list
            .map((item) => Expense.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'description': _descriptionController.text.trim(),
      'amount': double.parse(_amountController.text.replaceAll(',', '.')),
    };

    setState(() => _loading = true);
    try {
      final response = _editingId == null
          ? await http.post(
              Uri.parse('$_baseUrl/api/expenses'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
          : await http.put(
              Uri.parse('$_baseUrl/api/expenses/$_editingId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );

      if (response.statusCode != 201 && response.statusCode != 200)
        throw Exception();

      _editingId = null;
      _descriptionController.clear();
      _amountController.clear();
      await _loadExpenses();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editExpense(Expense expense) async {
    _editingId = expense.id;
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _deleteExpense(int id) async {
    setState(() => _loading = true);
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/expenses/$id'),
      );
      if (response.statusCode != 204) throw Exception();
      if (_editingId == id) {
        _editingId = null;
        _descriptionController.clear();
        _amountController.clear();
      }
      await _loadExpenses();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciador de Despesas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Descricao',
                      border: const OutlineInputBorder(),
                      suffixIcon: _editingId == null
                          ? null
                          : const Icon(Icons.edit),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe a descricao'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      if (parsed == null || parsed <= 0)
                        return 'Informe um valor valido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submitExpense,
                          child: Text(
                            _editingId == null
                                ? 'Adicionar gasto'
                                : 'Atualizar gasto',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                _editingId = null;
                                _descriptionController.clear();
                                _amountController.clear();
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _expenses.isEmpty
                  ? const Center(child: Text('Nenhum gasto cadastrado.'))
                  : ListView.separated(
                      itemCount: _expenses.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(expense.description),
                          subtitle: Text(
                            'R\$ ${expense.amount.toStringAsFixed(2)}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editExpense(expense),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteExpense(expense.id),
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
