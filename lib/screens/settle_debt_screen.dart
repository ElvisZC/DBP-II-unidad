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
  final currentUser = FirebaseAuth.instance.currentUser;

  String? _selectedUserToPay;
  bool _isLoading = false;
  bool _isLoadingList = true;

  List<Map<String, dynamic>> _creditors = [];

  @override
  void initState() {
    super.initState();
    _loadCreditors();
  }

  // Cargar usuarios con saldo a favor
  Future<void> _loadCreditors() async {
    try {
      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();

      if (!groupDoc.exists || groupDoc.data() == null) return;

      final memberIds = List<String>.from(groupDoc.data()!['members'] ?? []);
      List<Map<String, dynamic>> tempCreditors = [];

      for (var uid in memberIds) {
        if (uid == currentUser?.uid) continue;

        final balance = (widget.balances[uid] as num?)?.toDouble() ?? 0.0;

        // Solo mostramos a quienes se les debe dinero (Saldo > 0)
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

      if (mounted) setState(() => _creditors = tempCreditors);
    } catch (e) {
      debugPrint("Error cargando acreedores: $e");
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _sendPaymentRequest() async {
    FocusScope.of(context).unfocus();

    if (_selectedUserToPay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona a quién pagar'), backgroundColor: Colors.orange));
      return;
    }

    // Corregir comas por puntos
    String amountText = _amountController.text.trim().replaceAll(',', '.');
    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final myName = userDoc.data()?['name'] ?? 'Alguien';

      // Crear solicitud de pago
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
        const SnackBar(content: Text('Solicitud enviada. Espera confirmación.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saldar Deuda")),
      body: _isLoadingList
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.handshake_outlined, size: 80, color: Colors.green),
            const SizedBox(height: 20),

            const Text(
              "¿A quién le vas a pagar?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Selector de Acreedor
            _creditors.isEmpty
                ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(child: Text("Nadie tiene saldo a favor por ahora.", style: TextStyle(color: Colors.deepOrange))),
                ],
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
              onChanged: (value) => setState(() => _selectedUserToPay = value),
              decoration: const InputDecoration(
                labelText: 'Destinatario',
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 16),

            // Campo Monto
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Monto a pagar",
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),

            const SizedBox(height: 40),

            // Botón Enviar
            ElevatedButton.icon(
              onPressed: (_isLoading || _creditors.isEmpty) ? null : _sendPaymentRequest,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_isLoading ? "Enviando..." : "Enviar Pagó"),
              style: ElevatedButton.styleFrom(
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