begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values
 ('11111111-1111-4111-8111-111111111111','retailer@example.test','{"name":"소매 상점"}','{"provider":"google"}'),
 ('22222222-2222-4222-8222-222222222222','uncle@example.test','{"name":"사입 삼촌"}','{"provider":"kakao"}');

select saip_private.put(
  'accounts',
  '11111111-1111-4111-8111-111111111111',
  jsonb_build_object(
    'name','소매 상점',
    'nickname','소매',
    'role','retailer',
    'complete',true,
    'version',0
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid]
);
select saip_private.put(
  'accounts',
  '22222222-2222-4222-8222-222222222222',
  jsonb_build_object(
    'name','사입 삼촌',
    'nickname','삼촌',
    'role','uncle',
    'complete',true,
    'version',0
  ),
  array['22222222-2222-4222-8222-222222222222'::uuid]
);

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);

select is(
  public.saip_command(
    'wf.convenience.upsertFavoriteWholesaler',
    jsonb_build_object(
      'favoriteId','favorite-a',
      'wholesaler','남평화 1층',
      'location','A열',
      'paymentMode','direct_paid'
    ),
    'conv-favorite-upsert'
  ),
  'favorite-a',
  '즐겨찾기 저장'
);
select is(
  public.saip_command(
    'wf.upsertFavoriteWholesaler',
    jsonb_build_object(
      'wholesaler','남평화 1층',
      'location','A열',
      'paymentMode','needs_check'
    ),
    'conv-favorite-upsert-merge'
  ),
  'favorite-a',
  '같은 도매처는 기존 즐겨찾기를 재사용'
);
select is(
  (select data->>'paymentMode' from public.saip_records where collection='favoriteWholesalers' and id='favorite-a'),
  'review',
  'legacy 결제 모드를 canonical review 로 저장'
);
select is(
  (select data->>'ownerId' from public.saip_records where collection='favoriteWholesalers' and id='favorite-a'),
  '11111111-1111-4111-8111-111111111111',
  '즐겨찾기 owner 저장'
);

select ok(
  length(public.saip_command('wf.convenience.upsertFavoriteWholesaler',
    '{"wholesaler":"새 도매처","location":"2층"}'::jsonb,'conv-auto-id')) > 0,
  '새 즐겨찾기는 지정한 ID 없이도 서버가 ID를 만들어 저장한다'
);

reset role;

select saip_private.put(
  'appReleases',
  'release-retailer',
  jsonb_build_object(
    'public',true,
    'published',true,
    'publishedAt','2026-10-14T12:00:00Z',
    'roles',jsonb_build_array('retailer'),
    'title','소매 공개 공지',
    'platforms',jsonb_build_object(
      'android',
      jsonb_build_object(
        'versionName','1.1.0',
        'buildNumber',11,
        'storeUrl','https://play.google.com/store/apps/details?id=com.agent.uncle'
      )
    )
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid]
);
select saip_private.put(
  'appReleases',
  'release-uncle',
  jsonb_build_object(
    'public',true,
    'published',true,
    'publishedAt','2026-10-14T12:00:00Z',
    'roles',jsonb_build_array('uncle'),
    'title','삼촌 전용 공지',
    'platform','android',
    'versionName','1.1.0',
    'buildNumber',11,
    'storeUrl','https://play.google.com/store/apps/details?id=com.agent.uncle'
  ),
  array['22222222-2222-4222-8222-222222222222'::uuid]
);
select saip_private.put(
  'appReleases',
  'release-private',
  jsonb_build_object(
    'public',false,
    'published',true,
    'publishedAt','2026-10-14T12:00:00Z',
    'roles',jsonb_build_array('retailer'),
    'title','비공개 공지',
    'platform','android',
    'versionName','1.1.0',
    'buildNumber',11,
    'storeUrl','https://play.google.com/store/apps/details?id=com.agent.uncle'
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid]
);
select saip_private.put(
  'appReleases',
  'release-invalid-platform',
  jsonb_build_object(
    'public',true,
    'published',true,
    'publishedAt','2026-10-14T12:00:00Z',
    'roles',jsonb_build_array('retailer'),
    'title','잘못된 플랫폼',
    'platform','windows',
    'versionName','1.1.0',
    'buildNumber',11
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid]
);

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select ok(public.saip_snapshot()->'appReleases' ? 'release-retailer','eligible 공개 릴리스 노출');
select ok(not (public.saip_snapshot()->'appReleases' ? 'release-uncle'),'역할 불일치 릴리스 숨김');
select ok(not (public.saip_snapshot()->'appReleases' ? 'release-private'),'비공개 릴리스 숨김');
select ok(not (public.saip_snapshot()->'appReleases' ? 'release-invalid-platform'),'잘못된 플랫폼 릴리스 숨김');
select ok(not (public.saip_snapshot()->'appReleases'->'release-retailer' ? 'roles'),'roles 누출 금지');
select ok(not (public.saip_snapshot()->'appReleases'->'release-retailer' ? 'userIds'),'userIds 누출 금지');

select throws_ok(
  $$select public.saip_command('wf.publishAppRelease', '{}'::jsonb, 'conv-release-forbidden')$$,
  'P0001',
  '지원하지 않는 편의 기능 명령이에요: publishAppRelease',
  '클라이언트 release 게시 명령 금지'
);

select is(
  public.saip_command(
    'wf.convenience.deleteFavoriteWholesaler',
    jsonb_build_object('favoriteId','favorite-a'),
    'conv-favorite-delete'
  ),
  'favorite-a',
  '즐겨찾기 삭제'
);
select is(
  (select count(*)::text from public.saip_records where collection='favoriteWholesalers' and id='favorite-a'),
  '0',
  '삭제 후 레코드 제거'
);

reset role;
select * from finish();
rollback;
