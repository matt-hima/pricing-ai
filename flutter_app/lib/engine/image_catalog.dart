/// 圖片產生（stable-diffusion.cpp 的 sd-cli）與 GGUF 模型目錄。
/// 引擎固定在已知可用的發行版；模型選授權允許商用的（CreativeML OpenRAIL-M / OpenRAIL++）。
const sdCppTag = 'master-1015-e41fbcf';

class SdAsset {
  final String name;
  final int approxMB;
  const SdAsset(this.name, this.approxMB);
  Uri get url => Uri.parse('https://github.com/leejet/stable-diffusion.cpp/releases/download/$sdCppTag/$name');
}

/// macOS 只有 Apple Silicon 版；Windows 用 Vulkan 版（NVIDIA / AMD / Intel 顯卡都能跑）
SdAsset? sdAssetFor({required bool isMac, required bool isWindows, required String version}) {
  if (isMac) return version.contains('arm64') ? const SdAsset('sd-master-e41fbcf-bin-Darwin-macOS-26.6.2-arm64.zip', 36) : null;
  if (isWindows) return version.contains('arm64') ? null : const SdAsset('sd-master-e41fbcf-bin-win-vulkan-x64.zip', 29);
  return null;
}

class ImageModelSpec {
  final String id, label, repo, file, license;
  final int sizeMB, width, height, steps;
  final double cfg;
  const ImageModelSpec(this.id, this.label, this.repo, this.file, this.sizeMB, this.license, {this.width = 512, this.height = 320, this.steps = 20, this.cfg = 7});

  Uri get url => Uri.parse('https://huggingface.co/$repo/resolve/main/$file');
}

const imageModels = <ImageModelSpec>[
  ImageModelSpec('sd15', 'Stable Diffusion 1.5 (Q4_0)', 'gpustack/stable-diffusion-v1-5-GGUF', 'stable-diffusion-v1-5-Q4_0.gguf', 1666, 'CreativeML OpenRAIL-M'),
  ImageModelSpec('sd21', 'Stable Diffusion 2.1 (Q4_0)', 'gpustack/stable-diffusion-v2-1-GGUF', 'stable-diffusion-v2-1-Q4_0.gguf', 2084, 'OpenRAIL++', width: 640, height: 384),
  ImageModelSpec('sdxl', 'SDXL base 1.0 (Q4_0)', 'gpustack/stable-diffusion-xl-base-1.0-GGUF', 'stable-diffusion-xl-base-1.0-Q4_0.gguf', 3757, 'OpenRAIL++', width: 1024, height: 576, cfg: 6),
  ImageModelSpec('sdxl-q8', 'SDXL base 1.0 (Q8_0, higher quality)', 'gpustack/stable-diffusion-xl-base-1.0-GGUF', 'stable-diffusion-xl-base-1.0-Q8_0.gguf', 4807, 'OpenRAIL++', width: 1024, height: 576, cfg: 6),
];

ImageModelSpec? imageModelFor(String id) {
  for (final m in imageModels) {
    if (m.id == id) return m;
  }
  return null;
}

/// 給圖片模型的提示詞：把屋主的描述放進固定的攝影風格，並避開文字 / 人臉變形等常見失敗
String imagePrompt(String description) => 'professional photo, $description, soft natural light, clean composition, high detail, wide banner';

const imageNegative = 'text, letters, watermark, logo, blurry, low quality, deformed, extra fingers, cropped';
