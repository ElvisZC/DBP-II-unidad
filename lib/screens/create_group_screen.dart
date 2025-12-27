import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();

  String generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> createGroup() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final joinCode = generateJoinCode();

      final groupRef =
          FirebaseFirestore.instance.collection('groups').doc();

      await groupRef.set({
        'metadata': {
          'name': _groupNameController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
          'joinCode': joinCode,
        },
        'members': [user.uid],
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'groups': FieldValue.arrayUnion([groupRef.id])
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo creado correctamente')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
              controller: _groupNameController,
              decoration: const InputDecoration(labelText: 'Nombre del grupo'),
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
