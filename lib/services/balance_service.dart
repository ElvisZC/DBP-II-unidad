import 'package:cloud_firestore/cloud_firestore.dart';

class BalanceService {
  static Future<void> recalculateBalances(String groupId) async {
    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .get();

    if (expensesSnapshot.docs.isEmpty) return;

    final Map<String, double> paid = {};
    final Map<String, double> consumed = {};

    for (var doc in expensesSnapshot.docs) {
      final data = doc.data();
      final double amount = (data['amount'] as num).toDouble();
      final String paidBy = data['paidBy'];
      final List involved = data['involvedUsers'];

      paid[paidBy] = (paid[paidBy] ?? 0) + amount;

      final double share = amount / involved.length;
      for (var userId in involved) {
        consumed[userId] = (consumed[userId] ?? 0) + share;
      }
    }

    final Map<String, double> net = {};

    for (var userId in {...paid.keys, ...consumed.keys}) {
      net[userId] = (paid[userId] ?? 0) - (consumed[userId] ?? 0);
    }

    final Map<String, Map<String, double>> debts = {};

    final debtors = net.entries.where((e) => e.value < 0).toList();
    final creditors = net.entries.where((e) => e.value > 0).toList();

    for (var d in debtors) {
      double debt = -d.value;

      for (var c in creditors) {
        if (debt == 0) break;
        if (c.value <= 0) continue;

        final double pay = debt < c.value ? debt : c.value;

        debts.putIfAbsent(d.key, () => {});
        debts[d.key]![c.key] =
            ((debts[d.key]![c.key] ?? 0) + pay);

        debt -= pay;
        c = MapEntry(c.key, c.value - pay);
      }
    }

    await FirebaseFirestore.instance
        .collection('balances')
        .doc(groupId)
        .set({
      'groupId': groupId,
      'debts': debts,
      'updatedAt': Timestamp.now(),
    });
  }
}
