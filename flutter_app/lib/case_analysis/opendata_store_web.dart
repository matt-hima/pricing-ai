import 'opendata.dart';

/// 網頁版：瀏覽器的跨網站限制讀不到採購網的檔案，官方資料集只在 Mac / Windows App 提供
const datasetAvailable = false;

Future<List<DatasetAward>> loadDataset(List<String> files, {void Function(int done, int total)? onProgress}) async => const [];
