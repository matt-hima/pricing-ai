import 'case_store.dart';

/// 網頁版沒有案件資料庫（官方資料與即時查詢都只在 Mac / Windows App 提供）
const caseStoreAvailable = false;

Future<CaseStore?> openCaseStore() async => null;
