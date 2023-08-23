//Maybe it needs dispose method
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:realm/realm.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
      required this.subscriptionCallback,
      TransitionBuilder? builder,
      VisualDensity? visualDensity,
      List<Locale>? supportedLocales})
      : _appId = appId,
        super(
            key: key,
            child: supportedLocales != null
                ? EasyLocalization(
                    supportedLocales: supportedLocales,
                    path: 'assets/translations',
                    fallbackLocale: supportedLocales.first,
                    child: Builder(builder: (context) {
                      return MaterialApp(
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
                          overlayWidget: const Center(
                            child: CircularProgressIndicator(),
                          ),
                          child: child,
                        ),
                      );
                    }),
                  )
                : MaterialApp(
                    theme: ThemeData(
                      useMaterial3: true,
                    ),
                    home: LoaderOverlay(
                      useDefaultLoading: false,
                      overlayWidget: const Center(
                        child: CircularProgressIndicator(),
                      ),
                      child: child,
                    ),
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

  dynamic customData() {
    return _app.currentUser?.customData;
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
      _app.currentUser!.refreshCustomData();
      final configuration =
          Configuration.flexibleSync(_app.currentUser!, schemaObjects,
              syncErrorHandler: (SyncError error) {
        if (kDebugMode) {
          print("Error message${error.message}");
        }
        Sentry.captureException(
          error,
        );
      });
      realm.value = Realm(configuration);

      realm.value?.subscriptions.update((mutableSubscriptions) {
        subscriptionCallback.call(mutableSubscriptions, realm.value!);
      });
    }
  }
}
