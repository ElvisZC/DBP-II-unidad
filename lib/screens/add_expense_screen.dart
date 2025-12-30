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

  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false;

  // Lista de categorías inicial
  String _selectedCategory = 'Otros';
  final Map<String, IconData> _categories = {
    'Comida': Icons.restaurant,
    'Transporte': Icons.directions_bus,
    'Hospedaje': Icons.hotel,
    'Entretenimiento': Icons.movie,
    'Supermercado': Icons.shopping_cart,
    'Salud': Icons.local_hospital,
    'Servicios': Icons.lightbulb,
    'Otros': Icons.receipt,
  };

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedImage != null) {
      setState(() => _selectedImage = File(pickedImage.path));
    }
  }

  // NUEVA CATEGORÍA
  void _showAddCategoryDialog() {
    TextEditingController newCategoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nueva Categoría"),
        content: TextField(
          controller: newCategoryController,
          decoration: const InputDecoration(hintText: "Ej. Bebidas, Regalos..."),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedCategory = 'Otros'); // Cancelar vuelve a Otros
            },
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (newCategoryController.text.isNotEmpty) {
                final newCat = newCategoryController.text.trim();
                setState(() {
                  // Agregamos la nueva categoría al mapa local
                  _categories[newCat] = Icons.star; // Icono genérico para las personalizadas
                  _selectedCategory = newCat;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Agregar"),
          )
        ],
      ),
    );
  }

  Future<String?> _uploadImage(String expenseId) async {
    if (_selectedImage == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref().child('receipts').child(widget.groupId).child('$expenseId.jpg');
      await storageRef.putFile(_selectedImage!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("Error subiendo imagen: $e");
      return null;
    }
  }

  // FUNCIÓN PRINCIPAL BLINDADA
  Future<void> addExpense() async {
    print("INTENTANDO GUARDAR GASTO");

    // 1. Ocultar teclado
    FocusScope.of(context).unfocus();

    if (_isLoading) return;

    // 2. Validación Descripción
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛑 Faltó la descripción'), backgroundColor: Colors.red)
      );
      return;
    }

    // 3. CORRECCIÓN DE COMA
    String amountText = _amountController.text.trim().replaceAll(',', '.');
    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      print("Error: Monto inválido recibido: $amountText");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛑 El monto no es válido (Ej: 10.50)'), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() { _isLoading = true; _isUploading = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isLoading = false; _isUploading = false; });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final String userName = userDoc.exists ? (userDoc.data()!['name'] ?? 'Usuario') : 'Usuario';
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

      final newExpenseDoc = groupRef.collection('expenses').doc();

      String? receiptUrl;
      if (_selectedImage != null) {
        receiptUrl = await _uploadImage(newExpenseDoc.id);
      }

      // Guardar Gasto
      await newExpenseDoc.set({
        'description': _descriptionController.text.trim(),
        'amount': amount,
        'category': _selectedCategory,
        'paidBy': user.uid,
        'paidByName': userName,
        'receiptUrl': receiptUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Actualizar Balances
      await _updateBalancesIncrementally(groupRef, user.uid, amount);

      print("¡ÉXITO!");
      if (!mounted) return;
      Navigator.pop(context);

    } catch (e) {
      print("ERROR FATAL: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; _isUploading = false; });
    }
  }

  Future<void> _updateBalancesIncrementally(DocumentReference groupRef, String payerId, double newExpenseAmount) async {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      final groupData = groupSnapshot.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);
      final Map<String, double> currentBalances = (groupData['balances'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ?? {};

      final double sharePerPerson = newExpenseAmount / members.length;

      for (final memberId in members) {
        double current = currentBalances[memberId] ?? 0.0;
        if (memberId == payerId) current += (newExpenseAmount - sharePerPerson);
        else current -= sharePerPerson;
        currentBalances[memberId] = double.parse(current.toStringAsFixed(2));
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
    // Lista para el Dropdown
    List<DropdownMenuItem<String>> dropdownItems = _categories.keys.map((String category) {
      return DropdownMenuItem<String>(
        value: category,
        child: Row(
          children: [
            Icon(_categories[category], color: Colors.blueGrey, size: 20),
            const SizedBox(width: 10),
            Text(category),
          ],
        ),
      );
    }).toList();

    // Opción especial
    dropdownItems.add(
        const DropdownMenuItem<String>(
          value: '➕ Crear nueva...',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Text("Crear nueva categoría...", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        )
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Gasto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_selectedImage!, fit: BoxFit.cover))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                  Text("Foto del recibo (Opcional)", style: TextStyle(color: Colors.grey)),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // MENU DESPLEGABLE
            DropdownButtonFormField<String>(
              value: _categories.containsKey(_selectedCategory) ? _selectedCategory : null,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: dropdownItems,
              onChanged: (String? newValue) {
                if (newValue == '➕ Crear nueva...') {
                  _showAddCategoryDialog();
                } else {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                }
              },
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Concepto', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Monto', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : addExpense,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Guardando...' : 'Guardar Gasto'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }
}