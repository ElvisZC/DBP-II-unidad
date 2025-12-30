import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  // Recalcular Balances
  Future<void> _recalculateBalances() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recalculando balances... por favor espera')),
    );

    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Obtener datos del grupo y miembros
        final groupSnapshot = await transaction.get(groupRef);
        if (!groupSnapshot.exists) throw Exception("Grupo no encontrado");

        final groupData = groupSnapshot.data() as Map<String, dynamic>;
        final members = List<String>.from(groupData['members'] ?? []);

        if (members.isEmpty) return;

        // 2. Obtener TODOS los gastos de la subcolección para sumar de nuevo
        final expensesSnapshot = await groupRef.collection('expenses').get();

        // 3. Reiniciar balances a 0 para todos
        Map<String, double> newBalances = {};
        for (var m in members) {
          newBalances[m] = 0.0;
        }

        double totalExpenses = 0.0;

        // 4. Recorrer cada gasto y aplicar la matemática
        for (var doc in expensesSnapshot.docs) {
          final data = doc.data();
          final double amount = (data['amount'] as num).toDouble();
          final String payerId = data['paidBy'];

          totalExpenses += amount;
          final double sharePerPerson = amount / members.length;

          for (var memberId in members) {
            double current = newBalances[memberId] ?? 0.0;
            if (memberId == payerId) {
              current += (amount - sharePerPerson);
            } else {
              current -= sharePerPerson;
            }
            newBalances[memberId] = current;
          }
        }

        // 5. Redondeo final a 2 decimales
        newBalances.forEach((key, value) {
          newBalances[key] = double.parse(value.toStringAsFixed(2));
        });

        // 6. Guardar los nuevos balances limpios
        transaction.update(groupRef, {
          'balances': newBalances,
          'totalExpenses': totalExpenses,
          'lastActivityAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Balances corregidos correctamente!'), backgroundColor: Colors.green),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al recalcular: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Función para mostrar el recibo en un diálogo con zoom
  void _showReceiptDialog(BuildContext context, String imageUrl, String description) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(description, overflow: TextOverflow.ellipsis),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
            ),
            SizedBox(
              height: 400,
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (ctx, error, stackTrace) =>
                  const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      Text("Error al cargar la imagen", style: TextStyle(color: Colors.grey)),
                    ],
                  )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para construir la sección de Balances
  Widget _buildBalancesSection(Map<String, dynamic> balances, Map<String, String> memberNames) {
    final myBalance = (balances[currentUser?.uid] as num?)?.toDouble() ?? 0.0;

    List<Widget> balanceWidgets = [];

    // Mi resumen personal
    Color statusColor;
    String statusText;
    if (myBalance > 0) {
      statusColor = Colors.green;
      statusText = "Te deben en total: ${NumberFormat.simpleCurrency().format(myBalance)}";
    } else if (myBalance < 0) {
      statusColor = Colors.red;
      statusText = "Debes en total: ${NumberFormat.simpleCurrency().format(myBalance.abs())}";
    } else {
      statusColor = Colors.grey;
      statusText = "Estás al día (Saldo: 0)";
    }

    balanceWidgets.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        )
    );

    balanceWidgets.add(const SizedBox(height: 16));
    balanceWidgets.add(const Text("Detalle de Saldos:", style: TextStyle(fontWeight: FontWeight.bold)));
    balanceWidgets.add(const SizedBox(height: 8));

    // Lista detallada
    if (balances.isEmpty) {
      balanceWidgets.add(const Text("No hay deudas registradas.", style: TextStyle(fontStyle: FontStyle.italic)));
    } else {
      balances.forEach((uid, amountNum) {
        if (uid == currentUser?.uid) return;

        final amount = (amountNum as num).toDouble();
        final name = memberNames[uid] ?? 'Usuario';

        if (amount == 0) return;

        String detailText;
        Color itemColor;
        IconData itemIcon;

        if (amount > 0) {
          detailText = "$name debe ${NumberFormat.simpleCurrency().format(amount)}";
          itemColor = Colors.orange;
          itemIcon = Icons.arrow_outward;
        } else {
          detailText = "Se le debe a $name: ${NumberFormat.simpleCurrency().format(amount.abs())}";
          itemColor = Colors.blueGrey;
          itemIcon = Icons.arrow_back;
        }

        balanceWidgets.add(
            ListTile(
              leading: Icon(itemIcon, color: itemColor),
              title: Text(detailText),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )
        );
      });
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: balanceWidgets,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupDocRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    final expensesQuery = groupDocRef.collection('expenses').orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          // Botón de Recalcular (Refresh)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Recalcular Balances",
            onPressed: _recalculateBalances,
          ),
          // Botón de Info
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Lógica futura para ver código
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: groupDocRef.snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) return Center(child: Text('Error: ${groupSnapshot.error}'));
          if (!groupSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>?;
          if (groupData == null) return const Center(child: Text('Grupo no encontrado'));

          final balances = groupData['balances'] as Map<String, dynamic>? ?? {};

          final Map<String, String> memberNamesDummy = {
            currentUser?.uid ?? '': 'Tú',
          };

          return Column(
            children: [
              // 1. SECCIÓN DE BALANCES
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildBalancesSection(balances, memberNamesDummy),
              ),

              const Divider(height: 1),

              // 2. LISTA DE GASTOS
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: expensesQuery.snapshots(),
                  builder: (context, expensesSnapshot) {
                    if (expensesSnapshot.hasError) return Center(child: Text('Error: ${expensesSnapshot.error}'));
                    if (expensesSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final expenses = expensesSnapshot.data!.docs;

                    if (expenses.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text("Aún no hay gastos.", style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: expenses.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final expenseData = expenses[index].data() as Map<String, dynamic>;
                        final amount = (expenseData['amount'] as num).toDouble();
                        final description = expenseData['description'] as String;
                        final paidByName = expenseData['paidByName'] as String? ?? 'Alguien';
                        final receiptUrl = expenseData['receiptUrl'] as String?;
                        final createdAt = (expenseData['createdAt'] as Timestamp?)?.toDate();

                        final dateStr = createdAt != null
                            ? DateFormat('dd/MM/yy').format(createdAt)
                            : 'Fecha desc.';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple[100],
                            child: const Icon(Icons.receipt_long, color: Colors.purple),
                          ),
                          title: Text(description, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("$dateStr - Pagado por $paidByName"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                NumberFormat.simpleCurrency().format(amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              // BOTÓN DEL OJO
                              if (receiptUrl != null && receiptUrl.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.blue),
                                  onPressed: () => _showReceiptDialog(context, receiptUrl, description),
                                  tooltip: 'Ver recibo',
                                )
                              else
                                const IconButton(
                                  icon: Icon(Icons.visibility_off, color: Colors.grey),
                                  onPressed: null,
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
              context,
              '/add-expense',
              arguments: {'groupId': widget.groupId}
          );
        },
        label: const Text('Nuevo Gasto'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}