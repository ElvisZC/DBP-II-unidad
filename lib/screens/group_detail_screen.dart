import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupDetailScreen extends StatelessWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del grupo'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData =
              snapshot.data!.data() as Map<String, dynamic>;

          if (!groupData.containsKey('metadata')) {
            return const Center(
              child: Text('Estructura del grupo inválida'),
            );
          }

          final metadata =
              Map<String, dynamic>.from(groupData['metadata'] ?? {});
          final membersMap =
              Map<String, dynamic>.from(metadata['members'] ?? {});
          final balances =
              Map<String, dynamic>.from(groupData['balances'] ?? {});

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre del grupo
                Text(
                  metadata['name'] ?? 'Grupo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                // Código del grupo
                Text(
                  'Código del grupo: ${metadata['joinCode'] ?? '-'}',
                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 24),

                // ================= BALANCES =================
                const Text(
                  'Balances',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (balances.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Sin balances aún'),
                    ),
                  )
                else
                  Column(
                    children: balances.entries.map((entry) {
                      final parts = entry.key.split('_');
                      final debtorId = parts[0];
                      final creditorId = parts[1];
                      final amount =
                          (entry.value as num).toDouble();

                      final debtorName =
                          membersMap[debtorId] ?? 'Usuario';
                      final creditorName =
                          membersMap[creditorId] ?? 'Usuario';

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title:
                              Text('$debtorName → $creditorName'),
                          trailing: Text(
                            'S/ ${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),

                // ================= HISTORIAL =================
                const Text(
                  'Historial de gastos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('groups')
                        .doc(groupId)
                        .collection('expenses')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, expenseSnapshot) {
                      if (!expenseSnapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      if (expenseSnapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('No hay gastos registrados'),
                        );
                      }

                      return ListView(
                        children: expenseSnapshot.data!.docs.map((doc) {
                          final expense =
                              doc.data() as Map<String, dynamic>;

                          return ListTile(
                            leading:
                                const Icon(Icons.receipt_long),
                            title: Text(expense['description']),
                            subtitle: Text(
                                'Pagado por ${expense['paidByName']}'),
                            trailing: Text(
                              'S/ ${(expense['amount'] as num).toDouble().toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
