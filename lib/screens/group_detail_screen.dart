import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupDetailScreen extends StatelessWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grupo')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData =
              groupSnapshot.data!.data() as Map<String, dynamic>;
          final metadata = groupData['metadata'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata['name'],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Código: ${metadata['joinCode']}'),
                  ],
                ),
              ),

              const Divider(),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Balances',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId)
                      .collection('balances')
                      .doc('current')
                      .snapshots(),
                  builder: (context, balanceSnapshot) {
                    if (!balanceSnapshot.hasData ||
                        !balanceSnapshot.data!.exists) {
                      return const Center(
                          child: Text('Sin balances aún'));
                    }

                    final balanceData =
                        balanceSnapshot.data!.data() as Map<String, dynamic>;
                    final Map<String, dynamic> debts =
                        balanceData['debts'] ?? {};

                    if (debts.isEmpty) {
                      return const Center(
                          child: Text('Todos están saldados'));
                    }

                    return ListView(
                      children: debts.entries.map((entry) {
                        final ids = entry.key.split('_');
                        final debtorId = ids[0];
                        final creditorId = ids[1];
                        final amount = entry.value;

                        return FutureBuilder<List<DocumentSnapshot>>(
                          future: Future.wait([
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(debtorId)
                                .get(),
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(creditorId)
                                .get(),
                          ]),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return const ListTile(
                                  title: Text('Cargando...'));
                            }

                            final debtorName =
                                userSnapshot.data![0]['name'];
                            final creditorName =
                                userSnapshot.data![1]['name'];

                            return ListTile(
                              leading:
                                  const Icon(Icons.account_balance_wallet),
                              title: Text(
                                  '$debtorName debe S/ ${amount.toStringAsFixed(2)}'),
                              subtitle:
                                  Text('a $creditorName'),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
