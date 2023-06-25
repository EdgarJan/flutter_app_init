library flutter_app_init;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_init/mongo_data_wrapper/mongo_data_wrapper.dart';
import 'package:realm/realm.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
export 'package:realm/realm.dart';

appInit(
    {String? sentryDsn,
    required Widget body,
    required List<SchemaObject> schemaObjects,
    required void Function(
            MutableSubscriptionSet mutableSubscriptions, Realm realm)
        subscriptionCallback, required String realmAppId}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
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
          subscriptionCallback: subscriptionCallback,
          child: body,
        ),
      ),
    );
  }
}