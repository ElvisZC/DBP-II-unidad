import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart'; // Asegúrate de tener este archivo o créalo vacío si no existe

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // 1. IMAGEN O ICONO PRINCIPAL
              // Si tienes una imagen en assets, usa Image.asset('assets/logo.png')
              // Por ahora usaremos un icono gigante muy estético
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.savings_outlined, // Icono de cerdito/ahorro
                  size: 60,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 40),

              // 2. TEXTOS DE BIENVENIDA
              const Text(
                'Gastos Compartidos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Gestiona tus viajes y divide cuentas\nsin peleas ni confusiones.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // 3. BOTÓN INICIAR SESIÓN
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Iniciar Sesión',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),

              const SizedBox(height: 16),

              // 4. BOTÓN REGISTRARSE
              OutlinedButton(
                onPressed: () {
                  // Si aún no tienes RegisterScreen, comenta esta navegación
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.blueAccent, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Crear Cuenta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}