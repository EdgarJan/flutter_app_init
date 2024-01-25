//Maybe it needs dispose method
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:realm/realm.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MongoDataWrapper extends InheritedWidget {
  final ValueNotifier<Realm?> realm = ValueNotifier<Realm?>(null);
  final ValueNotifier<Realm?> localRealm = ValueNotifier<Realm?>(null);
  final List<SchemaObject> schemaObjects;
  final List<SchemaObject>? localSchemaObjects;
  final void Function(MutableSubscriptionSet mutableSubscriptions, Realm realm)
      subscriptionCallback;
  final void Function(SyncError error, BuildContext context)? syncErrorCallback;
  late final GlobalKey<NavigatorState> _appKey;
  final MutableData mutableData = MutableData();

  factory MongoDataWrapper({
    required List<SchemaObject> schemaObjects,
    List<SchemaObject>? localSchemaObjects,
    required void Function(
            MutableSubscriptionSet mutableSubscriptions, Realm realm)
        subscriptionCallback,
    void Function(SyncError error, BuildContext context)? syncErrorCallback,
    TransitionBuilder? builder,
    List<Locale>? supportedLocales,
    VisualDensity? visualDensity,
    Key? key,
    required Widget child,
  }) {
    final GlobalKey<NavigatorState> appKey = GlobalKey<NavigatorState>();
    return MongoDataWrapper._(
      schemaObjects: schemaObjects,
      localSchemaObjects: localSchemaObjects,
      subscriptionCallback: subscriptionCallback,
      syncErrorCallback: syncErrorCallback,
      builder: builder,
      supportedLocales: supportedLocales,
      visualDensity: visualDensity,
      key: key,
      appKey: appKey,
      child: child,
    );
  }

  MongoDataWrapper._({
    required this.schemaObjects,
    this.localSchemaObjects,
    required this.subscriptionCallback,
    this.syncErrorCallback,
    TransitionBuilder? builder,
    List<Locale>? supportedLocales,
    VisualDensity? visualDensity,
    Key? key,
    required Widget child,
    required GlobalKey<NavigatorState> appKey,
  })  : _appKey = appKey,
        super(
            child: MaterialAppWrapper(
          builder: builder,
          visualDensity: visualDensity,
          supportedLocales: supportedLocales,
          key: appKey,
          child: child,
        )) {
    _initApp().then((_) {
      _initRealm();
    });
  }

  @override
  bool updateShouldNotify(covariant MongoDataWrapper oldWidget) {
    return realm != oldWidget.realm || localRealm != oldWidget.localRealm;
  }

  static MongoDataWrapper? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MongoDataWrapper>();
  }

  dynamic customData() {
    return mutableData.app?.currentUser?.customData;
  }

  logOut() async {
    _appKey.currentContext?.loaderOverlay.show();
    try {
      await mutableData.app?.currentUser?.logOut();
      var tempRealm = realm.value;
      realm.value = null;
      tempRealm?.close();
      tempRealm = localRealm.value;
      localRealm.value = null;
      tempRealm?.close();
      mutableData.app = null;
      _appKey.currentContext?.loaderOverlay.hide();
      mutableData.appConfig = null;
    } catch (e) {
      _appKey.currentContext?.loaderOverlay.hide();
    }
  }

  logIn({required Credentials credentials, required String appId}) async {
    if (mutableData.app?.currentUser != null) {
      _appKey.currentContext?.loaderOverlay.show();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('appId', appId);
      await _initApp();
      await mutableData.app!.logIn(credentials);
      await _initRealm();
      _appKey.currentContext?.loaderOverlay.hide();
    }
  }

  _initApp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? appId = prefs.getString('appId');
    if (appId == null) {
      return;
    }
    mutableData.appConfig = AppConfiguration(appId);
    mutableData.app = App((mutableData.appConfig)!);
  }

  _initRealm() {
    if (mutableData.app?.currentUser != null) {
      mutableData.app!.currentUser!.refreshCustomData();
      final syncConfiguration = Configuration.flexibleSync(
          (mutableData.app!.currentUser)!, schemaObjects,
          syncErrorHandler: (SyncError error) {
        if (kDebugMode) {
          print("Error message${error.message}");
          BuildContext context = _appKey.currentState!.context;
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
      mutableData.app!.currentUser?.logOut().then((value) {
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

class MutableData {
  AppConfiguration? appConfig;
  App? app;
}

class MaterialAppWrapper extends StatelessWidget {
  final Widget child;
  final List<Locale>? supportedLocales;
  final TransitionBuilder? builder;
  final VisualDensity? visualDensity;

  const MaterialAppWrapper({
    super.key,
    required this.child,
    this.supportedLocales,
    this.builder,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context) {
    return supportedLocales != null
        ? EasyLocalization(
            supportedLocales: supportedLocales!,
            path: 'assets/translations',
            fallbackLocale: supportedLocales!.first,
            child: Builder(builder: (context) {
              return _buildMaterialApp(context, true);
            }),
          )
        : _buildMaterialApp(context, false);
  }

  Widget _buildMaterialApp(BuildContext context, bool isLocalized) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: visualDensity,
      ),
      builder: builder,
      localizationsDelegates:
          isLocalized ? context.localizationDelegates : null,
      supportedLocales: isLocalized
          ? context.supportedLocales
          : <Locale>[const Locale('en', 'US')],
      locale: isLocalized ? context.locale : null,
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
  }
}

//why we need iternal constructor?
// here is example of widget we cannot do without internal constructor
// class Test1 extends InheritedWidget {
//   final GlobalKey<_Test1MaterialAppState> materialAppKey;

//   Test1({super.key, required Widget child})
//       : materialAppKey = GlobalKey<_Test1MaterialAppState>(),
//         super(child: _Test1MaterialApp(key: materialAppKey, child: child));

//   static Test1 of(BuildContext context) {
//     final Test1? result = context.dependOnInheritedWidgetOfExactType<Test1>();
//     assert(result != null, 'No Test1 found in context');
//     return result!;
//   }

//   @override
//   bool updateShouldNotify(Test1 oldWidget) {
//     // Check if the state of _Test1MaterialApp has changed
//     return oldWidget.materialAppKey.currentState?.hasStateChanged ?? false;
//   }
// }

// class _Test1MaterialApp extends StatefulWidget {
//   final Widget child;

//   const _Test1MaterialApp({Key? key, required this.child}) : super(key: key);

//   @override
//   _Test1MaterialAppState createState() => _Test1MaterialAppState();
// }

// class _Test1MaterialAppState extends State<_Test1MaterialApp> {
//   bool hasStateChanged = false;

//   void changeState() {
//     setState(() {
//       hasStateChanged = !hasStateChanged; // Change some internal state
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       home: Scaffold(
//         appBar: AppBar(
//           title: Text('Home Page'),
//         ),
//         body: widget.child,
//       ),
//     );
//   }
// }