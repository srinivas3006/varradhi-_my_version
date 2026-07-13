import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/bottom_nav_bar.dart';
import 'local_news_tab.dart';
import 'create_post_screen.dart';
import 'news_feed_tab.dart';
import 'profile_tab.dart';
import 'video_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Vaaradhi?'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    ).then((shouldExit) {
      if (shouldExit == true) {
        SystemNavigator.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      NewsFeedTab(),
      LocalNewsTab(),
      CreatePostScreen(),
      VideoTab(),
      ProfileTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(index: _navIndex, children: tabs),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _navIndex,
          onTap: (index) => setState(() => _navIndex = index),
        ),
      ),
    );
  }
}
