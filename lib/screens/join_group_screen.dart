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

  Future<void> joinGroup() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final code = _codeController.text.trim();

      final query = await FirebaseFirestore.instance
          .collection('groups')
          .where('metadata.joinCode', isEqualTo: code)
          .get();

      if (query.docs.isEmpty) {
        throw 'Código inválido';
      }

      final groupDoc = query.docs.first;
      final groupId = groupDoc.id;

      // 1️⃣ Agregar usuario al grupo
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      // 2️⃣ Agregar grupo al usuario
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'groups': FieldValue.arrayUnion([groupId]),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unido al grupo correctamente')),
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
      appBar: AppBar(title: const Text('Unirse a grupo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              decoration:
                  const InputDecoration(labelText: 'Código del grupo'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: joinGroup,
              child: const Text('Unirse'),
            ),
          ],
        ),
      ),
    );
  }
}
