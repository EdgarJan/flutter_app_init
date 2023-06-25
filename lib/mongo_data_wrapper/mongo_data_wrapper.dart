//Maybe it needs dispose method
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:realm/realm.dart';

class MongoDataWrapper extends InheritedWidget {
  final String _appId;
  late final AppConfiguration _appConfig;
  late final App _app;
  final ValueNotifier<Realm?> realm = ValueNotifier<Realm?>(null);
  final List<SchemaObject> schemaObjects;
  final void Function(MutableSubscriptionSet mutableSubscriptions, Realm realm)
      subscriptionCallback;

  MongoDataWrapper(
      {Key? key,
      required String appId,
      required Widget child,
      required this.schemaObjects,
      required this.subscriptionCallback})
      : _appId = appId,
        super(
            key: key,
            child: EasyLocalization(
              supportedLocales: const [
                Locale('en'),
                Locale('ru'),
                Locale('lt')
              ],
              path: 'assets/translations',
              fallbackLocale: const Locale('en'),
              child: Builder(builder: (context) {
                return MaterialApp(
                  theme: ThemeData(
                    useMaterial3: true,
                  ),
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: LoaderOverlay(
                    useDefaultLoading: false,
                    overlayWidget: const Center(
                      child: CircularProgressIndicator(),
                    ),
                    child: child,
                  ),
                );
              }),
            )) {
    _appConfig = AppConfiguration(_appId);
    _app = App(_appConfig);
    _initRealm();
  }

  @override
  bool updateShouldNotify(covariant MongoDataWrapper oldWidget) {
    return oldWidget._appId != _appId || realm != oldWidget.realm;
  }

  static MongoDataWrapper? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MongoDataWrapper>();
  }

  logOut({required BuildContext context}) {
    context.loaderOverlay.show();
    try {
      _app.currentUser?.logOut().then((value) {
        final tempRealm = realm.value;
        realm.value = null;
        tempRealm?.close();
        context.loaderOverlay.hide();
      });
    } catch (e) {
      context.loaderOverlay.hide();
    }
  }

  logIn(
      {required Credentials credentials, required BuildContext context}) async {
    context.loaderOverlay.show();
    _app.logIn(credentials).then((value) {
      _initRealm();
      context.loaderOverlay.hide();
    });
  }

  _initRealm() {
    if (_app.currentUser != null) {
      final configuration =
          Configuration.flexibleSync(_app.currentUser!, schemaObjects);
      Realm? tempRealm;
      tempRealm = Realm(configuration);
      tempRealm.subscriptions.update((mutableSubscriptions) {
        subscriptionCallback.call(mutableSubscriptions, tempRealm!);
      });
      realm.value = tempRealm;
    }
  }
}
