//Maybe it needs dispose method
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:realm/realm.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MongoDataWrapper extends InheritedWidget {
  late final AppConfiguration _appConfig;
  late final App _app;
  final ValueNotifier<Realm?> realm = ValueNotifier<Realm?>(null);
  final ValueNotifier<Realm?> localRealm = ValueNotifier<Realm?>(null);
  final List<SchemaObject> schemaObjects;
  final List<SchemaObject>? localSchemaObjects;
  final void Function(MutableSubscriptionSet mutableSubscriptions, Realm realm)
      subscriptionCallback;
  final void Function(SyncError error, BuildContext context)? syncErrorCallback;
  late final GlobalKey<NavigatorState> navigatorKey;

  MongoDataWrapper._internal({
    super.key,
    required Widget child,
    required this.schemaObjects,
    required this.subscriptionCallback,
    this.localSchemaObjects,
    TransitionBuilder? builder,
    VisualDensity? visualDensity,
    List<Locale>? supportedLocales,
    required this.navigatorKey,
    this.syncErrorCallback,
  }) : super(
            child: supportedLocales != null
                ? EasyLocalization(
                    supportedLocales: supportedLocales,
                    path: 'assets/translations',
                    fallbackLocale: supportedLocales.first,
                    child: Builder(builder: (context) {
                      return MaterialApp(
                        navigatorKey: navigatorKey,
                        theme: ThemeData(
                          useMaterial3: true,
                          visualDensity: visualDensity,
                        ),
                        builder: builder,
                        localizationsDelegates: context.localizationDelegates,
                        supportedLocales: context.supportedLocales,
                        locale: context.locale,
                        home: LoaderOverlay(
                          useDefaultLoading: false,
                          overlayWidgetBuilder: (progress) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          child: child,
                        ),
                      );
                    }),
                  )
                : MaterialApp(
                    navigatorKey: navigatorKey,
                    theme: ThemeData(
                      useMaterial3: true,
                    ),
                    home: LoaderOverlay(
                      useDefaultLoading: false,
                      overlayWidgetBuilder: (progress) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      child: child,
                    ),
                  )) {
    _initRealm();
  }

  factory MongoDataWrapper({
    required Widget child,
    required List<SchemaObject> schemaObjects,
    required void Function(
            MutableSubscriptionSet mutableSubscriptions, Realm realm)
        subscriptionCallback,
    List<SchemaObject>? localSchemaObjects,
    TransitionBuilder? builder,
    VisualDensity? visualDensity,
    List<Locale>? supportedLocales,
    void Function(SyncError error, BuildContext context)? syncErrorCallback,
  }) {
    GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    return MongoDataWrapper._internal(
      schemaObjects: schemaObjects,
      subscriptionCallback: subscriptionCallback,
      localSchemaObjects: localSchemaObjects,
      syncErrorCallback: syncErrorCallback,
      navigatorKey: navigatorKey,
      supportedLocales: supportedLocales,
      builder: builder,
      visualDensity: visualDensity,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(covariant MongoDataWrapper oldWidget) {
    return realm != oldWidget.realm || localRealm != oldWidget.localRealm;
  }

  static MongoDataWrapper? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MongoDataWrapper>();
  }

  dynamic customData() {
    return _app.currentUser?.customData;
  }

  logOut({required BuildContext context}) {
    context.loaderOverlay.show();
    try {
      _app.currentUser?.logOut().then((value) {
        var tempRealm = realm.value;
        realm.value = null;
        tempRealm?.close();

        tempRealm = localRealm.value;
        localRealm.value = null;
        tempRealm?.close();
        context.loaderOverlay.hide();
      });
    } catch (e) {
      context.loaderOverlay.hide();
    }
  }

  logIn(
      {required Credentials credentials,
      required BuildContext context,
      required String appId}) async {
    context.loaderOverlay.show();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('appId', appId);
    await _app.logIn(credentials);
    await _initRealm();
    context.loaderOverlay.hide();
  }

  _initRealm() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? appId = prefs.getString('appId');
    if (appId == null) {
      return;
    }
    _appConfig = AppConfiguration(appId);
    _app = App(_appConfig);
    if (_app.currentUser != null) {
      _app.currentUser!.refreshCustomData();
      final syncConfiguration =
          Configuration.flexibleSync(_app.currentUser!, schemaObjects,
              syncErrorHandler: (SyncError error) {
        if (kDebugMode) {
          print("Error message${error.message}");
          BuildContext context = navigatorKey.currentState!.overlay!.context;
          syncErrorCallback?.call(error, context);
        }
        Sentry.captureException(
          error,
        );
        if (error.message?.contains("breaking schema change") == true) {
          _resetLocalDatabase();
        }
      });
      realm.value = Realm(syncConfiguration);

      if (localSchemaObjects != null) {
        final localConfiguration = Configuration.local(localSchemaObjects!,
            shouldDeleteIfMigrationNeeded: true);
        localRealm.value = Realm(localConfiguration);
      }

      realm.value?.subscriptions.update((mutableSubscriptions) {
        subscriptionCallback.call(mutableSubscriptions, realm.value!);
      });
    }
  }

  _resetLocalDatabase() {
    var tempRealm = realm.value;
    if (tempRealm != null) {
      final path = tempRealm.config.path;
      _app.currentUser?.logOut().then((value) {
        realm.value = null;
        tempRealm?.close();
        tempRealm = localRealm.value;
        localRealm.value = null;
        tempRealm?.close();
        Realm.deleteRealm(path);
        _initRealm();
      });
    }
  }
}
