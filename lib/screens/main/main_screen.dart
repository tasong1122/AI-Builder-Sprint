import 'package:flutter/material.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_theme.dart';
import '../contract/contract_list_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int selectedIndex;
  late final List<Widget> tabScreens;
  final homeKey = GlobalKey<HomeScreenState>();
  final contractListKey = GlobalKey<ContractListScreenState>();

  @override
  void initState() {
    super.initState();
    tabScreens = [
      HomeScreen(key: homeKey, onContractJoined: openJoinedContractList),
      ContractListScreen(key: contractListKey),
      SettingsScreen(
        isDarkMode: AppTheme.themeMode.value == ThemeMode.dark,
        onDarkModeChanged: changeDarkMode,
      ),
    ];
    selectedIndex = widget.initialTabIndex.clamp(0, tabScreens.length - 1);
  }

  // 하단 네비게이션에서 선택한 화면으로 탭을 전환한다.
  void selectTab(int index) {
    setState(() {
      selectedIndex = index;
    });
    if (index == 1) {
      contractListKey.currentState?.loadContracts();
    } else if (index == 0) {
      homeKey.currentState?.loadDashboard();
    }
  }

  // 링크로 계약을 등록한 뒤 계약 탭을 열고 목록을 새로 불러온다.
  void openJoinedContractList() {
    setState(() {
      selectedIndex = 1;
    });
    contractListKey.currentState?.loadContracts();
  }

  // 설정값에 따라 앱 전체의 밝은 테마와 어두운 테마를 전환한다.
  void changeDarkMode(bool enabled) {
    AppTheme.themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    setState(() {
      tabScreens[2] = SettingsScreen(
        isDarkMode: enabled,
        onDarkModeChanged: changeDarkMode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(index: selectedIndex, children: tabScreens),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.defaultBorderRadius),
          topRight: Radius.circular(AppDimensions.defaultBorderRadius),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: '돈 약속',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
