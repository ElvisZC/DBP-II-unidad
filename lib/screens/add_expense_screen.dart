import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;

  const AddExpenseScreen({super.key, required this.groupId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  Future<void> addExpense() async {
    final user = FirebaseAuth.instance.currentUser!;
    final amount = double.tryParse(_amountController.text.trim());

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

    final userName = userDoc['name'];

    // Guardar gasto
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .add({
      'description': _descriptionController.text.trim(),
      'amount': amount,
      'paidBy': user.uid,
      'paidByName': userName,
      'createdAt': Timestamp.now(),
    });

    // Recalcular balances
    await _recalculateBalances();

    Navigator.pop(context);
  }

  Future<void> _recalculateBalances() async {
    final groupRef =
        FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

    final groupDoc = await groupRef.get();
    final members = List<String>.from(groupDoc['members']);

    // Inicializar pagos
    final Map<String, double> paid = {
      for (var m in members) m: 0.0,
    };

    // Obtener gastos
    final expensesSnap =
        await groupRef.collection('expenses').get();

    double total = 0;

    for (var doc in expensesSnap.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num).toDouble();
      final payer = data['paidBy'];

      paid[payer] = paid[payer]! + amount;
      total += amount;
    }

    final perPerson = total / members.length;

    // Calcular balances individuales
    final Map<String, double> balance = {};
    for (var m in members) {
      balance[m] = paid[m]! - perPerson;
    }

    // Generar deudas
    final Map<String, double> debts = {};

    for (var debtor in members) {
      for (var creditor in members) {
        if (balance[debtor]! < 0 && balance[creditor]! > 0) {
          final double amount = (-balance[debtor]!)
              .clamp(0, balance[creditor]!)
              .toDouble();

          if (amount > 0) {
            debts['${debtor}_$creditor'] = amount;

            balance[debtor] = balance[debtor]! + amount;
            balance[creditor] = balance[creditor]! - amount;
          }
        }
      }
    }

    // Guardar balances
    await FirebaseFirestore.instance
        .collection('balances')
        .doc(widget.groupId)
        .set({
      'updatedAt': Timestamp.now(),
      'debts': debts,
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
              decoration: const InputDecoration(labelText: 'Descripción'),
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
