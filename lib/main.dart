import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:follow/db/word_db.dart';
import 'package:follow/models/word.dart';
import 'package:follow/url_converter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

void main() => runApp(const MyApp());

const _brandPurple = Color(0xff6750a4);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      ColorScheme lightColorScheme;
      ColorScheme darkColorScheme;

      if (lightDynamic != null && darkDynamic != null) {
        lightColorScheme = lightDynamic.harmonized();
        darkColorScheme = darkDynamic.harmonized();
      } else {
        lightColorScheme = ColorScheme.fromSeed(
          seedColor: _brandPurple,
        );
        darkColorScheme = ColorScheme.fromSeed(
          seedColor: _brandPurple,
          brightness: Brightness.dark,
        );
      }
      return MaterialApp(
        title: 'Follow',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: lightColorScheme,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: darkColorScheme,
        ),
        home: const HomePageWidget(),
      );
    });
  }
}

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({Key? key, this.cookieManager}) : super(key: key);

  final CookieManager? cookieManager;

  @override
  _HomePageWidgetState createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget>
    with WidgetsBindingObserver {
  late WebViewController _con;
  final CookieManager? cookieManager = CookieManager();
  late StreamSubscription _intentDataStreamSubscription;
  String? _sharedText;
  List<String> words = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WordDatabase.openDb();
    _checkConnectivityState();
    if (Platform.isAndroid) WebView.platform = AndroidWebView();

    ReceiveSharingIntent.getInitialText().then((String? value) {
      setState(() {
        _sharedText = value;
      });
    });

    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() {
        _sharedText = value;
      });
      _con.loadUrl(UrlConverter.link);
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    WordDatabase.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkConnectivityState() async {
    final ConnectivityResult result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.none) {
      Fluttertoast.showToast(
        msg: 'ไม่ได้เชื่อมต่ออินเทอร์เน็ต',
        toastLength: Toast.LENGTH_SHORT,
      );
      SystemNavigator.pop();
    }
  }

  Future<void> _navigateAndDisplaySelection(
      BuildContext context, String dialogName) async {
    final result = await Navigator.push<String>(
        context,
        MaterialPageRoute<String>(
          builder: (context) => dialogName == 'word-ranking'
              ? const _WordRankingDialog()
              : const _WordSavedDialog(),
          fullscreenDialog: true,
        ));
    if (!mounted) return;
    _con.loadUrl('https://www.google.com/search?q=${result!}');
    UrlConverter.makeRequestIncreaseScore();
  }

  Stream<dynamic> getCurrentUrl() async* {
    await Future.delayed(const Duration(seconds: 2));
    while (true) {
      UrlConverter.convertUrl((await _con.currentUrl())!);
      yield await WordDatabase.haveWord(UrlConverter.word);
    }
  }

  void addWord(String word) {
    setState(() {
      if (!words.contains(word) && word.isNotEmpty) {
        words.add(word);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            size: 25,
          ),
          tooltip: 'ย้อนกลับ',
          onPressed: () {
            _con.goBack();
          },
        ),
        actions: [
          StreamBuilder(
              stream: getCurrentUrl(),
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                if (snapshot.hasData && snapshot.data) {
                  return IconButton(
                      icon: const Icon(
                        Icons.bookmark_outlined,
                        size: 25,
                      ),
                      tooltip: 'ลบ ${UrlConverter.word}',
                      onPressed: () async {
                        await WordDatabase.deleteWord(UrlConverter.word).then(
                            (_) => Fluttertoast.showToast(
                                msg: 'ลบ ${UrlConverter.word} แล้ว',
                                toastLength: Toast.LENGTH_SHORT));
                      });
                } else {
                  if (UrlConverter.word.isNotEmpty) {
                    return IconButton(
                        icon: const Icon(
                          Icons.bookmark_outline_outlined,
                          size: 25,
                        ),
                        tooltip: 'เพิ่ม ${UrlConverter.word}',
                        onPressed: () async {
                          await WordDatabase.insertWord(
                              Word(word: UrlConverter.word));
                          Fluttertoast.showToast(
                              msg: 'เพิ่ม ${UrlConverter.word} แล้ว',
                              toastLength: Toast.LENGTH_SHORT);
                        });
                  } else {
                    return const IconButton(
                        icon: Icon(
                          Icons.bookmark_outline_outlined,
                          size: 25,
                        ),
                        tooltip: 'ไม่พบคำ',
                        onPressed: null);
                  }
                }
              }),
          IconButton(
            icon: const Icon(
              Icons.trending_up_outlined,
              size: 25,
            ),
            tooltip: 'มาแรง',
            onPressed: () =>
                _navigateAndDisplaySelection(context, 'word-ranking'),
          ),
          IconButton(
            icon: const Icon(
              Icons.bookmarks,
              size: 20,
            ),
            tooltip: 'คำที่จะค้นหา',
            onPressed: () =>
                _navigateAndDisplaySelection(context, 'word-saved'),
          ),
          IconButton(
            icon: const Icon(
              Icons.exit_to_app_outlined,
              color: Colors.blueAccent,
              size: 25,
            ),
            tooltip: 'เปิดในแอป',
            onPressed: () async =>
                url_launcher.launch((await _con.currentUrl())!),
          ),
          PopupMenuButton(
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem(
                      child: const Text('หน้าแรก'),
                      onTap: () async {
                        _con.loadUrl(words.isNotEmpty
                            ? 'https://you.com/search?q=แนะนำลิงก์เนื้อหาเว็บไซต์ภาษาไทยหรืออังกฤษที่เกี่ยวข้องกับ $words&tbm=youchat'
                            : 'https://follow-service.onrender.com/');
                        words.clear();
                        UrlConverter.makeRequestIncreaseScore();
                      }),
                  PopupMenuItem(
                      child: const Text('ล้างคุกกี้'),
                      onTap: () async => await cookieManager?.clearCookies()),
                  PopupMenuItem(
                      child: const Text('ล้างแคช'),
                      onTap: () async => await _con.clearCache()),
                ];
              },
              tooltip: 'ตัวเลือกเพิ่มเติม')
        ],
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.google,
                      size: 25,
                    ),
                    tooltip: 'Google',
                    onPressed: () async {
                      UrlConverter.makeRequestIncreaseScore();
                      addWord(UrlConverter.word);
                      _con.loadUrl(UrlConverter.word != ''
                          ? 'https://www.google.com/search?q=${UrlConverter.word}'
                          : 'https://www.google.com');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.facebook,
                      size: 25,
                    ),
                    tooltip: 'Facebook',
                    onPressed: () async {
                      UrlConverter.makeRequestIncreaseScore();
                      addWord(UrlConverter.word);
                      _con.loadUrl(UrlConverter.word != ''
                          ? 'https://m.facebook.com/hashtag/${UrlConverter.word}'
                          : 'https://m.facebook.com');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.twitter,
                      size: 25,
                    ),
                    tooltip: 'Twitter',
                    onPressed: () async {
                      UrlConverter.makeRequestIncreaseScore();
                      addWord(UrlConverter.word);
                      _con.loadUrl(UrlConverter.word != ''
                          ? 'https://mobile.twitter.com/search?q=${UrlConverter.word}'
                          : 'https://mobile.twitter.com');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.instagram,
                      size: 25,
                    ),
                    tooltip: 'Instagram',
                    onPressed: () async {
                      UrlConverter.makeRequestIncreaseScore();
                      addWord(UrlConverter.word);
                      _con.loadUrl(UrlConverter.word != ''
                          ? 'https://www.instagram.com/explore/tags/${UrlConverter.word}'
                          : 'https://www.instagram.com');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.youtube,
                      size: 25,
                    ),
                    tooltip: 'YouTube',
                    onPressed: () async {
                      UrlConverter.makeRequestIncreaseScore();
                      addWord(UrlConverter.word);
                      _con.loadUrl(UrlConverter.word != ''
                          ? 'https://m.youtube.com/results?search_query=${UrlConverter.word}'
                          : 'https://m.youtube.com');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.tiktok,
                      size: 25,
                    ),
                    tooltip: 'TikTok',
                    onPressed: () async {
                      UrlConverter.makeRequestIncreaseScore();
                      addWord(UrlConverter.word);
                      _con.loadUrl(UrlConverter.word != ''
                          ? 'https://www.tiktok.com/tag/${UrlConverter.word}'
                          : 'https://www.tiktok.com');
                    },
                  ),
                ],
              ),
              Expanded(
                child: WebView(
                  javascriptMode: JavascriptMode.unrestricted,
                  onWebViewCreated:
                      (WebViewController webViewController) async {
                    _con = webViewController;
                    UrlConverter.convertUrl(
                      _sharedText ?? 'https://follow-service.onrender.com/',
                    );
                    _con.loadUrl(UrlConverter.link);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordRankingDialog extends StatefulWidget {
  const _WordRankingDialog({Key? key}) : super(key: key);

  @override
  _WordRankingDialogState createState() => _WordRankingDialogState();
}

class _WordRankingDialogState extends State<_WordRankingDialog> {
  var data = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<dynamic> makeRequest() async {
    await http
        .get(Uri.parse('https://follow-service.onrender.com/api/ranking'))
        .then((response) => {
              if (response.statusCode == 200)
                setState(() {
                  data = json.decode(response.body)['data'];
                })
            });
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('มาแรง'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'กลับ',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder(
          future: makeRequest(),
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 100,
                    color: Color(0xffaaaaaa),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Text(
                    'เกิดข้อผิดพลาด',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  TextButton(
                    onPressed: () async => await makeRequest(),
                    child: Text(
                      'โหลดใหม่',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  )
                ],
              ));
            } else if (snapshot.data.length == 0) {
              return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(
                      Icons.trending_up_outlined,
                      size: 100,
                      color: Color(0xffaaaaaa),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Text(
                      'ไม่มีคำค้นหาที่มาแรงในขณะนี้',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    ),
                  ]));
            } else {
              return RefreshIndicator(
                  onRefresh: () async => await makeRequest(),
                  child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                            leading: const ExcludeSemantics(
                                child: Icon(Icons.trending_up_outlined,
                                    color: Color(0xffaaaaaa))),
                            title: Text(data[index]),
                            onTap: () {
                              Navigator.pop(context, '${data[index]}');
                            });
                      }));
            }
          }),
    );
  }
}

class _WordSavedDialog extends StatefulWidget {
  const _WordSavedDialog({Key? key}) : super(key: key);

  @override
  _WordSavedDialogState createState() => _WordSavedDialogState();
}

class _WordSavedDialogState extends State<_WordSavedDialog> {
  List<String> data = [];

  @override
  void initState() {
    super.initState();
    final snackBar = SnackBar(
      content: Text(
        UrlConverter.word,
        style: const TextStyle(fontSize: 16),
      ),
      behavior: SnackBarBehavior.fixed,
      action: SnackBarAction(
          label: "บันทึก",
          onPressed: () async {
            await WordDatabase.insertWord(Word(word: UrlConverter.word));
            setState(() {
              data.insert(0, UrlConverter.word);
              data = data;
            });
          }),
    );
    WordDatabase.haveWord(UrlConverter.word).then((value) {
      if (!value && UrlConverter.word.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
    WordDatabase.words().then((List<Word> words) => {
          setState(() {
            data.addAll(words.map((e) => e.word));
            data = List.from(data.reversed);
          })
        });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('คำที่จะค้นหา'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'กลับ',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: data.isEmpty
            ? Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.bookmarks_outlined,
                      size: 100, color: Color(0xffaaaaaa)),
                  SizedBox(
                    height: 20,
                  ),
                  Text(
                    'คำค้นหาที่คุณบันทึกไว้จะปรากฏที่นี่',
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  )
                ],
              ))
            : Scrollbar(
                child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return Dismissible(
                          key: Key(data[index]),
                          direction: DismissDirection.endToStart,
                          onDismissed: (DismissDirection dir) async {
                            await WordDatabase.deleteWord(data[index]);
                            setState(() {
                              data.removeAt(index);
                              data = data;
                            });
                          },
                          secondaryBackground: Container(
                              color: Colors.redAccent,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: const Icon(Icons.delete_outline_outlined)),
                          child: ListTile(
                              leading: const ExcludeSemantics(
                                  child: Icon(Icons.search_outlined,
                                      color: Color(0xffaaaaaa))),
                              title: Text(data[index]),
                              onTap: () async {
                                Navigator.pop(context, data[index]);
                              }));
                    })));
  }
}
