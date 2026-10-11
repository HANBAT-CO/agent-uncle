# 시작 화면 이미지

사용자가 제공한 `assets/logos/samchun_app_icon.svg`에서 생성한다.
LaunchScreen은 흰 배경 중앙에 192pt로 표시하며, 1×/2×/3× 파일 크기는
각각 192/384/576px이다. 원본의 비율과 흑백 색상을 유지한다.

프로젝트 루트에서 `npm ci --prefix tool/brand_assets` 후
`npm run generate --prefix tool/brand_assets`로 재생성한다.
