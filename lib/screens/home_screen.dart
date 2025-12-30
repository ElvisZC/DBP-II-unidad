import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_group_screen.dart';
import 'join_group_screen.dart';
import 'group_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios en el documento del USUARIO para ver sus grupos
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Grupos'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.exit_to_app))
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error al cargar perfil'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          // Obtenemos la lista de IDs de grupos donde está el usuario
          final List<dynamic> groupIds = userData['groups'] ?? [];

          if (groupIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.group_off, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No tienes grupos aún."),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: groupIds.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final groupId = groupIds[index];

              // Por cada ID, buscamos la info del grupo en tiempo real
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
                builder: (ctx, groupSnap) {
                  if (!groupSnap.hasData) return const SizedBox.shrink(); // Cargando silencioso

                  final groupData = groupSnap.data!.data() as Map<String, dynamic>?;
                  if (groupData == null) return const SizedBox.shrink(); // Grupo borrado o error

                  final metadata = groupData['metadata'] as Map<String, dynamic>? ?? {};
                  final name = metadata['name'] ?? 'Grupo sin nombre';
                  final code = metadata['joinCode'] ?? '---';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Código: $code'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(
                              groupId: groupId,
                              groupName: name, // Enviamos el nombre recuperado
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "join",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinGroupScreen()));
            },
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "create",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}