import 'package:flutter/material.dart';
import 'jwt_page.dart';
import 'url_page.dart';
import 'base64_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<NavigationRailDestination> _destinations = const [
    NavigationRailDestination(
      icon: Icon(Icons.security),
      label: Text('JWT'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.link),
      label: Text('URL'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.code),
      label: Text('Base64'),
    ),
  ];

  final List<Widget> _pages = const [
    JwtPage(),
    UrlPage(),
    Base64Page(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: _destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
