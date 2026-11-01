/// 本機推論引擎（llama.cpp 官方發行版的 llama-server）與 GGUF 模型目錄。
/// 引擎固定在已知可用的 tag，避免上游改名 / 改參數造成不相容。
const llamaCppTag = 'b11878';

enum ArchiveKind { zip, tarGz }

class EngineAsset {
  final String name;
  final ArchiveKind kind;
  final int approxMB;
  const EngineAsset(this.name, this.kind, this.approxMB);
  Uri get url => Uri.parse('https://github.com/ggml-org/llama.cpp/releases/download/$llamaCppTag/$name');
}

/// 依作業系統 / 架構挑引擎。macOS 的預設建置內含 Metal；Windows 用 Vulkan 版，
/// NVIDIA / AMD / Intel 顯卡都能跑（不需要另外裝 CUDA）。[version] 傳入 Platform.version。
EngineAsset? engineAssetFor({required bool isMac, required bool isWindows, required String version}) {
  final arm = version.contains('arm64');
  if (isMac) {
    return arm
        ? const EngineAsset('llama-$llamaCppTag-bin-macos-arm64.tar.gz', ArchiveKind.tarGz, 16)
        : const EngineAsset('llama-$llamaCppTag-bin-macos-x64.tar.gz', ArchiveKind.tarGz, 12);
  }
  if (isWindows) {
    return arm
        ? const EngineAsset('llama-$llamaCppTag-bin-win-vulkan-arm64.zip', ArchiveKind.zip, 25)
        : const EngineAsset('llama-$llamaCppTag-bin-win-vulkan-x64.zip', ArchiveKind.zip, 37);
  }
  return null;
}

class ModelSpec {
  /// 與 config.dart 的 ModelOption.base 對應
  final String base;
  final String repo, file;
  final int sizeMB;

  /// 是否用 GPU（false = 純 CPU，對應「CPU 版」選項）
  final bool gpu;
  const ModelSpec(this.base, this.repo, this.file, this.sizeMB, {this.gpu = true});

  Uri get url => Uri.parse('https://huggingface.co/$repo/resolve/main/$file');
}

const modelSpecs = <ModelSpec>[
  ModelSpec('Qwen2.5-0.5B-Instruct', 'Qwen/Qwen2.5-0.5B-Instruct-GGUF', 'qwen2.5-0.5b-instruct-q4_k_m.gguf', 491),
  ModelSpec('Qwen2.5-1.5B-Instruct', 'Qwen/Qwen2.5-1.5B-Instruct-GGUF', 'qwen2.5-1.5b-instruct-q4_k_m.gguf', 1117),
  ModelSpec('Qwen2.5-3B-Instruct', 'Qwen/Qwen2.5-3B-Instruct-GGUF', 'qwen2.5-3b-instruct-q4_k_m.gguf', 2105),
  ModelSpec('Qwen2.5-7B-Instruct', 'bartowski/Qwen2.5-7B-Instruct-GGUF', 'Qwen2.5-7B-Instruct-Q4_K_M.gguf', 4683),
  ModelSpec('Llama-3.1-8B-Instruct', 'bartowski/Meta-Llama-3.1-8B-Instruct-GGUF', 'Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf', 4921),
  ModelSpec('cpu:qwen2.5-0.5b', 'Qwen/Qwen2.5-0.5B-Instruct-GGUF', 'qwen2.5-0.5b-instruct-q4_k_m.gguf', 491, gpu: false),
  ModelSpec('cpu:qwen2.5-1.5b', 'Qwen/Qwen2.5-1.5B-Instruct-GGUF', 'qwen2.5-1.5b-instruct-q4_k_m.gguf', 1117, gpu: false),
];

ModelSpec? modelSpecFor(String base) {
  for (final m in modelSpecs) {
    if (m.base == base) return m;
  }
  return null;
}
