import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'create_group_screen.dart';
import 'join_group_screen.dart';
import 'group_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grupos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.group_add),
                    title: const Text('Crear grupo'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateGroupScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Unirse a grupo'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JoinGroupScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.data!.exists ||
              userSnapshot.data!.data() == null) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> groups = userData['groups'] ?? [];

          if (groups.isEmpty) {
            return const Center(
              child: Text('No perteneces a ningún grupo'),
            );
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final String groupId = groups[index];

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .snapshots(),
                builder: (context, groupSnapshot) {
                  if (!groupSnapshot.hasData) {
                    return const ListTile(
                      title: Text('Cargando grupo...'),
                    );
                  }

                  if (!groupSnapshot.data!.exists ||
                      groupSnapshot.data!.data() == null) {
                    return const ListTile(
                      title: Text('Grupo no encontrado'),
                    );
                  }

                  final groupData =
                      groupSnapshot.data!.data() as Map<String, dynamic>;
                  final metadata =
                      Map<String, dynamic>.from(groupData['metadata']);

                  return ListTile(
                    leading: const Icon(Icons.group),
                    title: Text(metadata['name']),
                    subtitle:
                        Text('Código: ${metadata['joinCode']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GroupDetailScreen(groupId: groupId),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
