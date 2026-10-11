# 프로필 이미지

내 정보, 가입·프로필 수정, 거래처 목록·상세, 초대 코드 검색 결과, 채팅 목록에서
공통 `ProfileAvatar`를 사용한다.

- 내 정보·프로필 수정·거래처 상세의 큰 사진은 88px, 사입삼촌 연결 카드의 사진은 64px이다.
  채팅 등 일반 목록은 40px을 유지하며, 모두 TDS 원형 프레임을 사용한다.

- 본인 또는 연결을 수락한 거래처의 `photoId`가 있으면 기존 첨부 저장소에서 사진 바이트를 읽는다.
  Supabase에서는 기존 Storage RLS와 `saip_attachment_path` 권한 검사를 유지한다.
- 사진이 없으면 `https://api.dicebear.com/9.x/lorelei/png?seed=<계정 ID>&size=160`을 호출한다.
  신규·기존 계정 모두 적용하며 별도 서버 마이그레이션은 없다.
- 계정 생성 시 무작위로 발급되는 ID를 seed로 사용한다. 계정마다 다른 얼굴이 생성되며
  새로고침·재로그인·이름 변경에도 유지된다. 이름·이메일·전화번호·등록 사진은 DiceBear로 보내지 않는다.
- 사진 첨부·교체·삭제를 바로 반영한다. 비동기로 읽던 이전 계정·사진의 결과는 새 프로필에 표시하지 않는다.
- 사진 읽기·디코딩 실패 시 Lorelei를 표시한다. DiceBear 로딩 중이나 API 실패·오프라인 상태에서는
  기존 인물 아이콘을 표시한다. 연결 전에는 상대방의 비공개 사진을 요청하지 않고 기본 아바타를 표시한다.
- 기본 아바타는 TDS 이미지 컴포넌트의 네트워크 이미지 캐시를 사용한다. 영구 오프라인 보관은 하지 않는다.

## TDS 지원

기존 `TdsAssetImage`에 `memory` 생성자, `placeholder`, `errorBuilder`를 추가했다.
앱의 사진·아바타는 모두 이 컴포넌트와 `TdsAssetFrames`의 원형 프레임으로 표시한다.
바이트 사진을 표시하기 위해 공개 URL을 만들거나 새 UI 패키지를 설치하지 않는다.

## 이미지 출처

[DiceBear Lorelei](https://www.dicebear.com/styles/lorelei/)는
[Lisa Wischofsky](https://www.instagram.com/lischi_art/)의 스타일이며
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)으로 제공된다.

## 검증

`test/local/profile_avatar_test.dart`에서 계정별 seed, 등록 사진 우선 표시,
사진 교체·삭제·읽기 실패·손상된 사진, 계정 전환, 연결 전 접근 제한과 API 실패 대체 표시를 확인한다.
