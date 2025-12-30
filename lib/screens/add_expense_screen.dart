import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  // Variables para la imagen
  File? _selectedImage;
  bool _isUploading = false;
  bool _isLoading = false;

  // Función para seleccionar imagen (Cámara o Galería)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);

    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
      });
    }
  }

  // Función para subir la imagen a Firebase Storage
  Future<String?> _uploadImage(String expenseId) async {
    if (_selectedImage == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child(widget.groupId)
          .child('$expenseId.jpg');

      await storageRef.putFile(_selectedImage!);
      final imageUrl = await storageRef.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print("Error subiendo imagen: $e");
      return null;
    }
  }

  Future<void> addExpense() async {
    if (_isLoading) return;

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa una descripción')),
      );
      return;
    }

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingrese un monto válido')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Obtener datos básicos
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final String userName = userDoc.exists ? (userDoc.data()!['name'] ?? 'Usuario') : 'Usuario';
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

      // 2. Generar el ID
      final newExpenseDoc = groupRef.collection('expenses').doc();

      // 3. Subir imagen
      String? receiptUrl;
      if (_selectedImage != null) {
        receiptUrl = await _uploadImage(newExpenseDoc.id);
      }

      // 4. Guardar datos en Firestore
      await newExpenseDoc.set({
        'description': _descriptionController.text.trim(),
        'amount': amount,
        'paidBy': user.uid,
        'paidByName': userName,
        'receiptUrl': receiptUrl, // Guardamos la URL de la foto
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Actualizar Balances
      await _updateBalancesIncrementally(groupRef, user.uid, amount);

      if (!mounted) return;
      Navigator.pop(context);

    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _updateBalancesIncrementally(DocumentReference groupRef, String payerId, double newExpenseAmount) async {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) throw Exception("El grupo no existe.");

      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);
      final Map<String, double> currentBalances = (groupData['balances'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ?? {};

      final double sharePerPerson = newExpenseAmount / members.length;

      for (final memberId in members) {
        double currentBalance = currentBalances[memberId] ?? 0.0;
        if (memberId == payerId) {
          currentBalance += (newExpenseAmount - sharePerPerson);
        } else {
          currentBalance -= sharePerPerson;
        }
        currentBalances[memberId] = double.parse(currentBalance.toStringAsFixed(2));
      }

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
      appBar: AppBar(title: const Text('Registrar Gasto con Foto')),
      body: SingleChildScrollView( // Añadido Scroll por si el teclado tapa campos
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ÁREA DE LA FOTO
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                    Text("Tocar para tomar foto del recibo", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Concepto',
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
              label: Text(_isLoading
                  ? (_isUploading ? 'Subiendo foto...' : 'Guardando...')
                  : 'Guardar Gasto'),
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