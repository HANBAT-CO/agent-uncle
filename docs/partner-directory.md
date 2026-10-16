# 거래처 디렉터리/공개 코드 백엔드 메모

## 범위
- 완료 계정의 연락처 중복을 한국 전화번호 정규화 기준으로 차단한다.
- 모든 계정에 불변 공개 코드 `#0000` 형식의 `publicCode`를 부여한다.
- 반대 역할 완료 계정만 검색하는 거래처 디렉터리 RPC를 제공한다.
- 디렉터리 검색 결과로도 연결 요청(`connect`)을 보낼 수 있게 한다.

## 연락처 중복 정책
- 정규화 기준은 `+82`, 공백, 하이픈을 제거하고 `82` 국가번호를 `0`으로 되돌린 값이다.
- 클라이언트는 `SessionRepository.checkPhoneAvailable(String phone)`로 사전 확인만 수행한다.
- 서버 최종 검증은 `saip_private.claim_phone`이 담당한다. 완료 저장 시 `phone_claims.normalized_phone` 고유 제약으로 경쟁 가입을 원자적으로 막는다.
- 자기 계정의 현재 번호는 허용한다. 응답은 `boolean`만 반환하고, 어떤 계정이 쓰는지는 공개하지 않는다.

## 운영 중복 데이터 안전 전략
- 기존 중복 연락처는 삭제하거나 덮어쓰지 않는다.
- 마이그레이션은 완료 계정 연락처를 스캔해 유일한 번호만 `saip_private.phone_claims`에 백필한다.
- 중복 번호는 `saip_private.phone_claim_conflicts`에 기록만 남긴다.
- 충돌 번호를 가진 기존 완료 계정은 이후 프로필 완료 저장에서 같은 번호를 유지할 수 없고, 다른 번호로 정리해야 한다.

## 공개 코드
- `saip_private.public_codes`가 `#0000` 형식과 계정별 유일성을 강제한다.
- `saip_private.assign_public_code`는 기존 코드를 재사용하고, 없으면 랜덤 재시도 후 전체 슬롯을 선형 탐색한다.
- 10,000개 슬롯이 모두 소진되면 명시적인 오류를 반환한다.
- 기존 invite code(`code`, `codeExpires`)는 그대로 유지하고 lookup/connect 흐름과 병행한다.

## 거래처 검색 공개 범위
- 검색 대상은 `complete = true`, 반대 역할, 본인 제외 계정만이다.
- 검색 키워드는 `nickname` 또는 기존 `name` 부분검색, `#1234` exact `publicCode`, 공개 지역(`pickupArea`/`deliveryArea`) 문자열, 건당 수수료 범위다.
- fee 필터를 쓰면 `fee` 미등록 계정은 제외하고 `0`은 무료로 취급한다.
- 반환 필드는 `name`, `nickname`, `publicCode`, `role`, `complete`, `photoId`, `pickupArea`, `deliveryArea`, `deadline`, `holiday`, `intro`, `working`, `fee`만 포함한다.
- 연락처, 상세주소, 사업자 서류, 이메일, 동의 메타데이터는 디렉터리와 코드 lookup 모두에서 숨긴다.

## connect 변경
- `connect(peerId, opId)`는 더 이상 invite code 조회 선행을 요구하지 않는다.
- 자기 자신, 같은 역할, 미완성 계정, 중복/보류 중 연결은 서버와 로컬에서 모두 차단한다.
- 실제 요청/채팅은 기존처럼 연결 수락 이후에만 허용한다.

## profile metadata 추가
- 허용 키: `nickname`, `fee`, `postcode`, `addressSource`, `addressRoad`, `addressJibun`.
- 도로명/지번 주소는 프로필 내부 저장용 메타데이터이며 공개 검색 지역 조건에는 사용하지 않는다.

## 가입 화면과 거래처 연결
- 연락처는 각 가입 단계와 최종 완료 직전에 중복 여부를 확인한다. 중복이면 해당 입력으로 이동하고 오류를 표시한다.
- 주소는 [카카오 우편번호 서비스](https://postcode.map.kakao.com/guide)의 검색 결과를 선택해 등록한다. 우편번호와 도로명·지번 주소를 보관하고 상세주소는 별도로 입력한다.
- iOS는 `WKWebView`, Android는 `WebView`에서 공식 주소검색 화면을 연다. 검색 취소, 네트워크 오류, 화면을 닫은 뒤 도착하는 응답을 구분해 처리한다.
- Web은 검색 스크립트를 준비한 뒤 사용자가 버튼을 눌러 팝업을 연다. 팝업 차단과 로딩 실패를 안내하며, 직접 창을 닫으면 검색을 취소한다.
- `AddressSearchGateway`의 `prepare`, `search`, `cancel`을 통해 플랫폼별 검색 수명주기를 관리한다. 반환 주소는 우편번호 5자리, 선택한 주소, `kakao_postcode` 출처를 검증한다.
- 거래처 연결 화면에서 일반 검색과 초대코드를 선택할 수 있다. 코드 입력은 복사·붙여넣기를 지원하고, 공개 코드 복사와 기존 초대코드 갱신을 제공한다.
- 이름·닉네임·공개 코드 검색, 지역과 건당 수수료 필터를 조합한다. 검색은 350ms 지연 후 실행하며 페이지당 20개를 읽고 이전 검색의 늦은 응답은 무시한다.

## 채팅 사진과 뒤로가기
- 채팅의 사진 버튼에서 `사진 촬영` 또는 `갤러리에서 선택`을 고르면 실제 카메라나 시스템 사진 선택기를 연다. 사업자 서류 등 일반 파일 첨부는 기존 경로를 유지한다.
- iOS는 `UIImagePickerController`와 `PHPickerViewController`, Android는 `ActivityResultContracts.TakePicture`와 `PickVisualMedia`를 사용한다. Android 촬영 결과는 캐시의 `FileProvider` URI로 전달한다.
- 네이티브 사진은 JPEG·PNG로 전달하고, 필요한 경우 HEIC 등을 JPEG로 변환한다. 파일 형식과 10MB 제한을 검증하며 취소·권한 거절·읽기 실패를 처리한다.
- Web 촬영은 브라우저의 `capture` 입력을 사용하므로 실제 촬영 지원은 브라우저에 따라 달라진다.
- Android 시스템 뒤로가기는 현재 로그인 내비게이터와 활성 탭의 상세 화면으로 전달한다. 비활성 탭의 화면은 유지하며, 초안 저장이 계속 실패하면 작성 화면을 닫지 않는다.

## 적용 시 참고
- 연락처 사전 조회는 2026-10-13에 `202610120001_signup_phone_availability.sql`로 복구했다. 2026-10-16에는 `202610130001_partner_directory.sql`을 포함한 누적 변경을 운영에 배포해 공개 코드 백필·거래처 검색·최종 저장 시 연락처 선점도 반영했다. 후속 배포는 [공유 DB 이력 처리](supabase.md#공유-db의-마이그레이션-이력-처리)에 따라 원격 이력과 `--include-all` dry-run 대상을 확인한다.
- 카메라·갤러리·주소검색의 네이티브 코드는 앱을 다시 빌드해야 반영된다. Dart 핫 리로드만으로는 추가되지 않는다.
- 약관·개인정보 페이지와 백오피스 연동은 요청에 따라 보류했다.

## 구현 메모
- 기존 `saip_command` 구조와 idempotency를 유지해야 해서 helper 함수들을 추가한 뒤 `saveProfile`/`connect` 분기만 확장하는 방식으로 migration을 작성했다.
- 로컬 저장소도 같은 공개 필드 컷을 적용해 remote/local parity를 맞췄다.
