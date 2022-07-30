class Word {
  final String word;

  const Word({
    required this.word,
  });

  Map<String, dynamic> toMap() {
    return {'word': word};
  }

  String toStr() {
    return 'Word{word: $word}';
  }
}
