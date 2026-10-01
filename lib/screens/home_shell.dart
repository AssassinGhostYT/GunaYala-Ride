import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/rides_provider.dart';
import '../screens/profile_tab.dart';
import '../screens/publish_tab.dart';
import '../screens/search_tab.dart';
import '../screens/my_trips_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isDriver = context.select<AuthProvider, bool>((auth) => auth.isDriver);

    // El chofer ve Publicar; el pasajero ve Buscar primero.
    final pages = <Widget>[
      const SearchTab(),
      if (isDriver) const PublishTab() else const MyTripsTab(),
      const MyTripsTab(),
      const ProfileTab(),
    ];

    final labels = <String>[
      'Buscar',
      isDriver ? 'Publicar' : 'Viajes',
      'Mis viajes',
      'Perfil',
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          if (value == 0) context.read<RidesProvider>().start();
        },
        destinations: [
          for (var i = 0; i < pages.length; i++)
            NavigationDestination(
              icon: Icon(_iconFor(i, isDriver)),
              label: labels[i],
            ),
        ],
      ),
    );
  }

  IconData _iconFor(int index, bool isDriver) => switch (index) {
        0 => Icons.search,
        1 => isDriver ? Icons.add_circle_outline : Icons.directions_bus,
        2 => Icons.event_note,
        _ => Icons.person,
      };
}