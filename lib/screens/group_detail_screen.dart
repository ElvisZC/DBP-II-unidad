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
              height: 400, // Altura fija para la imagen
              child: InteractiveViewer( // Permite hacer zoom con los dedos
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

  // Widget para construir la sección de Balances en tiempo real
  Widget _buildBalancesSection(Map<String, dynamic> balances, Map<String, String> memberNames) {
    final myBalance = (balances[currentUser?.uid] as num?)?.toDouble() ?? 0.0;

    List<Widget> balanceWidgets = [];

    // 1. Mi resumen personal
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

    // 2. Lista detallada de quién debe a quién
    if (balances.isEmpty) {
      balanceWidgets.add(const Text("No hay deudas registradas.", style: TextStyle(fontStyle: FontStyle.italic)));
    } else {
      balances.forEach((uid, amountNum) {
        if (uid == currentUser?.uid) return; // No mostrarme a mí mismo en la lista

        final amount = (amountNum as num).toDouble();
        final name = memberNames[uid] ?? 'Usuario';

        if (amount == 0) return; // No mostrar saldos cero

        String detailText;
        Color itemColor;
        IconData itemIcon;

        if (amount > 0) {
          // Saldo positivo: Esta persona LE DEBE al grupo (o a mí indirectamente)
          detailText = "$name debe ${NumberFormat.simpleCurrency().format(amount)}";
          itemColor = Colors.orange;
          itemIcon = Icons.arrow_outward;
        } else {
          // Saldo negativo: Alguien del grupo LE DEBE a esta persona
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
    // Referencia al documento principal del grupo
    final groupDocRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    // Referencia a la subcolección de gastos
    final expensesQuery = groupDocRef.collection('expenses').orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Aquí podrías mostrar el código del grupo en un diálogo
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: groupDocRef.snapshots(), // Escuchamos cambios en el GRUPO (para balances)
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
              // SECCIÓN SUPERIOR: Balances (Fija)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildBalancesSection(balances, memberNamesDummy),
              ),

              const Divider(height: 1),

              // SECCIÓN INFERIOR: Lista de Gastos (Scrollable)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: expensesQuery.snapshots(), // Escuchamos cambios en los GASTOS
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
                          child: Text("Aún no hay gastos. ¡Agrega el primero!", style: TextStyle(color: Colors.grey)),
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
                              // EL BOTÓN DEL OJO 👁️
                              if (receiptUrl != null && receiptUrl.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.blue),
                                  onPressed: () => _showReceiptDialog(context, receiptUrl, description),
                                  tooltip: 'Ver recibo',
                                )
                              else
                                const IconButton(
                                  icon: Icon(Icons.visibility_off, color: Colors.grey),
                                  onPressed: null, // Deshabilitado si no hay foto
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
              arguments: {'groupId': widget.groupId} // Pasamos el ID como argumento
          );
        },
        label: const Text('Nuevo Gasto'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}