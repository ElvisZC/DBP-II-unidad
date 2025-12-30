import 'package:flutter/material.dart';

class AppTheme {
  // 1. COLORES MAESTROS
  // Usaremos un Indigo (Azul moderno) como primario y Verde para el dinero
  static const Color primary = Color(0xFF2962FF); // Indigo vibrante
  static const Color secondary = Color(0xFF10B981); // Verde Esmeralda (Dinero)
  static const Color error = Color(0xFFEF4444); // Rojo moderno
  static const Color background = Color(0xFFF9FAFB); // Gris muy clarito (casi blanco)

  // 2. DEFINICIÓN DEL TEMA
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      error: error,
      background: background,
      surface: Colors.white, // Color de las tarjetas (Cards)
    ),

    // Fondo general de la app
    scaffoldBackgroundColor: background,

    // Estilo de la Barra Superior (AppBar)
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white, // Color del texto e iconos
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white
      ),
    ),

    // Estilo de las Tarjetas (Cards)
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Estilo de los Botones Principales (ElevatedButton)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),

    // Estilo de los Botones Secundarios (OutlinedButton)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: const BorderSide(color: primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),

    // Estilo de los Campos de Texto (InputDecoration) - ¡Esto ahorra mucho código!
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Sin borde por defecto
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12), // Borde gris suave
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2), // Borde azul al escribir
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIconColor: Colors.grey,
    ),

    // Estilo de los botones flotantes (+ Gasto)
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      shape: CircleBorder(), // O RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
    ),
  );
}