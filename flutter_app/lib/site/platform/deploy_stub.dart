/// 網頁版無法執行本機指令，部署只在 Windows / macOS 桌面版提供；網頁版請匯出 ZIP。
const canDeploy = false;

Stream<String> loginFirebase() => const Stream.empty();

Stream<String> deploySite(String html, {required String project, String hostingSite = '', String url = ''}) => const Stream.empty();
