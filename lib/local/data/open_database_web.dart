import 'package:sembast_web/sembast_web.dart';

Future<Database> openLocalDatabase() =>
    databaseFactoryWeb.openDatabase('saipsamchun-v1', version: 1);
