import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  Future<void> addExpense() async {
    final user = FirebaseAuth.instance.currentUser!;
    final double? amount =
        double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto inválido')),
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return;

    final String userName = userDoc.data()!['name'];

    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

    // 1️⃣ Guardar gasto
    await groupRef.collection('expenses').add({
      'description': _descriptionController.text.trim(),
      'amount': amount,
      'paidBy': user.uid,
      'paidByName': userName,
      'createdAt': Timestamp.now(),
    });

    // 2️⃣ Recalcular balances
    await _recalculateBalances();

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _recalculateBalances() async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

    final groupDoc = await groupRef.get();
    if (!groupDoc.exists) return;

    final data = groupDoc.data()!;
    final metadata =
        Map<String, dynamic>.from(data['metadata'] ?? {});
    final membersMap =
        Map<String, dynamic>.from(metadata['members'] ?? {});

    final members = membersMap.keys.toList();
    if (members.isEmpty) return;

    // Inicializar pagos
    final Map<String, double> paid = {
      for (var m in members) m: 0.0,
    };

    final expensesSnap = await groupRef.collection('expenses').get();
    double total = 0.0;

    for (var doc in expensesSnap.docs) {
      final expense = doc.data();
      final double amount =
          (expense['amount'] as num).toDouble();
      final String payer = expense['paidBy'];

      if (paid.containsKey(payer)) {
        paid[payer] = paid[payer]! + amount;
      }

      total += amount;
    }

    final double perPerson = total / members.length;

    final Map<String, double> balance = {
      for (var m in members) m: paid[m]! - perPerson,
    };

    final Map<String, double> debts = {};

    for (var debtor in members) {
      for (var creditor in members) {
        if (balance[debtor]! < 0 && balance[creditor]! > 0) {
          final double debtAmount =
              (-balance[debtor]!).clamp(0.0, balance[creditor]!);

          if (debtAmount > 0) {
            debts['${debtor}_$creditor'] = debtAmount;
            balance[debtor] = balance[debtor]! + debtAmount;
            balance[creditor] = balance[creditor]! - debtAmount;
          }
        }
      }
    }

    // 3️⃣ Guardar balances EN EL GRUPO
    await groupRef.update({
      'balances': debts,
      'balancesUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar gasto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Descripción'),
            ),
            TextField(
              controller: _amountController,
              decoration:
                  const InputDecoration(labelText: 'Monto'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: addExpense,
              child: const Text('Guardar gasto'),
            ),
          ],
        ),
      ),
    );
  }
}
