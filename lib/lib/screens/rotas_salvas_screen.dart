import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RotasSalvasScreen extends StatefulWidget {
  const RotasSalvasScreen({super.key});

  @override
  State<RotasSalvasScreen> createState() => _RotasSalvasScreenState();
}

class _RotasSalvasScreenState extends State<RotasSalvasScreen> {
  List<Map<String, dynamic>> _rotas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = prefs.getStringList('rotas') ?? [];
    setState(() {
      _rotas = lista.map((r) => jsonDecode(r) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _excluir(int indice) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = prefs.getStringList('rotas') ?? [];
    lista.removeAt(indice);
    await prefs.setStringList('rotas', lista);
    _carregar();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota excluída')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📂 Rotas Salvas')),
      body: _rotas.isEmpty
          ? const Center(child: Text('Nenhuma rota salva ainda', style: TextStyle(fontSize: 16)))
          : ListView.builder(
              itemCount: _rotas.length,
              itemBuilder: (context, i) {
                final rota = _rotas[i];
                final data = DateTime.parse(rota['data']);
                return ListTile(
                  title: Text(rota['nome']),
                  subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(data)} — ${(rota['pontos'] as List).length} pontos'),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => showDialog(context: context,
                      builder: (_) => AlertDialog(title: const Text('Excluir?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                          TextButton(onPressed: () { Navigator.pop(context); _excluir(i); },
                            child: const Text('Excluir', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
