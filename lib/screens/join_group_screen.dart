import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> joinGroup() async {
    FocusScope.of(context).unfocus();

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un código válido'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // 1. Buscar grupo por código
      final query = await FirebaseFirestore.instance
          .collection('groups')
          .where('metadata.joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw 'Código inválido o grupo no encontrado';
      }

      final groupDoc = query.docs.first;
      final groupId = groupDoc.id;

      // 2. Actualizar referencias (Usuario <-> Grupo)
      final batch = FirebaseFirestore.instance.batch();

      batch.update(
          FirebaseFirestore.instance.collection('groups').doc(groupId),
          {'members': FieldValue.arrayUnion([user.uid])}
      );

      batch.update(
          FirebaseFirestore.instance.collection('users').doc(user.uid),
          {'groups': FieldValue.arrayUnion([groupId])}
      );

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Te has unido al grupo!'), backgroundColor: Colors.green),
      );

      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse a Grupo')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.diversity_3, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 30),

            const Text(
              "Ingresa el código de invitación",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Código del grupo',
                hintText: 'Ej. X7Y9Z2',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              textCapitalization: TextCapitalization.characters, // Fuerza mayúsculas
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isLoading ? null : joinGroup,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Unirse'),
            ),
          ],
        ),
      ),
    );
  }
}