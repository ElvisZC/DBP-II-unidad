import 'package:cloud_firestore/cloud_firestore.dart';

class BalanceService {
  static Future<void> calculateGroupBalances(String groupId) async {
    final firestore = FirebaseFirestore.instance;

    final expensesSnapshot = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .get();

    Map<String, Map<String, double>> debts = {};

    for (var doc in expensesSnapshot.docs) {
      final data = doc.data();

      final double amount = data['amount'];
      final String paidBy = data['paidBy'];
      final List involved = data['involvedUsers'];

      final double share = amount / involved.length;

      for (String userId in involved) {
        if (userId == paidBy) continue;

        debts.putIfAbsent(userId, () => {});
        debts[userId]![paidBy] =
            (debts[userId]![paidBy] ?? 0) + share;
      }
    }

    await firestore
        .collection('balances')
        .doc(groupId)
        .set({'debts': debts});
  }
}
