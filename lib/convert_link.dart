import 'dart:core';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

final regex = RegExp(
    r'[(http(s)?):\/\/(www\.)]*?([a-zA-Z0-9@:%_\+~#=]{2,256}\.[a-z(\.a-z)]{2,7})\/\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)');

String link = "";
String word = "";

String getLink() {
  return link;
}

String getWord() {
  return (Uri.decodeFull(word).replaceAll(RegExp(r'\+'), ' '))
      .replaceAll(RegExp(r'#'), '');
}

Future<void> makeRequest(bool enable) async {
  if (word.isNotEmpty && enable) {
    await http
        .put(Uri.parse(
            'https://follow-service.onrender.com/api/ranking/${getWord()}'))
        .then((res) => {
              if (res.statusCode != 200)
                Fluttertoast.showToast(
                  msg: 'เกิดข้อผิดพลาด',
                  toastLength: Toast.LENGTH_SHORT,
                  backgroundColor: Colors.grey,
                )
            });
  }
}

void filterPath() {
  if (word.isNotEmpty) {
    while (word.contains('/')) {
      word = word.substring(0, (word.lastIndexOf('/')));
    }
    if (word.contains('?')) {
      word = word.substring(0, (word.lastIndexOf('?')));
    }
  }
}

void convertUrl(String url, bool enable) {
  if (url.contains('@')) {
    List<String> path = url.split('@');
    link = url;
    url = path[0] + path[1];
    word = "@";
  } else {
    link = url;
  }
  RegExpMatch? match = regex.firstMatch(url);
  String service = match?.group(1) ?? "";
  if (word.contains('@')) {
    word += match?.group(2) ?? "";
  } else {
    word = match?.group(2) ?? "";
  }

  switch (service) {
    case 'thailandsuperstar.com':
      if (word.contains('profile/')) {
        word = word
            .substring((word.lastIndexOf('/')) + 1, (word.length))
            .replaceAll(RegExp(r'-'), ' ');
      } else if (word.contains('youtube/channel/')) {
        word = word
            .substring((word.lastIndexOf('/')) + 1, (word.length))
            .replaceAll(RegExp(r'_'), ' ');
      } else {
        word = service;
      }
      makeRequest(enable);
      break;
    case 'google.com':
      if (word.contains('q=') && word.contains('&')) {
        word = word.substring((word.indexOf('q=')) + 2, (word.indexOf('&')));
      } else if (word.contains('q=')) {
        word = word.substring((word.indexOf('q=')) + 2, (word.length));
      } else {
        word = "";
      }
      makeRequest(enable);
      break;
    case 'facebook.com':
      if (word.contains('people/')) {
        word = word.substring(7, (word.length));
      } else if (word.contains('groups/')) {
        word = "";
      } else if (word.contains('hashtag/') && word.contains('?')) {
        word = word.substring(8, (word.lastIndexOf('?')));
      } else if (word.contains('hashtag/')) {
        word = word.substring(8, (word.length));
      } else if (word.contains('public/')) {
        word = word.substring(7, (word.lastIndexOf('?')));
      } else if (word.contains('pg/')) {
        word = word.substring(3, (word.length));
      }
      filterPath();
      word = word.replaceAll(RegExp(r'\.'), ' ');
      word = word.replaceAll(RegExp(r'-'), ' ');
      makeRequest(enable);
      break;
    case 'youtube.com':
      if (word.contains('@')) {
        word = word.substring(1, (word.length));
      } else if (word.contains('user/')) {
        word = word.substring(5, (word.length));
      } else if (word.contains('tag/')) {
        word = word.substring(4, (word.length));
      } else if (word.contains('query=')) {
        word = word.substring((word.indexOf('query=')) + 6, (word.length));
      } else {
        word = "";
      }
      filterPath();
      makeRequest(enable);
      break;
    case 'instagram.com':
      if (word.contains('tags/')) {
        word = word.substring((word.indexOf('tags/')) + 5, (word.length));
      } else if (word.contains('login/')) {
        word = word.substring((word.lastIndexOf('next=/')) + 6, (word.length));
      } else if (word.contains('p/')) {
        word = "";
      }
      filterPath();
      makeRequest(enable);
      break;
    case 'twitter.com':
      if (word.contains('q=') && word.contains('&')) {
        word = word.substring((word.indexOf('=')) + 1, (word.indexOf('&')));
      } else if (word.contains('q=')) {
        word = word.substring((word.indexOf('=')) + 1, (word.length));
      } else if (word.contains('hashtag/') && word.contains('&')) {
        word = word.substring((word.lastIndexOf('/')) + 1, (word.indexOf('&')));
      } else if (word.contains('hashtag/')) {
        word = word.substring((word.lastIndexOf('/')) + 1, (word.length));
      } else if (word.contains('explore')) {
        word = "";
      }
      filterPath();
      makeRequest(enable);
      break;
    case 'tiktok.com':
      url = link;
      if (word.contains('q=')) {
        word = word.substring((word.indexOf('q=')) + 2, (word.length));
      } else if (word.contains('tag/')) {
        word = word.substring(4, (word.length));
      } else if (word.contains('@')) {
        word = word.substring(1, (word.length));
      } else if (word.contains('music/')) {
        word = word.substring(6, (word.lastIndexOf(RegExp(r'-[0-9]'))));
        word = word.replaceAll(RegExp(r'-'), ' ');
      } else {
        word = "";
      }
      filterPath();
      makeRequest(enable);
      break;
    default:
      word = service;
  }
}
