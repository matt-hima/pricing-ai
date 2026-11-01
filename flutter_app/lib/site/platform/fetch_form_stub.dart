/// 網頁版：瀏覽器不允許讀取其他網站（Google）的頁面，所以不能自動抓取；改由使用者貼上頁面原始碼。
const canFetchForm = false;

Future<({String html, String url})> fetchFormPage(String url) async => throw UnsupportedError('fetch');
