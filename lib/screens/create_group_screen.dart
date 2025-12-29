import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[
        DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }

  Future<void> createGroup() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final groupRef =
          FirebaseFirestore.instance.collection('groups').doc();

      final joinCode = _generateJoinCode();

      // 1️⃣ Crear grupo
      await groupRef.set({
        'metadata': {
          'name': _nameController.text.trim(),
          'joinCode': joinCode,
          'createdAt': Timestamp.now(),
          'createdBy': user.uid,
        },
        'members': [user.uid],
        'balances': {},
      });

      // 2️⃣ Agregar grupo al usuario
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'groups': FieldValue.arrayUnion([groupRef.id]),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo creado correctamente')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear grupo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del grupo'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: createGroup,
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}
