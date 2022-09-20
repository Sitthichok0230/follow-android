import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:follow/convert_link.dart';
import 'package:follow/db/word_db.dart';
import 'package:follow/models/word_model.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Follow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: const HomePageWidget(),
    );
  }
}

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({Key? key, this.cookieManager}) : super(key: key);

  final CookieManager? cookieManager;

  @override
  _HomePageWidgetState createState() => _HomePageWidgetState();
}

void _showToast(String msg) => Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: Colors.grey,
    );

class _HomePageWidgetState extends State<HomePageWidget>
    with WidgetsBindingObserver {
  late WebViewController _con;
  final CookieManager? cookieManager = CookieManager();
  late StreamSubscription _intentDataStreamSubscription;
  String? _sharedText;

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
      convertUrl(_sharedText ?? 'https://follow-service.onrender.com', true);
      _con.loadUrl(getLink());
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
      _showToast('ไม่ได้เชื่อมต่ออินเทอร์เน็ต');
      SystemNavigator.pop();
    }
  }

  Future<void> _navigateAndDisplaySelection(
      BuildContext context, bool online) async {
    final result = await Navigator.push<String>(
        context,
        MaterialPageRoute<String>(
          builder: (context) =>
              online ? const _FullscreenDialog() : const _SavedDialog(),
          fullscreenDialog: true,
        ));
    if (!mounted) return;
    _con.loadUrl('https://www.google.com/search?q=${result!}');
    convertUrl((await _con.currentUrl())!, true);
  }

  Stream<dynamic> getCurrentUrl() async* {
    await Future.delayed(const Duration(seconds: 2));
    while (true) {
      convertUrl((await _con.currentUrl())!, false);
      yield await WordDatabase.haveWord(getWord());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xffffffff),
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
                        Icons.star,
                        color: Color(0xffffffff),
                        size: 25,
                      ),
                      tooltip: 'ลบ',
                      onPressed: () async {
                        await WordDatabase.deleteWord(getWord());
                        _showToast('ลบแล้ว');
                      });
                } else {
                  return IconButton(
                    icon: const Icon(
                      Icons.star_border,
                      color: Color(0xffffffff),
                      size: 25,
                    ),
                    tooltip: 'เพิ่ม',
                    onPressed: () async {
                      if (getWord().isNotEmpty) {
                        await WordDatabase.insertWord(Word(word: getWord()));
                        _showToast('เพิ่มแล้ว');
                      } else {
                        _showToast('เพิ่มไม่ได้');
                      }
                    },
                  );
                }
              }),
          IconButton(
            icon: const Icon(
              Icons.trending_up_outlined,
              color: Color(0xffffffff),
              size: 25,
            ),
            tooltip: 'มาแรง',
            onPressed: () => _navigateAndDisplaySelection(context, true),
          ),
          IconButton(
            icon: const Icon(
              Icons.saved_search_outlined,
              color: Color(0xffffffff),
              size: 25,
            ),
            tooltip: 'คำที่จะค้นหา',
            onPressed: () => _navigateAndDisplaySelection(context, false),
          ),
          IconButton(
            icon: const Icon(
              Icons.exit_to_app_outlined,
              color: Color(0xff3ea6ff),
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
                        _con.loadUrl('https://follow-service.onrender.com');
                        convertUrl((await _con.currentUrl())!, true);
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
                      color: Color(0xffaaaaaa),
                      size: 25,
                    ),
                    tooltip: 'Google',
                    onPressed: () async {
                      convertUrl((await _con.currentUrl())!, true);
                      _con.loadUrl(
                          'https://www.google.com/search?q=${getWord()}');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.facebook,
                      color: Color(0xffaaaaaa),
                      size: 25,
                    ),
                    tooltip: 'Facebook',
                    onPressed: () async {
                      convertUrl((await _con.currentUrl())!, true);
                      _con.loadUrl(
                          'https://m.facebook.com/hashtag/${getWord()}');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.twitter,
                      color: Color(0xffaaaaaa),
                      size: 25,
                    ),
                    tooltip: 'Twitter',
                    onPressed: () async {
                      convertUrl((await _con.currentUrl())!, true);
                      _con.loadUrl(
                          'https://mobile.twitter.com/search?q=${getWord()}');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.instagram,
                      color: Color(0xffaaaaaa),
                      size: 25,
                    ),
                    tooltip: 'Instagram',
                    onPressed: () async {
                      convertUrl((await _con.currentUrl())!, true);
                      _con.loadUrl(
                          'https://www.instagram.com/explore/tags/${getWord()}');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.youtube,
                      color: Color(0xffaaaaaa),
                      size: 25,
                    ),
                    tooltip: 'YouTube',
                    onPressed: () async {
                      convertUrl((await _con.currentUrl())!, true);
                      _con.loadUrl(
                          'https://m.youtube.com/results?search_query=${getWord()}');
                    },
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.tiktok,
                      color: Color(0xffaaaaaa),
                      size: 25,
                    ),
                    tooltip: 'TikTok',
                    onPressed: () async {
                      convertUrl((await _con.currentUrl())!, true);
                      _con.loadUrl('https://www.tiktok.com/tag/${getWord()}');
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
                    convertUrl(
                        _sharedText ?? 'https://follow-service.onrender.com',
                        true);
                    _con.loadUrl(getLink());
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

class _FullscreenDialog extends StatefulWidget {
  const _FullscreenDialog({Key? key}) : super(key: key);

  @override
  _FullscreenDialogState createState() => _FullscreenDialogState();
}

class _FullscreenDialogState extends State<_FullscreenDialog> {
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
      appBar: AppBar(title: const Text('มาแรง')),
      body: FutureBuilder(
          future: makeRequest(),
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(
                  child: Text(
                'เกิดข้อผิดพลาด\n\nโปรดลองใหม่อีกครั้ง',
                textAlign: TextAlign.center,
              ));
            } else if (snapshot.data.length == 0) {
              return const Center(
                  child: Text('ไม่มีสถิติการค้นหา 24 ชั่วโมงล่าสุด'));
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

class _SavedDialog extends StatefulWidget {
  const _SavedDialog({Key? key}) : super(key: key);

  @override
  _SavedDialogState createState() => _SavedDialogState();
}

class _SavedDialogState extends State<_SavedDialog> {
  List<String> data = [];

  @override
  void initState() {
    super.initState();
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
        appBar: AppBar(title: const Text('คำที่จะค้นหา')),
        body: (data.isEmpty)
            ? const Center(child: Text('ไม่มีคำค้นหา'))
            : Scrollbar(
                child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return Dismissible(
                          key: Key(data[index]),
                          onDismissed: (DismissDirection dir) async {
                            await WordDatabase.deleteWord(data[index]);
                            setState(() {
                              data.removeAt(index);
                            });
                            _showToast('ลบแล้ว');
                          },
                          background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerLeft,
                              child: const Icon(Icons.delete)),
                          secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              child: const Icon(Icons.delete)),
                          child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              title: Text(data[index]),
                              onTap: () async {
                                Navigator.pop(context, '${data[index]}');
                              }));
                    })));
  }
}
