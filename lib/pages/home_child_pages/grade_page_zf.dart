import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sachet/providers/grade_page_zf_provider.dart';
import 'package:sachet/providers/zhengfang_user_provider.dart';
import 'package:sachet/services/zhengfang_jwxt/get_data/get_grade.dart';
import 'package:sachet/services/zhengfang_jwxt/get_data/get_grade_semesters.dart';
import 'package:sachet/widgets/homepage_widgets/grade_page_qz_widgets/item_filter_dialog.dart';
import 'package:sachet/widgets/homepage_widgets/grade_page_zf_widgets/grade_table.dart';
import 'package:sachet/widgets/homepage_widgets/grade_page_zf_widgets/semester_index_selector.dart';
import 'package:sachet/widgets/homepage_widgets/grade_page_zf_widgets/semester_year_selector.dart';
import 'package:sachet/widgets/utils_widgets/login_expired_zf.dart';

import 'package:shared_preferences/shared_preferences.dart'; // 新增
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 新增
import 'dart:convert'; // 新增，用于处理数据对比

class GradePageZF extends StatelessWidget {
  const GradePageZF({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GradePageZFProvider(),
      child: Scaffold(
        appBar: AppBar(title: const Text('成绩查询')),
        body: Selector<GradePageZFProvider, bool>(
            selector: (_, provider) => provider.isSelectingSemester,
            builder: (context, isSelectingSemester, __) {
              if (isSelectingSemester) {
                return _QueryView();
              } else {
                return _ResultView();
              }
            }),
      ),
    );
  }
}

class _QueryView extends StatefulWidget {
  /// 获取可选学期及让用户选择学期
  const _QueryView({super.key});

  @override
  State<_QueryView> createState() => _QueryViewState();
}

class _QueryViewState extends State<_QueryView> {
  late Future getDataFuture;

  Future _getSemestersData(ZhengFangUserProvider? zhengFangUserProvider) async {
    final result = await getGradeSemestersZF(
      cookie: ZhengFangUserProvider.cookie,
      zhengFangUserProvider: zhengFangUserProvider,
    );
    final selectedSemesterYear = result.currentSemesterYear;
    if (selectedSemesterYear != null) {
      context
          .read<GradePageZFProvider>()
          .changeSemesterYear(selectedSemesterYear);
    }
    final selectedSemesterIndex = result.currentSemesterIndex;

    if (selectedSemesterIndex != null) {
      context
          .read<GradePageZFProvider>()
          .changeSemesterIndex(selectedSemesterIndex);
    }
    context
        .read<GradePageZFProvider>()
        .setSemestersYears(result.semestersYears);
  }

  /// 从登录页面回来，如果 value 为 true 说明登录成功，需要刷新
  void onGoBack(dynamic value) {
    if (value == true) {
      final zhengFangUserProvider = context.read<ZhengFangUserProvider>();
      setState(() {
        getDataFuture = _getSemestersData(zhengFangUserProvider);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final zhengFangUserProvider = context.read<ZhengFangUserProvider>();
    getDataFuture = _getSemestersData(zhengFangUserProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FutureBuilder(
            future: getDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                if (snapshot.error ==
                    "获取可查询学期数据失败: Http status code = 302, 可能需要重新登录") {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: LoginExpiredZF(
                        onGoBack: (value) => onGoBack(value),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runAlignment: WrapAlignment.center,
                    children: [
                      SemesterYearSelectorZF(),
                      SemesterIndexSelectorZF(),
                    ],
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: () {
                      context
                          .read<GradePageZFProvider>()
                          .setIsSelectingSemester(false);
                    },
                    child: Text('查询'),
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatefulWidget {
  /// 筛选显示字段的按钮
  const _FilterButton({super.key});

  @override
  State<_FilterButton> createState() => __FilterButtonState();
}

class __FilterButtonState extends State<_FilterButton> {
  void showFilterDialog() async {
    List<String> items = context.read<GradePageZFProvider>().items;
    List<String> selectedItems =
        context.read<GradePageZFProvider>().selectedItems;

    List<List<String>>? results = await showDialog(
      context: context,
      builder: (BuildContext context) => ItemFilterDialogQZ(
        items: items,
        selectedItems: selectedItems,
      ),
    );
    if (results != null) {
      // 新选择的要显示的 selectedItems，（经过 List.add、List.remove,顺序会乱）
      List<String> newSelectedItems = results[0];

      // （可能）经过重新排序的 items
      List<String> reorderedItems = results[1];

      // 对 newSelectedItems 根据 reorderedItems 的顺序排序
      // e.g.
      // newSelectedItems = [[课程名称, 学分, 平时成绩, 总成绩, 考核方式, 期末成绩],
      // reorderedItems = [开课学期, 课程名称, 学分, 平时成绩, 期末成绩, 总成绩, 总学时, 考核方式, 课程属性, 课程性质]]
      // 经过下面的处理 ==>
      // newSelectedItems = [课程名称, 学分, 平时成绩, 期末成绩, 总成绩, 考核方式]
      newSelectedItems.sort((a, b) =>
          reorderedItems.indexOf(a).compareTo(reorderedItems.indexOf(b)));
      context.read<GradePageZFProvider>().updateSelectedItems(newSelectedItems);
      context.read<GradePageZFProvider>().updateItems(reorderedItems);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      ),
      onPressed: showFilterDialog,
      icon: Icon(Icons.filter_list_outlined),
      label: Text('筛选'),
    );
  }
}

class _ResultView extends StatelessWidget {
  /// 显示成绩结果（上面是学期选择，下面是成绩表）
  const _ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              runAlignment: WrapAlignment.center,
              children: [
                SemesterYearSelectorZF(),
                SemesterIndexSelectorZF(),
                _FilterButton(),
              ],
            ),
            Selector<GradePageZFProvider, (String, String)>(
                selector: (_, provider) => (
                      provider.selectedSemesterYear,
                      provider.selectedSemesterIndex,
                    ),
                builder: (_, data, ___) {
                  return _GradeView(
                    key: ValueKey("${data.$1}_${data.$2}"),
                    semesterYear: data.$1,
                    semesterIndex: data.$2,
                  );
                }),
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _GradeView extends StatefulWidget {
  /// xnm 学年名，如 '2025'=> 指 2025-2026 学年
  final String semesterYear;

  /// xqm 学期名，"3"=> 第1学期，"12"=>第二学期，"16"=>第三学期, "" => 全部
  final String semesterIndex;

  const _GradeView({
    super.key,
    required this.semesterYear,
    required this.semesterIndex,
  });

  @override
  State<_GradeView> createState() => _GradeViewState();
}

class _GradeViewState extends State<_GradeView> {
  late Future _dataFuture;
  // 新增：通知插件实例
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    final zhengFangUserProvider = context.read<ZhengFangUserProvider>();
    _dataFuture = _getGradeData(zhengFangUserProvider);
    
    // 新增：初始化通知设置
    _initNotifications();
  }

  /// 新增：初始化通知功能的函数
  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // 确保你app图标叫这个，或者用 'app_icon'
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
        
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  /// 新增：发送通知的函数
  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'grade_channel_id', '成绩更新通知', 
            channelDescription: '当查询到新成绩时发送通知',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
            
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics);
  }

  /// 新增：检查是否有新成绩
  Future<void> _checkNewGrades(dynamic currentGrades) async {
    try {
      if (currentGrades == null) return;
      
      // 这里的 logic 假设 currentGrades 是一个 List。
      // 如果它是其他对象，你需要根据实际情况调整，比如 currentGrades.data
      List gradesList = currentGrades as List; 
      
      final prefs = await SharedPreferences.getInstance();
      // 获取上次保存的成绩数量
      int? lastCount = prefs.getInt('last_grade_count_${widget.semesterYear}');
      
      // 如果上次有记录，且现在的数量比上次多，说明出分了！
      if (lastCount != null && gradesList.length > lastCount) {
        int diff = gradesList.length - lastCount;
        _showNotification("🎉 成绩更新啦！", "发现 $diff 门新课程的成绩，快来看看吧！");
      }
      
      // 保存当前的数量，供下次对比
      await prefs.setInt('last_grade_count_${widget.semesterYear}', gradesList.length);
      
    } catch (e) {
      print("成绩比对出错: $e");
    }
  }

  /// 从登录页面回来，如果 value 为 true 说明登录成功，需要刷新
  void onGoBack(dynamic value) {
    if (value == true) {
      final zhengFangUserProvider = context.read<ZhengFangUserProvider>();
      setState(() {
        _dataFuture = _getGradeData(zhengFangUserProvider);
      });
    }
  }

  Future _getGradeData(ZhengFangUserProvider? zhengFangUserProvider) async {
    final result = await getGradeZF(
      cookie: ZhengFangUserProvider.cookie,
      zhengFangUserProvider: zhengFangUserProvider,
      semesterYear: widget.semesterYear,
      semesterIndex: widget.semesterIndex,
    );
    
    // 新增：获取到数据后，立马进行比对
    _checkNewGrades(result);
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          if (snapshot.error == "获取成绩数据失败: Http status code = 302, 可能需要重新登录") {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: LoginExpiredZF(
                  onGoBack: (value) => onGoBack(value),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '${snapshot.error}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }

        final gradeData = snapshot.data;
        return Column(
          children: [
            SizedBox(height: 20),
            GradeTableZF(gradeData: gradeData),
          ],
        );
      },
    );
  }
}
