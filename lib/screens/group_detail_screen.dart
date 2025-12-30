import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'settle_debt_screen.dart';
import 'add_expense_screen.dart';

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

  final Map<String, IconData> _categoryIcons = {
    'Comida': Icons.restaurant,
    'Transporte': Icons.directions_bus,
    'Hospedaje': Icons.hotel,
    'Entretenimiento': Icons.movie,
    'Supermercado': Icons.shopping_cart,
    'Salud': Icons.local_hospital,
    'Servicios': Icons.lightbulb,
    'Otros': Icons.receipt,
  };

  // Confirmar pago recibido
  Future<void> _confirmPayment(String settlementId, String fromUid, double amount) async {
    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
      final settlementRef = groupRef.collection('settlements').doc(settlementId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupSnapshot = await transaction.get(groupRef);
        final groupData = groupSnapshot.data() as Map<String, dynamic>;

        Map<String, double> currentBalances = (groupData['balances'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ?? {};

        double balancePayer = currentBalances[fromUid] ?? 0.0;
        double balanceReceiver = currentBalances[currentUser!.uid] ?? 0.0;

        currentBalances[fromUid] = double.parse((balancePayer + amount).toStringAsFixed(2));
        currentBalances[currentUser!.uid] = double.parse((balanceReceiver - amount).toStringAsFixed(2));

        transaction.update(groupRef, {
          'balances': currentBalances,
          'lastActivityAt': FieldValue.serverTimestamp(),
        });

        transaction.update(settlementRef, {'status': 'confirmed'});
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Pago confirmado!')));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Recalcular balances
  Future<void> _recalculateBalances() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recalculando...')));

    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupSnapshot = await transaction.get(groupRef);
        final groupData = groupSnapshot.data() as Map<String, dynamic>;
        final members = List<String>.from(groupData['members'] ?? []);

        if (members.isEmpty) return;

        final expensesSnapshot = await groupRef.collection('expenses').get();
        final settlementsSnapshot = await groupRef.collection('settlements').where('status', isEqualTo: 'confirmed').get();

        Map<String, double> newBalances = {};
        for (var m in members) newBalances[m] = 0.0;

        double totalExpenses = 0.0;

        // Sumar gastos
        for (var doc in expensesSnapshot.docs) {
          final data = doc.data();
          final double amount = (data['amount'] as num).toDouble();
          final String payerId = data['paidBy'];
          totalExpenses += amount;
          final double sharePerPerson = amount / members.length;

          for (var memberId in members) {
            double current = newBalances[memberId] ?? 0.0;
            if (memberId == payerId) current += (amount - sharePerPerson);
            else current -= sharePerPerson;
            newBalances[memberId] = current;
          }
        }

        // Sumar pagos confirmados
        for (var doc in settlementsSnapshot.docs) {
          final data = doc.data();
          final double amount = (data['amount'] as num).toDouble();
          final String fromUid = data['fromUid'];
          final String toUid = data['toUid'];

          if (newBalances.containsKey(fromUid)) newBalances[fromUid] = (newBalances[fromUid] ?? 0) + amount;
          if (newBalances.containsKey(toUid)) newBalances[toUid] = (newBalances[toUid] ?? 0) - amount;
        }

        newBalances.forEach((key, value) {
          newBalances[key] = double.parse(value.toStringAsFixed(2));
        });

        transaction.update(groupRef, {
          'balances': newBalances,
          'totalExpenses': totalExpenses,
        });
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listo.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Ver recibo
  void _showReceiptDialog(BuildContext context, String imageUrl, String description) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(description),
              leading: CloseButton(),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black,
            ),
            SizedBox(
              height: 400,
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Info del grupo
  void _showGroupInfo() async {
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
    final data = groupDoc.data();
    final joinCode = data?['metadata']?['joinCode'] ?? 'Error';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Invitar Amigos"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Comparte este código:"),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).primaryColor),
              ),
              child: Text(
                joinCode,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Theme.of(context).primaryColor
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: joinCode));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copiado al portapapeles'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copiar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recalculateBalances,
            tooltip: 'Recalcular',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGroupInfo,
            tooltip: 'Ver código',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: groupRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text('El grupo no existe'));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final balances = data['balances'] as Map<String, dynamic>? ?? {};
          final myBalance = (balances[currentUser?.uid] as num?)?.toDouble() ?? 0.0;

          // Colores de estado
          final isNegative = myBalance < 0;
          final isPositive = myBalance > 0;
          final statusColor = isNegative ? Colors.red : (isPositive ? Colors.green : Colors.grey);

          return Column(
            children: [
              // 1. Notificaciones
              StreamBuilder<QuerySnapshot>(
                stream: groupRef.collection('settlements')
                    .where('toUid', isEqualTo: currentUser?.uid)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    color: Colors.orange[50],
                    child: Column(
                      children: snap.data!.docs.map((doc) {
                        final pData = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.notifications_active, color: Colors.deepOrange),
                          title: Text("${pData['fromName']} dice que pagó"),
                          subtitle: Text(NumberFormat.simpleCurrency().format(pData['amount'])),
                          trailing: ElevatedButton(
                            onPressed: () => _confirmPayment(doc.id, pData['fromUid'], (pData['amount'] as num).toDouble()),
                            child: const Text("Confirmar"),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),

              // 2. Resumen Saldo
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Column(
                  children: [
                    Text(
                      isNegative
                          ? "Debes ${NumberFormat.simpleCurrency().format(myBalance.abs())}"
                          : (isPositive ? "Te deben ${NumberFormat.simpleCurrency().format(myBalance)}" : "Estás al día"),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                    if (isNegative) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SettleDebtScreen(
                            groupId: widget.groupId,
                            balances: balances,
                          )));
                        },
                        icon: const Icon(Icons.money_off),
                        label: const Text("Saldar Deuda"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      )
                    ]
                  ],
                ),
              ),

              // 3. Lista de Gastos
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: groupRef.collection('expenses').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, expSnap) {
                    if (!expSnap.hasData) return const Center(child: CircularProgressIndicator());
                    final expenses = expSnap.data!.docs;

                    if (expenses.isEmpty) {
                      return const Center(child: Text("No hay gastos aún", style: TextStyle(color: Colors.grey)));
                    }

                    return ListView.separated(
                      itemCount: expenses.length,
                      separatorBuilder: (_,__) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final eData = expenses[i].data() as Map<String, dynamic>;
                        final category = eData['category'] as String? ?? 'Otros';
                        final icon = _categoryIcons[category] ?? Icons.receipt;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Icon(icon, color: Colors.blue[800]),
                          ),
                          title: Text(eData['description'] ?? 'Sin descripción'),
                          subtitle: Text("$category • Pagado por ${eData['paidByName']}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  NumberFormat.simpleCurrency().format(eData['amount']),
                                  style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                              const SizedBox(width: 8),

                              // Visualizador de recibo
                              if (eData['receiptUrl'] != null && eData['receiptUrl'].toString().isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.blue),
                                  onPressed: () => _showReceiptDialog(context, eData['receiptUrl'], eData['description'] ?? ''),
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen(groupId: widget.groupId)),
          );
        },
        label: const Text("Gasto"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}