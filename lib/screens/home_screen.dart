import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../state/app_state.dart';
import 'local_news_tab.dart';
import 'create_post_screen.dart';
import 'news_feed_tab.dart';
import 'profile_tab.dart';
import 'video_tab.dart';
import 'account_login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;



  @override
  Widget build(BuildContext context) {
    const tabs = [
      NewsFeedTab(),
      LocalNewsTab(),
      CreatePostScreen(),
      VideoTab(),
      ProfileTab(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _navIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _navIndex,
        onTap: (index) {
          if (index == 2) {
            if (!AppState.instance.isLoggedIn) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountLoginScreen()));
              return;
            }
          }
          setState(() => _navIndex = index);
        },
      ),
    );
  }
}
