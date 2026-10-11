// 사용자 SVG 원본에서 플랫폼별 아이콘과 시작 화면 이미지를 생성한다.
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');

const root = path.resolve(__dirname, '../..');
const check = process.argv.includes('--check');
const sourcePath = 'assets/logos/samchun_app_icon.svg';
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
const generated = [];

async function save(relativePath, bytes) {
  const destination = path.join(root, relativePath);
  if (check) {
    const actual = await fs.readFile(destination);
    if (!actual.equals(bytes)) throw new Error(`재생성이 필요합니다: ${relativePath}`);
  } else {
    await fs.mkdir(path.dirname(destination), { recursive: true });
    await fs.writeFile(destination, bytes);
  }
  generated.push(relativePath);
}

async function main() {
  const source = await fs.readFile(path.join(root, sourcePath));
  // 원본 SVG는 수정하지 않는다. 불투명 흰 배경은 iOS 아이콘에도 필요하다.
  const master = await sharp(source, { density: 144 })
    .resize(1024, 1024)
    .flatten({ background: '#ffffff' })
    .removeAlpha()
    .png()
    .toBuffer();
  const raster = (size) => sharp(master).resize(size, size).png().toBuffer();
  const padded = async (size, artworkSize, transparent = false) => {
    const artwork = await raster(artworkSize);
    const offset = Math.floor((size - artworkSize) / 2);
    let result = sharp({
      create: {
        width: size,
        height: size,
        channels: 4,
        background: transparent ? { r: 255, g: 255, b: 255, alpha: 0 } : '#ffffff',
      },
    }).composite([{ input: artwork, left: offset, top: offset }]);
    if (!transparent) result = result.removeAlpha();
    return result.png().toBuffer();
  };

  await save('assets/logos/samchun_app_icon.png', master);
  const iosCatalog = JSON.parse(await fs.readFile(
    path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'),
    'utf8',
  ));
  const iosSizes = new Map();
  for (const item of iosCatalog.images) {
    iosSizes.set(item.filename, Math.round(parseFloat(item.size) * parseFloat(item.scale)));
  }
  for (const [filename, size] of iosSizes) {
    await save(`ios/Runner/Assets.xcassets/AppIcon.appiconset/${filename}`, await raster(size));
  }
  for (const scale of [1, 2, 3]) {
    const suffix = scale === 1 ? '' : `@${scale}x`;
    await save(`ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${suffix}.png`, await raster(192 * scale));
  }

  for (const [density, scale] of Object.entries(densities)) {
    await save(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, await raster(48 * scale));
    // 108dp 적응형 캔버스의 중앙 72dp에 원본을 배치한다.
    // 원본에 포함된 여백과 함께 캐릭터가 시스템 마스크 안전 영역에 들어간다.
    await save(`android/app/src/main/res/drawable-${density}/ic_launcher_foreground.png`,
      await padded(108 * scale, 72 * scale, true));
    await save(`android/app/src/main/res/drawable-${density}/splash_logo.png`, await raster(192 * scale));
  }
  for (const size of [192, 512]) {
    await save(`web/icons/Icon-${size}.png`, await raster(size));
    await save(`web/icons/Icon-maskable-${size}.png`, await padded(size, Math.round(size * 0.8)));
  }
  await save('web/icons/apple-touch-icon.png', await raster(180));
  await save('web/favicon.png', await raster(48));
  await save('web/splash.png', await raster(576));
  await save('tool/brand_assets/source.json', Buffer.from(JSON.stringify({
    source: sourcePath,
    sha256: crypto.createHash('sha256').update(source).digest('hex'),
    splashLogicalSize: 192,
    files: [...generated].sort(),
  }, null, 2) + '\n'));
  console.log(`${check ? '검증' : '생성'} 완료: ${generated.length}개 파일`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
