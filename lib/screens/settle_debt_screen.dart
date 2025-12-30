import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SettleDebtScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> balances;

  const SettleDebtScreen({
    super.key,
    required this.groupId,
    required this.balances,
  });

  @override
  State<SettleDebtScreen> createState() => _SettleDebtScreenState();
}

class _SettleDebtScreenState extends State<SettleDebtScreen> {
  final _amountController = TextEditingController();
  String? _selectedUserToPay;
  bool _isLoading = false;
  final currentUser = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _creditors = [];

  @override
  void initState() {
    super.initState();
    _loadCreditors();
  }

  Future<void> _loadCreditors() async {
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();

    // Verificamos que existan miembros
    if (!groupDoc.exists || groupDoc.data() == null) return;

    final memberIds = List<String>.from(groupDoc.data()!['members'] ?? []);

    List<Map<String, dynamic>> tempCreditors = [];

    for (var uid in memberIds) {
      if (uid == currentUser?.uid) continue;

      final balance = (widget.balances[uid] as num?)?.toDouble() ?? 0.0;

      // Solo mostramos a gente que tiene saldo positivo (le deben dinero)
      if (balance > 0) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final name = userDoc.exists ? (userDoc.data()?['name'] ?? 'Usuario') : 'Desconocido';

        tempCreditors.add({
          'uid': uid,
          'name': name,
          'amount': balance,
        });
      }
    }

    if (mounted) {
      setState(() {
        _creditors = tempCreditors;
      });
    }
  }

  Future<void> _sendPaymentRequest() async {
    if (_selectedUserToPay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona a quién pagar')));
      return;
    }

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final myName = userDoc.data()?['name'] ?? 'Alguien';

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('settlements')
          .add({
        'fromUid': currentUser!.uid,
        'fromName': myName,
        'toUid': _selectedUserToPay,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada. Espera a que te confirmen.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saldar Deuda")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "¿A quién le vas a pagar?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _creditors.isEmpty
                ? const Card(
              color: Color(0xFFFFF3E0),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No hay nadie con saldo a favor en este momento. ¡Qué raro!", style: TextStyle(color: Colors.orange)),
              ),
            )
                : DropdownButtonFormField<String>(
              value: _selectedUserToPay,
              hint: const Text("Selecciona un integrante"),
              items: _creditors.map<DropdownMenuItem<String>>((creditor) {
                final amountFormatted = NumberFormat.simpleCurrency().format(creditor['amount']);
                return DropdownMenuItem<String>(
                  value: creditor['uid'] as String,
                  child: Text("${creditor['name']} (Le deben $amountFormatted)"),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUserToPay = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Monto a pagar",
                hintText: "Ej. 10.50",
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),
            ElevatedButton.icon(
              onPressed: (_isLoading || _creditors.isEmpty) ? null : _sendPaymentRequest,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_isLoading ? "Enviando..." : "Enviar Solicitud de Pago"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}