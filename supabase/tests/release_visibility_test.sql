begin;
select no_plan();
insert into auth.users(id,email) values
 ('81111111-1111-4111-8111-111111111111','release-retailer@example.test'),
 ('82222222-2222-4222-8222-222222222222','release-uncle@example.test');
select saip_private.put('accounts','81111111-1111-4111-8111-111111111111',
 '{"role":"retailer","complete":true}',array['81111111-1111-4111-8111-111111111111']::uuid[]);
select saip_private.put('accounts','82222222-2222-4222-8222-222222222222',
 '{"role":"uncle","complete":true}',array['82222222-2222-4222-8222-222222222222']::uuid[]);

select is(saip_private.project_app_release(
 '{"public":true,"published":true,"build":20,"roles":["retailer"],"internalNote":"비밀","readers":["내부"]}',
 '81111111-1111-4111-8111-111111111111'),
 '{"public":true,"published":true,"build":20}'::jsonb,'공개 필드만 반환');
select is(saip_private.project_app_release('{"public":true,"roles":["uncle"],"platforms":{"ios":{"roles":["retailer"]}}}',
 '81111111-1111-4111-8111-111111111111'),null::jsonb,'하위 설정으로 부모 대상 조건 우회 불가');
select is(saip_private.project_app_release('{"public":true,"build":20,"platforms":{"ios":{"public":false}}}',
 '81111111-1111-4111-8111-111111111111'),null::jsonb,'모든 플랫폼이 비공개면 공통 빌드를 대신 노출하지 않음');
select is(saip_private.project_app_release(
 '{"public":true,"platforms":{"ios":{"publicAt":"2999-01-01"},"android":{"body":"공개","userIds":["81111111-1111-4111-8111-111111111111"],"internalNote":"비밀"}}}',
 '81111111-1111-4111-8111-111111111111')->'platforms',
 '{"android":{"public":true,"platform":"android","body":"공개"}}'::jsonb,
 '미래 플랫폼은 제외하고 공개 플랫폼의 표시 필드만 반환');
select ok(not saip_private.convenience_release_visible('{"public":true,"published":true,"enabled":false}',
 '81111111-1111-4111-8111-111111111111'),'한 공개 플래그가 참이어도 비활성 플래그는 우회 불가');
select ok(not saip_private.convenience_release_visible('{"public":true,"publishedAt":"2020-01-01","startsAt":"2999-01-01"}',
 '81111111-1111-4111-8111-111111111111'),'모든 공개 시각을 확인');
select ok(not saip_private.convenience_release_visible('{"public":true,"publicAt":"잘못된 날짜"}',
 '81111111-1111-4111-8111-111111111111'),'잘못된 날짜는 비공개');
select ok(not saip_private.convenience_release_visible('{"public":true,"roles":["retailer"],"eligibleRoles":["uncle"]}',
 '81111111-1111-4111-8111-111111111111'),'역할 조건 별칭도 모두 확인');
select ok(not saip_private.convenience_release_visible('{"public":true,"userIds":["81111111-1111-4111-8111-111111111111"],"targetUserIds":["other"]}',
 '81111111-1111-4111-8111-111111111111'),'사용자 조건 별칭도 모두 확인');
select ok(not saip_private.convenience_release_visible('{"public":true,"roles":[null]}',
 '81111111-1111-4111-8111-111111111111'),'잘못된 대상 배열은 비공개');
select ok(not saip_private.convenience_release_visible('{"public":true,"userIds":"81111111-1111-4111-8111-111111111111"}',
 '81111111-1111-4111-8111-111111111111'),'배열이 아닌 대상자는 비공개');

select ok(not saip_private.convenience_release_visible('{"public":true,"publishedAt":"2020-01-01T00:00:00"}',
 '81111111-1111-4111-8111-111111111111'),'시간대 없는 공개 시각은 비공개');
select ok(not saip_private.convenience_release_visible('{"public":true,"publishedAt":"2020-01-01"}',
 '81111111-1111-4111-8111-111111111111'),'날짜만 있는 공개 시각은 비공개');
select ok(saip_private.convenience_release_visible('{"public":true,"publishedAt":"2020-01-01T00:00:00Z"}',
 '81111111-1111-4111-8111-111111111111'),'UTC 시각 공개');
select ok(saip_private.convenience_release_visible('{"public":true,"publishedAt":"2020-01-01T09:00:00+09:00"}',
 '81111111-1111-4111-8111-111111111111'),'명시된 시간대 시각 공개');
select ok(not saip_private.convenience_release_visible('{"public":true,"publishedAt":"2026-02-30T00:00:00Z"}',
 '81111111-1111-4111-8111-111111111111'),'존재하지 않는 날짜는 비공개');
select ok(not saip_private.convenience_release_visible('{"public":true,"publishedAt":"2020-01-01T24:00:00Z"}',
 '81111111-1111-4111-8111-111111111111'),'정규화가 필요한 시각은 비공개');
select ok(not saip_private.convenience_release_visible('{"public":true,"publishedAt":"2020-01-01T00:00:60Z"}',
 '81111111-1111-4111-8111-111111111111'),'잘못된 초는 비공개');

select saip_private.put('appReleases','visible-release',
 '{"public":true,"published":true,"build":20,"roles":["retailer"],"internalNote":"비밀"}',
 array['81111111-1111-4111-8111-111111111111']::uuid[]);
set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-4111-8111-111111111111',true);
select is((select count(*) from public.saip_records where collection='appReleases'),0::bigint,
 'reader가 포함되어도 공지 원본에 직접 접근 불가');
select ok(public.saip_snapshot()->'appReleases' ? 'visible-release','스냅샷으로 허용한 공지 표시');
select ok(not(public.saip_snapshot()->'appReleases'->'visible-release' ? 'internalNote'),'스냅샷 내부 메모 제외');
reset role;
select ok(not has_function_privilege('authenticated','saip_private.project_app_release(jsonb,uuid)','execute'),
 '다른 사용자로 투영 함수를 직접 호출할 수 없음');
select * from finish();
rollback;
