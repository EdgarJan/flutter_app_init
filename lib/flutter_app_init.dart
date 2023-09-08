library flutter_app_init;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_init/mongo_data_wrapper/mongo_data_wrapper.dart';
import 'package:realm/realm.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
export 'package:easy_localization/easy_localization.dart';
// carry on sentry ignore
// ignore: invalid_export_of_internal_element
export 'package:sentry_flutter/sentry_flutter.dart';
export 'package:loader_overlay/loader_overlay.dart';

appInit(
    {String? sentryDsn,
    required Widget body,
    required List<SchemaObject> schemaObjects,
    required void Function(
            MutableSubscriptionSet mutableSubscriptions, Realm realm,)
        subscriptionCallback,
    required String realmAppId,
    List<SchemaObject>? localSchemaObjects,
    TransitionBuilder? builder,
    VisualDensity? visualDensity,
    List<Locale>? supportedLocales}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supportedLocales != null){
    await EasyLocalization.ensureInitialized();
  }
  if (sentryDsn != null) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(
        MongoDataWrapper(
          appId: realmAppId,
          schemaObjects: schemaObjects,
          localSchemaObjects: localSchemaObjects,
          subscriptionCallback: subscriptionCallback,
          supportedLocales: supportedLocales,
          builder: builder,
          visualDensity: visualDensity,
          child: body,
        ),
      ),
    );
  } else {
    runApp(
      MongoDataWrapper(
        appId: realmAppId,
        schemaObjects: schemaObjects,
        localSchemaObjects: localSchemaObjects,
        subscriptionCallback: subscriptionCallback,
        supportedLocales: supportedLocales,
        builder: builder,
        visualDensity: visualDensity,
        child: body,
      ),
    );
  }
}
