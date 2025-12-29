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

    final String userName = userDoc['name'];

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
    await _recalculateBalances(groupRef);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _recalculateBalances(DocumentReference groupRef) async {
    final groupDoc = await groupRef.get();
    final List<String> members =
        List<String>.from(groupDoc['members']);

    // Pagos por miembro
    final Map<String, double> paid = {
      for (final m in members) m: 0.0,
    };

    final expensesSnap = await groupRef.collection('expenses').get();
    double total = 0.0;

    for (final doc in expensesSnap.docs) {
      final data = doc.data();
      final double amount = (data['amount'] as num).toDouble();
      final String payer = data['paidBy'];

      paid[payer] = paid[payer]! + amount;
      total += amount;
    }

    if (total == 0) {
      await groupRef.update({'balances': {}});
      return;
    }

    final double perPerson = total / members.length;

    // Balance individual
    final Map<String, double> balance = {};
    for (final m in members) {
      balance[m] = paid[m]! - perPerson;
    }

    // Deudas finales
    final Map<String, double> debts = {};

    for (final debtor in members) {
      for (final creditor in members) {
        if (balance[debtor]! < 0 && balance[creditor]! > 0) {
          final double debt =
              (-balance[debtor]! < balance[creditor]!)
                  ? -balance[debtor]!
                  : balance[creditor]!;

          if (debt > 0.01) {
            debts['${debtor}_$creditor'] = debt;
            balance[debtor] = balance[debtor]! + debt;
            balance[creditor] = balance[creditor]! - debt;
          }
        }
      }
    }

    // 3️⃣ Guardar balances dentro del grupo
    await groupRef.update({
      'balances': debts,
      'balancesUpdatedAt': Timestamp.now(),
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
              decoration: const InputDecoration(labelText: 'Monto'),
              keyboardType: TextInputType.number,
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
