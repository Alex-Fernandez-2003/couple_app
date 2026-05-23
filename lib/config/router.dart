import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/boxes/screens/boxes_screen.dart';
import '../features/couple/screens/create_room_screen.dart';
import '../features/couple/screens/join_room_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/notes/screens/notes_screen.dart';
import '../features/pareja/screens/pareja_screen.dart';
import '../features/shopping/screens/shopping_screen.dart';
import '../features/study/screens/study_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const OnboardingScreen()),
    GoRoute(
      path: '/create-room',
      builder: (context, state) => const CreateRoomScreen(),
    ),
    GoRoute(
      path: '/join-room',
      builder: (context, state) => const JoinRoomScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/couple',
          builder: (context, state) => const ParejaScreen(),
        ),
        GoRoute(
          path: '/shopping',
          builder: (context, state) => const ShoppingScreen(),
        ),
        GoRoute(
          path: '/notes',
          builder: (context, state) => const NotesScreen(),
        ),
        GoRoute(
          path: '/study',
          builder: (context, state) => const StudyScreen(),
        ),
        GoRoute(
          path: '/boxes',
          builder: (context, state) => const BoxesScreen(),
        ),
      ],
    ),
  ],
);

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bienvenidos a tu espacio de pareja',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Crea una conexión con tu persona favorita usando un código. Es simple, rápido y sin login.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/create-room'),
                child: const Text('Crear conexión'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/join-room'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFD8392),
                  side: const BorderSide(color: Color(0xFFFD8392)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Unirme con código'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({required this.child, super.key});

  static const _locations = [
    '/home',
    '/couple',
    '/shopping',
    '/notes',
    '/study',
    '/boxes',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.toString();
    final index = _locations.indexWhere((path) => location.startsWith(path));
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: index < 0 ? 0 : index,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              label: 'Pareja',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              label: 'Compras',
            ),
            NavigationDestination(
              icon: Icon(Icons.note_outlined),
              label: 'Notas',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              label: 'Estudio',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Cajas',
            ),
          ],
          onDestinationSelected: (value) => context.go(_locations[value]),
        ),
      ),
    );
  }
}
