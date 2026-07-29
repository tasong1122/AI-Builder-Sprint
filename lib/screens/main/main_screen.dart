import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../contract/contract_list_screen.dart';
import '../home/home_screen.dart';

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
    } else {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: selectedIndex, children: tabScreens),
      bottomNavigationBar: NavigationBar(
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
        ],
      ),
    );
  }
}
