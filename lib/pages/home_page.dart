import 'package:flutter/material.dart';
import 'jwt_page.dart';
import 'url_page.dart';
import 'base64_page.dart';
import 'json_page.dart';
import 'hash_page.dart';
import 'text_page.dart';
import 'about_page.dart';
import 'time_page.dart';

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
    NavigationRailDestination(
      icon: Icon(Icons.data_object),
      label: Text('JSON'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.key),
      label: Text('Hash'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.text_fields),
      label: Text('Text'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.access_time),
      label: Text('Time'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.info_outline),
      label: Text('About'),
    ),
  ];

  final List<Widget> _pages = const [
    JwtPage(),
    UrlPage(),
    Base64Page(),
    JsonPage(),
    HashPage(),
    TextPage(),
    TimePage(),
    AboutPage(),
  ];

  final List<String> _titles = [
    'JWT',
    'URL',
    'Base64',
    'JSON',
    'Hash',
    'Text',
    '时间工具',
    'About',
  ];

  final List<IconData> _icons = [
    Icons.security,
    Icons.link,
    Icons.code,
    Icons.data_object,
    Icons.key,
    Icons.text_fields,
    Icons.access_time,
    Icons.info,
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
