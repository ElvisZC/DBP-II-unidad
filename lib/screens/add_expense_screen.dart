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
  bool _isLoading = false;

  // Función principal para agregar un gasto
  Future<void> addExpense() async {
    if (_isLoading) return;

    // Validación básica de campos vacíos
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa una descripción')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final double? amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingrese un monto válido')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Obtener datos del usuario actual para guardar su nombre en el gasto
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final String userName = userDoc.exists ? (userDoc.data()!['name'] ?? 'Usuario') : 'Usuario';

      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

      // 1️⃣ Guardar el gasto en la subcolección 'expenses'
      // Usamos .doc() vacío para generar ID automático
      await groupRef.collection('expenses').add({
        'description': _descriptionController.text.trim(),
        'amount': amount, // Guardamos el valor exacto del gasto
        'paidBy': user.uid,
        'paidByName': userName,
        'createdAt': FieldValue.serverTimestamp(), // Mejor usar serverTimestamp para evitar problemas de zona horaria
      });

      // 2️⃣ Actualizar los balances del grupo
      await _updateBalancesIncrementally(groupRef, user.uid, amount);

      if (!mounted) return;
      Navigator.pop(context); // Volver a la pantalla anterior

    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de Firebase: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocurrió un error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Lógica matemática para dividir la deuda
  Future<void> _updateBalancesIncrementally(DocumentReference groupRef, String payerId, double newExpenseAmount) async {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) throw Exception("El grupo no existe.");

      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);

      if (members.isEmpty) throw Exception("El grupo no tiene miembros.");

      // Leemos los balances actuales (o creamos un mapa vacío si es el primer gasto)
      final Map<String, double> currentBalances = (groupData['balances'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ?? {};

      // División equitativa
      final double sharePerPerson = newExpenseAmount / members.length;

      for (final memberId in members) {
        double currentBalance = currentBalances[memberId] ?? 0.0;

        if (memberId == payerId) {
          // EL QUE PAGÓ: Recupera su dinero (Gasto total) menos su propia parte (share)
          // Ejemplo: Pagó 100, son 4. Le deben 75. (100 - 25 = +75)
          currentBalance += (newExpenseAmount - sharePerPerson);
        } else {
          // LOS DEMÁS: Deben su parte.
          // Ejemplo: Deben 25. Balance = -25.
          currentBalance -= sharePerPerson;
        }

        // REDONDEO IMPORTANTE: Guardar solo 2 decimales para evitar 33.3333333
        currentBalances[memberId] = double.parse(currentBalance.toStringAsFixed(2));
      }

      // Actualizamos el documento del grupo
      transaction.update(groupRef, {
        'balances': currentBalances,
        'totalExpenses': FieldValue.increment(newExpenseAmount),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Gasto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Concepto (Ej. Cena, Taxi)',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Monto Total',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : addExpense,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Guardando...' : 'Guardar Gasto'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}