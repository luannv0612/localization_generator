import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:build/build.dart';

class GenCodeBuilder implements Builder {
  String pathLozalization = 'lib/res/strings';

  @override
  Map<String, List<String>> get buildExtensions => {
    '.json': ['.dart']
  };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    var inputId = buildStep.inputId;
    if (!inputId.path.contains(pathLozalization)) {
      return;
    }
    var contents = await buildStep.readAsString(inputId);
    Map<String, dynamic> data = jsonDecode(contents);

    //build string class
    String content;
    String contentProp;

    var defaultLang = data['isDefault'] ?? false;
    var currentLangCode = inputId.pathSegments[inputId.pathSegments.length - 1].replaceAll('.json', '');

    for (var key in data.keys) {
      content = content == null ? _genKey(key, data[key].toString(), !defaultLang) : content + _genKey(key, data[key].toString(), !defaultLang);
      contentProp = contentProp == null ? _genKeyProp(key, data[key].toString()) : contentProp + _genKeyProp(key, data[key].toString());
    }

    if (defaultLang) {
      var languages = _listLanguageFromDir(pathLozalization);
      await Directory(pathLozalization + '/gen').create(recursive: false);
      await _createFile(pathLozalization + '/gen/strings.dart', _genDefaultStrings(inputId.package, currentLangCode, languages, content, contentProp));
    }
    var fileName = inputId.changeExtension('.dart').path.split('/').last;
    _createFile(pathLozalization + '/gen/' + fileName, _genContentStrings(inputId.package, currentLangCode, defaultLang ? '' : content));
  }

  String _genKeyProp(String key, String input) {
    var value = input.replaceAll('\n', '\\n');
    return '\'$key\': \'$value\',\n';
  }

  List<String> _listLanguageFromDir(String path) {
    var languages = <String>[];
    var dir = Directory(path);
    List contents = dir.listSync();
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        var fileName = getFileName(fileOrDir.path);
        if (fileName.contains('.json')) {
          languages.add(fileName.replaceFirst('.json', ''));
        }
      }
    }
    return languages;
  }

  void _createFile(String fileName, String content) {
    File(fileName).writeAsString(content)
        .then((File file) {
      // Stuff to do after file has been created...
    });
  }

  String _genKey(String key, String input, bool isOverride) {
    var value = input.replaceAll('\n', '\\n');
    var buffer = StringBuffer();
    if (isOverride) {
      buffer.writeln('  @override');
    }
    final List<Match> matches = parameterRegExp.allMatches(value).toList();
    if (matches.isNotEmpty) {
      //có parameter...
      //create fun
      var params = createParametrized(value, matches);
      buffer.write('''
  String $key ($params) => '$value';
''');
    } else {
      buffer.write('''
  String get $key => '$value';
''');
    }
    return buffer.toString();
  }

  String _genDefaultStrings(String package, String defaultLanguage, List<String> languages, String content, String contentProp) {
    var import = '';
    var supportedLocales = '';
    var loadInfo = '';
    for(var fileName in languages) {
      //build import
      import = import + '''
import 'package:$package/res/strings/gen/$fileName.dart';
''';
      //build supportedLocales
      supportedLocales = supportedLocales + '''
      Locale("$fileName", ""),
''';
      // build loadInfo
      var capName = capitalize(fileName);
      loadInfo = loadInfo + '''
        case "$fileName":
          Strings.current = const $capName();
          return SynchronousFuture<Strings>(Strings.current);
''';
    }
    return '''
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

$import

// ignore_for_file: non_constant_identifier_names
class Strings implements WidgetsLocalizations {

$content

  const Strings();

  static Strings current;

  static const GeneratedLocalizationsDelegate delegate = GeneratedLocalizationsDelegate();

  static Strings of(BuildContext context) => Localizations.of<Strings>(context, Strings);

  @override
  TextDirection get textDirection => TextDirection.ltr;
  
  static Locale localeResolutionCallback(Locale locale, Iterable<Locale> supported) {
    Locale target = _findSupported(locale);
    return target != null ? target : Locale("$defaultLanguage", "");
  }

  static Locale _findSupported(Locale locale) {
    if (locale != null) {
      for (Locale supportedLocale in delegate.supportedLocales) {
        if (locale.languageCode == supportedLocale.languageCode)
          return supportedLocale;
      }
    }
    return null;
  }

  static String stringByKey(BuildContext context, String key) {
    return delegate.getStringLabel(context, key);
  }

  dynamic getProp(String key) => <String, dynamic>{
    $contentProp
    }[key];
}

class GeneratedLocalizationsDelegate extends LocalizationsDelegate<Strings> {
  const GeneratedLocalizationsDelegate();
  static Map<String, dynamic> _defaultSentences = HashMap();

  List<Locale> get supportedLocales {
    return const <Locale>[
$supportedLocales
    ];
  }

  LocaleListResolutionCallback listResolution({Locale fallback, bool withCountry = true}) {
    return (List<Locale> locales, Iterable<Locale> supported) {
      if (locales == null || locales.isEmpty) {
        return fallback ?? supported.first;
      } else {
        return _resolve(locales.first, fallback, supported, withCountry);
      }
    };
  }

  LocaleResolutionCallback resolution({Locale fallback, bool withCountry = true}) {
    return (Locale locale, Iterable<Locale> supported) {
      return _resolve(locale, fallback, supported, withCountry);
    };
  }

  @override
  Future<Strings> load(Locale locale) async {
    final String lang = getLang(locale);
    if (lang != null) {
      switch (lang) {
$loadInfo
      }
    }
    Strings.current = const Strings();
    String defaultLanguage = await rootBundle.loadString('$pathLozalization/' + lang + '.json');
    _defaultSentences = json.decode(defaultLanguage);
    return SynchronousFuture<Strings>(Strings.current);
  }

  String getStringLabel(BuildContext context, String key) {
    
    if (key == null || key.isEmpty) {
      return key;
    }
    String ret = _defaultSentences[key] ?? key;
    return ret;
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale, true);

  @override
  bool shouldReload(GeneratedLocalizationsDelegate old) => false;

  ///
  /// Internal method to resolve a locale from a list of locales.
  ///
  Locale _resolve(Locale locale, Locale fallback, Iterable<Locale> supported, bool withCountry) {
    if (locale == null || !_isSupported(locale, withCountry)) {
      return fallback ?? supported.first;
    }

    final Locale languageLocale = Locale(locale.languageCode, "");
    if (supported.contains(locale)) {
      return locale;
    } else if (supported.contains(languageLocale)) {
      return languageLocale;
    } else {
      final Locale fallbackLocale = fallback ?? supported.first;
      return fallbackLocale;
    }
  }

  ///
  /// Returns true if the specified locale is supported, false otherwise.
  ///
  bool _isSupported(Locale locale, bool withCountry) {
    if (locale != null) {
      for (Locale supportedLocale in supportedLocales) {
        // Language must always match both locales.
        if (supportedLocale.languageCode != locale.languageCode) {
          continue;
        }

        // If country code matches, return this locale.
        if (supportedLocale.countryCode == locale.countryCode) {
          return true;
        }

        // If no country requirement is requested, check if this locale has no country.
        if (true != withCountry && (supportedLocale.countryCode == null || supportedLocale.countryCode.isEmpty)) {
          return true;
        }
      }
    }
    return false;
  }
}

String getLang(Locale l) => l == null
    ? null
    : l.countryCode != null && l.countryCode.isEmpty
    ? l.languageCode
    : l.toString();
''';
  }

  String _genContentStrings(String package, String langCode, String content) {
    var className = capitalize(langCode);
    return '''
import 'package:$package/res/strings/gen/strings.dart';

// ignore_for_file: non_constant_identifier_names
class $className extends Strings {
  const $className();
$content
}''';
  }
}

String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

String getFileName(String path) {
  return path?.split('/')?.last?.split('\\')?.last;
}

final RegExp parameterRegExp = RegExp(r'(?<!\\)\$\{?(.+?\b)\}?');

String createParametrized(String value, List<Match> matches) {
  var buffer = StringBuffer();
  for (var i = 0; i < matches.length; i++) {
    var parameter = normalizeParameter(matches[i].group(0));
    buffer.write('String $parameter');
    if(i < matches.length - 1) {
      buffer.write(', ');
    }
  }
  return buffer.toString();
}

String normalizeParameter(String parameter) {
  return parameter //
      .replaceAll(r'$', '')
      .replaceAll(r'{', '')
      .replaceAll(r'}', '');
}