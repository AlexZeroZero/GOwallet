enum Language { chineseSimplified, englishUS }

extension LanguageExt on Language {
  String get simple => this == Language.chineseSimplified ? '简体中文' : 'English';
  String get description =>
      this == Language.chineseSimplified ? '简体中文' : 'English (US)';
}

Language languageFromDescription(String description) =>
    description == 'English (US)'
    ? Language.englishUS
    : Language.chineseSimplified;
