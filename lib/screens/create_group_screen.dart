import 'dart:math';
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
  bool _isLoading = false;

  // Generar código alfanumérico aleatorio de 6 dígitos
  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> createGroup() async {
    // Ocultar teclado
    FocusScope.of(context).unfocus();

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ponle un nombre al grupo'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final groupRef = FirebaseFirestore.instance.collection('groups').doc();
      final joinCode = _generateJoinCode();

      // 1. Crear documento del grupo
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

      // 2. Vincular grupo al usuario
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'groups': FieldValue.arrayUnion([groupRef.id]),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo creado correctamente'), backgroundColor: Colors.green),
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
      appBar: AppBar(title: const Text('Crear Grupo')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.group_add_outlined, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 30),

            const Text(
              "Empieza un nuevo viaje",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Nombre del Grupo
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                hintText: 'Ej. Viaje a Cusco',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 30),

            // Botón Crear
            ElevatedButton(
              onPressed: _isLoading ? null : createGroup,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Crear Grupo'),
            ),
          ],
        ),
      ),
    );
  }
}