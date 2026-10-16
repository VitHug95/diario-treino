import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Ações de mover que o leitor de tela anuncia na lista reordenável da ficha
/// (PBI-62): "Mover para cima", "Mover para baixo"... Só esses textos mudam; o
/// resto continua no padrão do Flutter, para não mexer em textos de que o Robot
/// depende. A lista lê dos WidgetsLocalizations; o Material também tem os
/// mesmos textos, então os dois ficam iguais.
abstract final class LocalizacoesPt {
  /// Entram em `localizationsDelegates` do MaterialApp.
  static const delegates = <LocalizationsDelegate<dynamic>>[
    _DelegateWidgets(),
    _DelegateMaterial(),
  ];
}

class _WidgetsPt extends DefaultWidgetsLocalizations {
  const _WidgetsPt();

  @override
  String get reorderItemUp => 'Mover para cima';
  @override
  String get reorderItemDown => 'Mover para baixo';
  @override
  String get reorderItemToStart => 'Mover para o início';
  @override
  String get reorderItemToEnd => 'Mover para o fim';
}

class _MaterialPt extends DefaultMaterialLocalizations {
  const _MaterialPt();

  @override
  String get reorderItemUp => 'Mover para cima';
  @override
  String get reorderItemDown => 'Mover para baixo';
  @override
  String get reorderItemToStart => 'Mover para o início';
  @override
  String get reorderItemToEnd => 'Mover para o fim';
}

class _DelegateWidgets extends LocalizationsDelegate<WidgetsLocalizations> {
  const _DelegateWidgets();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(const _WidgetsPt());

  @override
  bool shouldReload(_DelegateWidgets old) => false;
}

class _DelegateMaterial extends LocalizationsDelegate<MaterialLocalizations> {
  const _DelegateMaterial();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(const _MaterialPt());

  @override
  bool shouldReload(_DelegateMaterial old) => false;
}
