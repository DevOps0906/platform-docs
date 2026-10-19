-- =====================================================================
-- 0002_stay_domain.sql (모놀리스, public 스키마)
-- airbnb(Stay, 가칭) 도메인: 숙소 등록·검색·예약·리뷰·찜. 선행: 0001_core_lite.sql
-- 기획: docs/products/airbnb/05_DATA_MODEL.md
-- 모듈러 조각(_supabase-modular/migrations/2700_stay.sql)은 아직 없다. 이 파일을 정본으로 두고
-- SY-06-002 가 모듈러 조각으로 역변환한다(05장 8절). 그 뒤에는 조각이 정본, 이 파일은 변환본이 된다.
--
-- 설계 요점
--   1) 게스트와 호스트는 모두 Supabase 사용자다. 가입하면 개인 조직이 생기고(코어 handle_new_user),
--      숙소는 호스트의 조직(org_id)에 속한다. 게스트 식별은 auth.uid()뿐이며 요청 body의 사용자 id를 받지 않는다
--      (리뷰 #2, #3: 원본은 body 의 hostId/userId 를 그대로 썼다).
--   2) 정확한 주소·좌표·체크인 안내는 listing_private 에 분리한다. 호스트 조직과 확정 예약 게스트만 읽는다.
--      공개 화면은 listings 의 대략 좌표(소수 2자리, 약 1km)만 쓴다.
--   3) 비로그인 검색·상세는 테이블 권한이 아니라 SECURITY DEFINER 공개 RPC(11절)로만 읽는다. anon 은 테이블 권한 0.
--   4) 이중 예약은 DB 배타 제약(btree_gist)으로 막는다: 같은 숙소에서 requested/confirmed 예약의 기간이 겹칠 수 없다
--      (리뷰 #11). 예약 쓰기는 전부 RPC(13절)이고 테이블 INSERT/UPDATE 권한은 없다(리뷰 #6).
--   5) 리뷰는 완료(completed)된 예약 1건당 1개, 체크아웃 후 14일 안에만(리뷰 #12). 평균 별점은 트리거가 listings 에 유지한다.
--   6) 결제는 MVP 범위 밖이다(01_PRD 2장). 예약 행의 금액은 표시용 스냅샷이며 Phase 2 Toss 결제가 이 행을 참조한다.
-- 반복 실행 가능.
-- =====================================================================

create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------------
-- 0. 순수 함수
-- ---------------------------------------------------------------------
-- 사용자 입력 정리: 제어문자를 공백으로, 앞뒤 공백 제거. HTML은 저장 그대로 두고 렌더에서 텍스트로만 출력한다.
create or replace function public.stay_clean_text(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select btrim(regexp_replace(coalesce(p_text, ''), '[[:cntrl:]]+', ' ', 'g'));
$$;

-- 서울 기준 오늘 날짜. 체크인·체크아웃·리뷰 기한 판정에 쓴다.
create or replace function public.stay_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Seoul')::date;
$$;

-- ---------------------------------------------------------------------
-- 1. listings: 숙소(공개 정보). 상태 draft/published/unlisted/suspended
-- ---------------------------------------------------------------------
create table if not exists public.listings (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations(id) on delete cascade,
  status              text not null default 'draft'
                      constraint listings_status_check check (status in ('draft', 'published', 'unlisted', 'suspended')),
  register_step       smallint not null default 1 constraint listings_register_step_check check (register_step between 1 and 13),
  large_building_type text constraint listings_large_building_type_check check (char_length(large_building_type) <= 40),
  building_type       text constraint listings_building_type_check check (char_length(building_type) <= 40),
  room_type           text not null default 'entire'
                      constraint listings_room_type_check check (room_type in ('entire', 'private', 'shared')),
  is_set_up_for_guest boolean not null default false,
  max_guests          smallint not null default 1 constraint listings_max_guests_check check (max_guests between 1 and 16),
  bedroom_count       smallint not null default 1 constraint listings_bedroom_count_check check (bedroom_count between 0 and 50),
  bed_count           smallint not null default 1 constraint listings_bed_count_check check (bed_count between 0 and 100),
  bed_list            jsonb not null default '[]'::jsonb
                      constraint listings_bed_list_check check (jsonb_typeof(bed_list) = 'array' and pg_column_size(bed_list) <= 8192),
  public_bed_list     jsonb not null default '[]'::jsonb
                      constraint listings_public_bed_list_check check (jsonb_typeof(public_bed_list) = 'array' and pg_column_size(public_bed_list) <= 4096),
  bathroom_count      numeric(3,1) not null default 1 constraint listings_bathroom_count_check check (bathroom_count between 0 and 50),
  bathroom_type       text not null default 'private'
                      constraint listings_bathroom_type_check check (bathroom_type in ('private', 'shared')),
  country             text not null default 'KR' constraint listings_country_check check (country ~ '^[A-Z]{2}$'),
  city                text not null default '' constraint listings_city_check check (char_length(city) <= 60),
  district            text not null default '' constraint listings_district_check check (char_length(district) <= 60),
  public_lat          numeric(5,2) constraint listings_public_lat_check check (public_lat between -90 and 90),
  public_lng          numeric(5,2) constraint listings_public_lng_check check (public_lng between -180 and 180),
  amenities           text[] not null default '{}' constraint listings_amenities_check check (cardinality(amenities) <= 60),
  conveniences        text[] not null default '{}' constraint listings_conveniences_check check (cardinality(conveniences) <= 30),
  title               text not null default '' constraint listings_title_check check (char_length(title) <= 50),
  description         text not null default '' constraint listings_description_check check (char_length(description) <= 5000),
  house_rules         text not null default '' constraint listings_house_rules_check check (char_length(house_rules) <= 2000),
  price_per_night     integer constraint listings_price_check check (price_per_night between 10000 and 10000000),
  cleaning_fee        integer not null default 0 constraint listings_cleaning_fee_check check (cleaning_fee between 0 and 1000000),
  min_nights          smallint not null default 1 constraint listings_min_nights_check check (min_nights between 1 and 30),
  max_nights          smallint not null default 30 constraint listings_max_nights_check check (max_nights between 1 and 90),
  check_in_time       time not null default '15:00',
  check_out_time      time not null default '11:00',
  instant_book        boolean not null default false,
  available_from      date,
  available_to        date,
  cover_photo_path    text,
  rating_avg          numeric(2,1),
  review_count        integer not null default 0,
  published_at        timestamptz,
  suspended_reason    text,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint listings_nights_range_check check (min_nights <= max_nights),
  constraint listings_available_range_check check (available_from is null or available_to is null or available_from < available_to),
  constraint listings_id_org_uniq unique (id, org_id)
);
comment on column public.listings.public_lat is '공개용 대략 좌표(소수 2자리). 정확한 좌표는 listing_private.lat/lng 이고 트리거가 반올림해 채운다';
comment on column public.listings.register_step is '등록 마법사 마지막 저장 단계(원본 13단계, pages/room/register/*)';
comment on column public.listings.rating_avg is '보이는 리뷰의 평균(트리거 유지). 리뷰 0건이면 null';

create index if not exists listings_org_idx on public.listings (org_id, created_at desc);
create index if not exists listings_search_geo_idx on public.listings (public_lat, public_lng) where status = 'published' and deleted_at is null;
create index if not exists listings_search_city_idx on public.listings (city, price_per_night) where status = 'published' and deleted_at is null;

-- ---------------------------------------------------------------------
-- 2. listing_private: 정확한 주소·좌표·체크인 안내. 호스트 조직 + 확정 예약 게스트만
-- ---------------------------------------------------------------------
create table if not exists public.listing_private (
  listing_id      uuid primary key,
  org_id          uuid not null references public.organizations(id) on delete cascade,
  street_address  text not null default '' constraint listing_private_street_check check (char_length(street_address) <= 200),
  detail_address  text not null default '' constraint listing_private_detail_check check (char_length(detail_address) <= 200),
  postcode        text not null default '' constraint listing_private_postcode_check check (char_length(postcode) <= 10),
  lat             numeric(9,6) constraint listing_private_lat_check check (lat between -90 and 90),
  lng             numeric(9,6) constraint listing_private_lng_check check (lng between -180 and 180),
  checkin_guide   text not null default '' constraint listing_private_guide_check check (char_length(checkin_guide) <= 3000),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint listing_private_listing_fk foreign key (listing_id, org_id) references public.listings (id, org_id) on delete cascade
);
comment on table public.listing_private is '리뷰 #6 대응: 공개 RPC 와 게스트에게 정확한 주소를 주지 않기 위해 분리';

-- ---------------------------------------------------------------------
-- 3. listing_photos: 사진. Storage public-assets 버킷의 <org_id>/listings/<listing_id>/ 경로만
-- ---------------------------------------------------------------------
create table if not exists public.listing_photos (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations(id) on delete cascade,
  listing_id   uuid not null,
  storage_path text not null constraint listing_photos_path_check check (char_length(storage_path) <= 300),
  position     smallint not null default 0 constraint listing_photos_position_check check (position between 0 and 99),
  width        integer constraint listing_photos_width_check check (width between 1 and 20000),
  height       integer constraint listing_photos_height_check check (height between 1 and 20000),
  caption      text not null default '' constraint listing_photos_caption_check check (char_length(caption) <= 200),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint listing_photos_listing_fk foreign key (listing_id, org_id) references public.listings (id, org_id) on delete cascade,
  constraint listing_photos_path_prefix_check check (storage_path like (org_id::text || '/listings/' || listing_id::text || '/%')),
  constraint listing_photos_path_uniq unique (storage_path)
);
create index if not exists listing_photos_listing_idx on public.listing_photos (listing_id, position);

-- ---------------------------------------------------------------------
-- 4. availability_blocks: 호스트가 막은 날짜(개인 사용, 수리 등). 예약과 같은 반열림 구간 [start, end)
-- ---------------------------------------------------------------------
create table if not exists public.availability_blocks (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  listing_id  uuid not null,
  start_date  date not null,
  end_date    date not null,
  period      daterange generated always as (daterange(start_date, end_date, '[)')) stored,
  note        text not null default '' constraint availability_blocks_note_check check (char_length(note) <= 200),
  created_by  uuid,
  created_at  timestamptz not null default now(),
  constraint availability_blocks_listing_fk foreign key (listing_id, org_id) references public.listings (id, org_id) on delete cascade,
  constraint availability_blocks_range_check check (start_date < end_date and end_date - start_date <= 365),
  constraint availability_blocks_no_overlap exclude using gist (listing_id with =, period with &&)
);

-- ---------------------------------------------------------------------
-- 5. reservations: 예약. 게스트 = auth.uid(). 겹침은 배타 제약으로 차단
--    상태: requested → confirmed / declined / expired / canceled_by_guest
--          confirmed → completed / canceled_by_guest / canceled_by_host
-- ---------------------------------------------------------------------
create table if not exists public.reservations (
  id                uuid primary key default gen_random_uuid(),
  org_id            uuid not null references public.organizations(id) on delete cascade,
  listing_id        uuid not null,
  guest_user_id     uuid not null references auth.users(id) on delete restrict,
  check_in          date not null,
  check_out         date not null,
  stay              daterange generated always as (daterange(check_in, check_out, '[)')) stored,
  nights            smallint generated always as ((check_out - check_in)::smallint) stored,
  adult_count       smallint not null default 1 constraint reservations_adult_check check (adult_count between 1 and 16),
  children_count    smallint not null default 0 constraint reservations_children_check check (children_count between 0 and 15),
  infant_count      smallint not null default 0 constraint reservations_infant_check check (infant_count between 0 and 5),
  status            text not null default 'requested'
                    constraint reservations_status_check check (status in
                      ('requested', 'confirmed', 'declined', 'expired', 'canceled_by_guest', 'canceled_by_host', 'completed')),
  nightly_price     integer not null constraint reservations_nightly_price_check check (nightly_price > 0),
  cleaning_fee      integer not null default 0 constraint reservations_cleaning_fee_check check (cleaning_fee >= 0),
  service_fee       integer not null default 0 constraint reservations_service_fee_check check (service_fee >= 0),
  total_price       integer not null constraint reservations_total_check check (total_price > 0),
  guest_message     text not null default '' constraint reservations_message_check check (char_length(guest_message) <= 1000),
  cancel_reason     text constraint reservations_cancel_reason_check check (char_length(cancel_reason) <= 500),
  expires_at        timestamptz,
  responded_at      timestamptz,
  canceled_at       timestamptz,
  completed_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint reservations_listing_fk foreign key (listing_id, org_id) references public.listings (id, org_id) on delete restrict,
  constraint reservations_dates_check check (check_in < check_out and check_out - check_in <= 90),
  constraint reservations_no_overlap exclude using gist (listing_id with =, stay with &&)
    where (status in ('requested', 'confirmed'))
);
comment on column public.reservations.org_id is '호스트 조직(숙소 소유). 게스트는 guest_user_id';
comment on column public.reservations.total_price is 'nightly_price * nights + cleaning_fee + service_fee 스냅샷(원). MVP 결제 없음';
create index if not exists reservations_guest_idx on public.reservations (guest_user_id, check_in desc);
create index if not exists reservations_org_status_idx on public.reservations (org_id, status, check_in);
create index if not exists reservations_listing_idx on public.reservations (listing_id, check_in);
create index if not exists reservations_expiry_idx on public.reservations (expires_at) where status = 'requested';

-- ---------------------------------------------------------------------
-- 6. reviews: 완료된 예약 1건당 리뷰 1개. 호스트 답글 1회
-- ---------------------------------------------------------------------
create table if not exists public.reviews (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  listing_id      uuid not null,
  reservation_id  uuid not null references public.reservations(id) on delete cascade,
  guest_user_id   uuid not null references auth.users(id) on delete cascade,
  rating          smallint not null constraint reviews_rating_check check (rating between 1 and 5),
  content         text not null constraint reviews_content_check check (char_length(content) between 10 and 1000),
  status          text not null default 'visible' constraint reviews_status_check check (status in ('visible', 'hidden')),
  host_reply      text constraint reviews_host_reply_check check (char_length(host_reply) between 1 and 500),
  host_replied_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint reviews_listing_fk foreign key (listing_id, org_id) references public.listings (id, org_id) on delete cascade,
  constraint reviews_reservation_uniq unique (reservation_id)
);
create index if not exists reviews_listing_idx on public.reviews (listing_id, created_at desc) where status = 'visible';

-- ---------------------------------------------------------------------
-- 7. wishlists: 찜. 사용자 본인 행만
-- ---------------------------------------------------------------------
create table if not exists public.wishlists (
  user_id    uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

-- ---------------------------------------------------------------------
-- 8. 트리거: updated_at, 공개 좌표 동기화, 평균 별점 유지
-- ---------------------------------------------------------------------
drop trigger if exists listings_set_updated_at on public.listings;
create trigger listings_set_updated_at before update on public.listings
  for each row execute function public.set_updated_at();
drop trigger if exists listing_private_set_updated_at on public.listing_private;
create trigger listing_private_set_updated_at before update on public.listing_private
  for each row execute function public.set_updated_at();
drop trigger if exists listing_photos_set_updated_at on public.listing_photos;
create trigger listing_photos_set_updated_at before update on public.listing_photos
  for each row execute function public.set_updated_at();
drop trigger if exists reservations_set_updated_at on public.reservations;
create trigger reservations_set_updated_at before update on public.reservations
  for each row execute function public.set_updated_at();
drop trigger if exists reviews_set_updated_at on public.reviews;
create trigger reviews_set_updated_at before update on public.reviews
  for each row execute function public.set_updated_at();

-- 정확한 좌표가 바뀌면 공개 좌표(소수 2자리)를 listings 에 채운다
create or replace function public.listing_private_sync_public_geo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.listings
     set public_lat = round(new.lat, 2), public_lng = round(new.lng, 2)
   where id = new.listing_id
     and (public_lat is distinct from round(new.lat, 2) or public_lng is distinct from round(new.lng, 2));
  return new;
end;
$$;
drop trigger if exists listing_private_sync_geo on public.listing_private;
create trigger listing_private_sync_geo after insert or update of lat, lng on public.listing_private
  for each row execute function public.listing_private_sync_public_geo();

-- 리뷰가 생기거나 숨김 상태가 바뀌면 평균과 건수를 다시 계산한다(리뷰 #14: 상세마다 전체 리뷰를 읽지 않는다)
create or replace function public.reviews_refresh_listing_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_listing uuid := coalesce(new.listing_id, old.listing_id);
begin
  update public.listings l
     set rating_avg = s.avg_rating, review_count = s.cnt
    from (select round(avg(r.rating)::numeric, 1) as avg_rating, count(*)::integer as cnt
            from public.reviews r where r.listing_id = v_listing and r.status = 'visible') s
   where l.id = v_listing;
  return null;
end;
$$;
drop trigger if exists reviews_refresh_rating on public.reviews;
create trigger reviews_refresh_rating after insert or delete or update of status on public.reviews
  for each row execute function public.reviews_refresh_listing_rating();

-- ---------------------------------------------------------------------
-- 9. RLS와 GRANT
--   호스트(authenticated): 자기 조직 + 'stay' 엔타이틀먼트일 때 자기 숙소를 읽고 비상태 컬럼을 고친다.
--   게스트(authenticated): 자기 예약·리뷰·찜만 읽는다. 쓰기는 RPC.
--   anon: 테이블 권한 없음. 공개 RPC(11절)만.
-- ---------------------------------------------------------------------
alter table public.listings            enable row level security;
alter table public.listing_private     enable row level security;
alter table public.listing_photos      enable row level security;
alter table public.availability_blocks enable row level security;
alter table public.reservations        enable row level security;
alter table public.reviews             enable row level security;
alter table public.wishlists           enable row level security;

revoke all on table public.listings, public.listing_private, public.listing_photos, public.availability_blocks,
                    public.reservations, public.reviews, public.wishlists
  from public, anon, authenticated;
grant all on table public.listings, public.listing_private, public.listing_photos, public.availability_blocks,
                   public.reservations, public.reviews, public.wishlists
  to service_role;

-- listings: 호스트 조직만 테이블로 읽는다. 상태·별점·조직은 RPC/트리거만 바꾼다(컬럼 GRANT)
grant select on public.listings to authenticated;
grant update (register_step, large_building_type, building_type, room_type, is_set_up_for_guest, max_guests,
              bedroom_count, bed_count, bed_list, public_bed_list, bathroom_count, bathroom_type, country, city,
              district, amenities, conveniences, title, description, house_rules, price_per_night, cleaning_fee,
              min_nights, max_nights, check_in_time, check_out_time, instant_book, available_from, available_to,
              cover_photo_path)
  on public.listings to authenticated;
drop policy if exists listings_select on public.listings;
create policy listings_select on public.listings for select to authenticated
  using (public.is_org_member(org_id) and public.has_entitlement(org_id, 'stay') and deleted_at is null);
drop policy if exists listings_update on public.listings;
create policy listings_update on public.listings for update to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'stay')
         and deleted_at is null and status <> 'suspended')
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'stay')
              and status <> 'suspended');

-- listing_private: 호스트 조직 또는 확정·완료 예약의 게스트
grant select on public.listing_private to authenticated;
grant update (street_address, detail_address, postcode, lat, lng, checkin_guide) on public.listing_private to authenticated;
drop policy if exists listing_private_select on public.listing_private;
create policy listing_private_select on public.listing_private for select to authenticated
  using (public.is_org_member(org_id)
         or exists (select 1 from public.reservations r
                     where r.listing_id = listing_private.listing_id and r.guest_user_id = auth.uid()
                       and r.status in ('confirmed', 'completed')));
drop policy if exists listing_private_update on public.listing_private;
create policy listing_private_update on public.listing_private for update to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'stay'))
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']));

-- listing_photos: 호스트가 직접 추가·정렬·삭제(숙소당 30장 상한). 공개 조회는 RPC
grant select, delete on public.listing_photos to authenticated;
grant insert (org_id, listing_id, storage_path, position, width, height, caption) on public.listing_photos to authenticated;
grant update (position, caption) on public.listing_photos to authenticated;
drop policy if exists listing_photos_select on public.listing_photos;
create policy listing_photos_select on public.listing_photos for select to authenticated
  using (public.is_org_member(org_id));
drop policy if exists listing_photos_insert on public.listing_photos;
create policy listing_photos_insert on public.listing_photos for insert to authenticated
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']) and public.has_entitlement(org_id, 'stay')
              and exists (select 1 from public.listings l
                           where l.id = listing_photos.listing_id and l.org_id = listing_photos.org_id
                             and l.deleted_at is null and l.status <> 'suspended')
              and (select count(*) from public.listing_photos p where p.listing_id = listing_photos.listing_id) < 30);
drop policy if exists listing_photos_update on public.listing_photos;
create policy listing_photos_update on public.listing_photos for update to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']))
  with check (public.has_org_role(org_id, array['owner', 'admin', 'member']));
drop policy if exists listing_photos_delete on public.listing_photos;
create policy listing_photos_delete on public.listing_photos for delete to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'member']));

-- availability_blocks: 호스트 조직만 읽기. 쓰기는 block_dates/unblock_dates RPC
grant select on public.availability_blocks to authenticated;
drop policy if exists availability_blocks_select on public.availability_blocks;
create policy availability_blocks_select on public.availability_blocks for select to authenticated
  using (public.is_org_member(org_id));

-- reservations: 게스트 본인 또는 호스트 조직. 쓰기 권한 없음(RPC만)
grant select on public.reservations to authenticated;
drop policy if exists reservations_select on public.reservations;
create policy reservations_select on public.reservations for select to authenticated
  using (guest_user_id = auth.uid() or public.is_org_member(org_id));

-- reviews: 작성자 본인 또는 호스트 조직. 공개 목록은 RPC. 쓰기는 RPC
grant select on public.reviews to authenticated;
drop policy if exists reviews_select on public.reviews;
create policy reviews_select on public.reviews for select to authenticated
  using (guest_user_id = auth.uid() or public.is_org_member(org_id));

-- wishlists: 본인 행 읽기·삭제. 추가는 toggle_wishlist(공개 숙소 확인 필요)
grant select, delete on public.wishlists to authenticated;
drop policy if exists wishlists_select on public.wishlists;
create policy wishlists_select on public.wishlists for select to authenticated
  using (user_id = auth.uid());
drop policy if exists wishlists_delete on public.wishlists;
create policy wishlists_delete on public.wishlists for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- 10. 내부 헬퍼 (SECURITY DEFINER, EXECUTE 없음: 같은 소유자의 DEFINER 함수 안에서만 호출)
-- ---------------------------------------------------------------------
-- 플랜 features 정수 값(없으면 기본값). 엔타이틀먼트가 없으면 기본값
create or replace function public.stay_plan_feature_int(p_org_id uuid, p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select (p.features ->> p_key)::integer
      from public.app_entitlements e
      join public.plans p on p.id = e.plan_id
     where e.org_id = p_org_id and e.app_id = 'stay' and e.status = 'active'
       and (e.expires_at is null or e.expires_at > now())
     limit 1), p_default);
$$;

-- 호출자가 활성 사용자인지(정지 계정 차단)
create or replace function public.stay_require_active_user()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'stay: login required' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles p where p.id = v_uid and p.status = 'suspended') then
    raise exception 'stay: suspended user' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

-- 레이트 리밋(초과 시 SY429)
create or replace function public.stay_rate_limit(p_key text, p_limit integer, p_window_seconds integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_rl record;
begin
  select * into v_rl from public.rate_limit_hit('stay:' || p_key, p_limit, p_window_seconds);
  if not v_rl.allowed then
    raise exception 'stay: rate limited %', p_key using errcode = 'SY429';
  end if;
end;
$$;

-- 공개 카드 한 장(검색·찜·여행 목록이 같은 모양을 쓴다)
create or replace function public.stay_listing_card(p_listing public.listings)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_listing.id, 'title', p_listing.title, 'room_type', p_listing.room_type,
    'building_type', p_listing.building_type, 'city', p_listing.city, 'district', p_listing.district,
    'public_lat', p_listing.public_lat, 'public_lng', p_listing.public_lng,
    'price_per_night', p_listing.price_per_night, 'rating_avg', p_listing.rating_avg,
    'review_count', p_listing.review_count, 'max_guests', p_listing.max_guests,
    'bedroom_count', p_listing.bedroom_count, 'bed_count', p_listing.bed_count,
    'bathroom_count', p_listing.bathroom_count,
    'cover_photo_path', coalesce(p_listing.cover_photo_path,
      (select ph.storage_path from public.listing_photos ph where ph.listing_id = p_listing.id order by ph.position, ph.created_at limit 1)),
    'host_display_name', (select pr.display_name from public.organizations o join public.profiles pr on pr.id = o.owner_id
                           where o.id = p_listing.org_id));
$$;

-- 기간이 비어 있는가(예약 requested/confirmed, 호스트 차단 날짜 모두 제외)
create or replace function public.stay_range_is_free(p_listing_id uuid, p_check_in date, p_check_out date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.reservations r
                      where r.listing_id = p_listing_id and r.status in ('requested', 'confirmed')
                        and r.stay && daterange(p_check_in, p_check_out, '[)'))
     and not exists (select 1 from public.availability_blocks b
                      where b.listing_id = p_listing_id and b.period && daterange(p_check_in, p_check_out, '[)'));
$$;

-- ---------------------------------------------------------------------
-- 11. 공개 RPC (anon, authenticated). 정확한 주소·게스트 정보는 돌려주지 않는다
-- ---------------------------------------------------------------------
-- 검색: 지도 경계(남서·북동) 또는 도시, 날짜, 인원, 가격, 유형. 리뷰 #13(비대칭 범위), #14(N+1) 대응
create or replace function public.search_listings(
  p_sw_lat numeric default null, p_sw_lng numeric default null,
  p_ne_lat numeric default null, p_ne_lng numeric default null,
  p_city text default null,
  p_check_in date default null, p_check_out date default null,
  p_guests integer default 1,
  p_min_price integer default null, p_max_price integer default null,
  p_room_type text default null,
  p_limit integer default 20, p_offset integer default 0
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (p_check_in is null) <> (p_check_out is null) then
    raise exception 'search_listings: both dates required' using errcode = 'SY002';
  end if;
  if p_check_in is not null and (p_check_in >= p_check_out or p_check_in < public.stay_today()) then
    raise exception 'search_listings: invalid dates' using errcode = 'SY002';
  end if;
  return query
  select public.stay_listing_card(l)
    from public.listings l
   where l.status = 'published' and l.deleted_at is null
     and (p_sw_lat is null or (l.public_lat between p_sw_lat and p_ne_lat and l.public_lng between p_sw_lng and p_ne_lng))
     and (p_city is null or l.city = p_city)
     and l.max_guests >= greatest(coalesce(p_guests, 1), 1)
     and (p_min_price is null or l.price_per_night >= p_min_price)
     and (p_max_price is null or l.price_per_night <= p_max_price)
     and (p_room_type is null or l.room_type = p_room_type)
     and (p_check_in is null or (
           (p_check_out - p_check_in) between l.min_nights and l.max_nights
           and (l.available_from is null or p_check_in >= l.available_from)
           and (l.available_to is null or p_check_out <= l.available_to)
           and public.stay_range_is_free(l.id, p_check_in, p_check_out)))
   order by l.rating_avg desc nulls last, l.published_at desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- 상세: 공개 정보 + 사진 + 호스트 표시 정보. 호스트 조직 멤버는 draft 도 미리 볼 수 있다
create or replace function public.get_listing_public(p_listing_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_l public.listings;
begin
  select * into v_l from public.listings where id = p_listing_id and deleted_at is null;
  if not found or (v_l.status <> 'published' and not public.is_org_member(v_l.org_id)) then
    raise exception 'get_listing_public: not found' using errcode = 'SY001';
  end if;
  return public.stay_listing_card(v_l) || jsonb_build_object(
    'status', v_l.status, 'large_building_type', v_l.large_building_type, 'is_set_up_for_guest', v_l.is_set_up_for_guest,
    'bed_list', v_l.bed_list, 'public_bed_list', v_l.public_bed_list, 'bathroom_type', v_l.bathroom_type,
    'amenities', v_l.amenities, 'conveniences', v_l.conveniences, 'description', v_l.description,
    'house_rules', v_l.house_rules, 'cleaning_fee', v_l.cleaning_fee, 'min_nights', v_l.min_nights,
    'max_nights', v_l.max_nights, 'check_in_time', v_l.check_in_time, 'check_out_time', v_l.check_out_time,
    'instant_book', v_l.instant_book, 'available_from', v_l.available_from, 'available_to', v_l.available_to,
    'photos', coalesce((select jsonb_agg(jsonb_build_object('path', ph.storage_path, 'caption', ph.caption,
                                                            'width', ph.width, 'height', ph.height)
                                         order by ph.position, ph.created_at)
                          from public.listing_photos ph where ph.listing_id = v_l.id), '[]'::jsonb),
    'host', (select jsonb_build_object('display_name', pr.display_name, 'avatar_url', pr.avatar_url,
                                       'joined_at', pr.created_at)
               from public.organizations o join public.profiles pr on pr.id = o.owner_id where o.id = v_l.org_id));
end;
$$;

-- 예약 불가 구간(게스트 정보 없음). 달력 비활성 표시용
create or replace function public.listing_unavailable_ranges(p_listing_id uuid, p_from date, p_to date)
returns table (start_date date, end_date date)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_to <= p_from or p_to - p_from > 400 then
    raise exception 'listing_unavailable_ranges: invalid range' using errcode = 'SY002';
  end if;
  if not exists (select 1 from public.listings l where l.id = p_listing_id and l.status = 'published' and l.deleted_at is null) then
    raise exception 'listing_unavailable_ranges: not found' using errcode = 'SY001';
  end if;
  return query
    select lower(r.stay), upper(r.stay) from public.reservations r
     where r.listing_id = p_listing_id and r.status in ('requested', 'confirmed')
       and r.stay && daterange(p_from, p_to, '[)')
    union all
    select b.start_date, b.end_date from public.availability_blocks b
     where b.listing_id = p_listing_id and b.period && daterange(p_from, p_to, '[)')
    order by 1;
end;
$$;

-- 공개 리뷰 목록(작성자는 표시 이름 첫 글자 + 가입 연도만)
create or replace function public.listing_reviews_public(p_listing_id uuid, p_limit integer default 10, p_offset integer default 0)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'id', r.id, 'rating', r.rating, 'content', r.content, 'created_at', r.created_at,
           'host_reply', r.host_reply, 'host_replied_at', r.host_replied_at,
           'reviewer_name', left(coalesce(nullif(pr.display_name, ''), '게스트'), 1) || '**',
           'reviewer_since', extract(year from pr.created_at)::integer)
    from public.reviews r
    join public.listings l on l.id = r.listing_id and l.status = 'published' and l.deleted_at is null
    left join public.profiles pr on pr.id = r.guest_user_id
   where r.listing_id = p_listing_id and r.status = 'visible'
   order by r.created_at desc
   limit least(greatest(coalesce(p_limit, 10), 1), 50) offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ---------------------------------------------------------------------
-- 12. 호스트 RPC (authenticated, SECURITY DEFINER)
--     호출자 판정: public.is_service_caller() + public.has_org_role(...)
-- ---------------------------------------------------------------------
-- 새 숙소 초안(+비공개 행). 플랜 max_listings, 시간당 20건
create or replace function public.create_listing(p_org_id uuid default null)
returns public.listings
language plpgsql
security definer
set search_path = ''
as $$
declare v_org uuid; v_row public.listings; v_limit integer; v_count integer;
begin
  perform public.stay_require_active_user();
  v_org := coalesce(p_org_id, public.personal_org_id());
  if v_org is null or not public.has_org_role(v_org, array['owner', 'admin', 'member']) then
    raise exception 'create_listing: not a member' using errcode = '42501';
  end if;
  if not public.has_entitlement(v_org, 'stay') then
    raise exception 'create_listing: no entitlement' using errcode = '42501';
  end if;
  perform public.stay_rate_limit('create_listing:' || v_org::text, 20, 3600);
  v_limit := public.stay_plan_feature_int(v_org, 'max_listings', 3);
  select count(*) into v_count from public.listings l where l.org_id = v_org and l.deleted_at is null;
  if v_limit >= 0 and v_count >= v_limit then
    raise exception 'create_listing: plan limit % listings', v_limit using errcode = 'SY012';
  end if;
  insert into public.listings (org_id, created_by) values (v_org, auth.uid()) returning * into v_row;
  insert into public.listing_private (listing_id, org_id) values (v_row.id, v_org);
  perform public.write_audit(v_org, 'listing.create', 'stay_listing', v_row.id::text);
  return v_row;
end;
$$;

-- 상태 전이: draft→published, published→unlisted, unlisted→published (게시 조건 검사)
create or replace function public.transition_listing(p_listing_id uuid, p_to text)
returns public.listings
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.listings; v_priv public.listing_private; v_photos integer; v_missing text[] := '{}';
begin
  select * into v_row from public.listings where id = p_listing_id and deleted_at is null for update;
  if not found then
    raise exception 'transition_listing: not found' using errcode = 'SY001';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'transition_listing: not a member' using errcode = '42501';
  end if;
  if not ((v_row.status, p_to) in (('draft', 'published'), ('published', 'unlisted'), ('unlisted', 'published'))) then
    raise exception 'transition_listing: % -> % not allowed', v_row.status, p_to using errcode = 'SY007';
  end if;
  if p_to = 'published' then
    select * into v_priv from public.listing_private where listing_id = p_listing_id;
    select count(*) into v_photos from public.listing_photos where listing_id = p_listing_id;
    if char_length(v_row.title) < 5 then v_missing := array_append(v_missing, 'title'); end if;
    if char_length(v_row.description) < 20 then v_missing := array_append(v_missing, 'description'); end if;
    if v_row.price_per_night is null then v_missing := array_append(v_missing, 'price'); end if;
    if v_priv.lat is null or v_priv.lng is null or v_priv.street_address = '' then v_missing := array_append(v_missing, 'location'); end if;
    if v_photos < 5 then v_missing := array_append(v_missing, 'photos'); end if;
    if cardinality(v_missing) > 0 then
      raise exception 'transition_listing: incomplete %', array_to_string(v_missing, ',') using errcode = 'SY010';
    end if;
    update public.listings set status = 'published', published_at = coalesce(published_at, now())
     where id = p_listing_id returning * into v_row;
  else
    update public.listings set status = p_to where id = p_listing_id returning * into v_row;
  end if;
  perform public.write_audit(v_row.org_id, 'listing.' || p_to, 'stay_listing', p_listing_id::text);
  return v_row;
end;
$$;

-- 운영자 정지·해제(service_role 전용). suspended→unlisted 로 돌린다
create or replace function public.suspend_listing(p_listing_id uuid, p_suspend boolean, p_reason text default null)
returns public.listings
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.listings;
begin
  if not public.is_service_caller() then
    raise exception 'suspend_listing: service_role only' using errcode = '42501';
  end if;
  update public.listings
     set status = case when p_suspend then 'suspended' else 'unlisted' end,
         suspended_reason = case when p_suspend then public.stay_clean_text(p_reason) else null end
   where id = p_listing_id and deleted_at is null
     and ((p_suspend and status <> 'suspended') or (not p_suspend and status = 'suspended'))
  returning * into v_row;
  if not found then
    raise exception 'suspend_listing: not allowed' using errcode = 'SY007';
  end if;
  perform public.write_audit(v_row.org_id, case when p_suspend then 'listing.suspend' else 'listing.unsuspend' end,
                             'stay_listing', p_listing_id::text, null, null, jsonb_build_object('reason', p_reason));
  return v_row;
end;
$$;

-- 삭제(소프트). 앞으로 남은 requested/confirmed 예약이 있으면 거부
create or replace function public.delete_listing(p_listing_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.listings;
begin
  select * into v_row from public.listings where id = p_listing_id and deleted_at is null for update;
  if not found then
    raise exception 'delete_listing: not found' using errcode = 'SY001';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'delete_listing: owner/admin only' using errcode = '42501';
  end if;
  if exists (select 1 from public.reservations r where r.listing_id = p_listing_id
               and r.status in ('requested', 'confirmed') and r.check_out > public.stay_today()) then
    raise exception 'delete_listing: active reservations' using errcode = 'SY007';
  end if;
  update public.listings set deleted_at = now(), status = case when status = 'suspended' then status else 'unlisted' end
   where id = p_listing_id;
  delete from public.wishlists where listing_id = p_listing_id;
  perform public.write_audit(v_row.org_id, 'listing.delete', 'stay_listing', p_listing_id::text);
end;
$$;

-- 날짜 막기 / 풀기. 막는 구간이 활성 예약과 겹치면 SY003
create or replace function public.block_dates(p_listing_id uuid, p_start date, p_end date, p_note text default '')
returns public.availability_blocks
language plpgsql
security definer
set search_path = ''
as $$
declare v_l public.listings; v_row public.availability_blocks;
begin
  select * into v_l from public.listings where id = p_listing_id and deleted_at is null;
  if not found then
    raise exception 'block_dates: not found' using errcode = 'SY001';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_l.org_id, array['owner', 'admin', 'member']) then
    raise exception 'block_dates: not a member' using errcode = '42501';
  end if;
  if p_start >= p_end or p_start < public.stay_today() then
    raise exception 'block_dates: invalid dates' using errcode = 'SY002';
  end if;
  if not public.stay_range_is_free(p_listing_id, p_start, p_end) then
    raise exception 'block_dates: overlaps reservation or block' using errcode = 'SY003';
  end if;
  begin
    insert into public.availability_blocks (org_id, listing_id, start_date, end_date, note, created_by)
    values (v_l.org_id, p_listing_id, p_start, p_end, public.stay_clean_text(p_note), auth.uid())
    returning * into v_row;
  exception when exclusion_violation then
    raise exception 'block_dates: overlaps block' using errcode = 'SY003';
  end;
  return v_row;
end;
$$;

create or replace function public.unblock_dates(p_block_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_b public.availability_blocks;
begin
  select * into v_b from public.availability_blocks where id = p_block_id;
  if not found then
    raise exception 'unblock_dates: not found' using errcode = 'SY001';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_b.org_id, array['owner', 'admin', 'member']) then
    raise exception 'unblock_dates: not a member' using errcode = '42501';
  end if;
  delete from public.availability_blocks where id = p_block_id;
end;
$$;

-- 예약 요청 승인·거절(requested 만, 만료 전)
create or replace function public.respond_reservation(p_reservation_id uuid, p_accept boolean)
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.reservations;
begin
  select * into v_row from public.reservations where id = p_reservation_id for update;
  if not found then
    raise exception 'respond_reservation: not found' using errcode = 'SY001';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'respond_reservation: not a member' using errcode = '42501';
  end if;
  if v_row.status <> 'requested' or v_row.expires_at < now() then
    raise exception 'respond_reservation: % not allowed', v_row.status using errcode = 'SY007';
  end if;
  update public.reservations
     set status = case when p_accept then 'confirmed' else 'declined' end, responded_at = now(), expires_at = null
   where id = p_reservation_id returning * into v_row;
  perform public.write_audit(v_row.org_id, case when p_accept then 'reservation.confirm' else 'reservation.decline' end,
                             'stay_reservation', p_reservation_id::text);
  return v_row;
end;
$$;

-- 호스트 취소(confirmed, 체크인 전). 사유 필수. 패널티는 Phase 2(01_PRD D4)
create or replace function public.host_cancel_reservation(p_reservation_id uuid, p_reason text)
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.reservations;
begin
  select * into v_row from public.reservations where id = p_reservation_id for update;
  if not found then
    raise exception 'host_cancel_reservation: not found' using errcode = 'SY001';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin']) then
    raise exception 'host_cancel_reservation: owner/admin only' using errcode = '42501';
  end if;
  if v_row.status <> 'confirmed' or v_row.check_in <= public.stay_today() then
    raise exception 'host_cancel_reservation: not allowed' using errcode = 'SY007';
  end if;
  if char_length(public.stay_clean_text(p_reason)) < 5 then
    raise exception 'host_cancel_reservation: reason required' using errcode = '22023';
  end if;
  update public.reservations
     set status = 'canceled_by_host', canceled_at = now(), cancel_reason = public.stay_clean_text(p_reason)
   where id = p_reservation_id returning * into v_row;
  perform public.write_audit(v_row.org_id, 'reservation.host_cancel', 'stay_reservation', p_reservation_id::text);
  return v_row;
end;
$$;

-- 리뷰 답글(1회)
create or replace function public.reply_review(p_review_id uuid, p_reply text)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.reviews;
begin
  select * into v_row from public.reviews where id = p_review_id for update;
  if not found then
    raise exception 'reply_review: not found' using errcode = 'SY001';
  end if;
  if not public.is_service_caller() and not public.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'reply_review: not a member' using errcode = '42501';
  end if;
  if v_row.host_reply is not null then
    raise exception 'reply_review: already replied' using errcode = 'SY009';
  end if;
  update public.reviews set host_reply = public.stay_clean_text(p_reply), host_replied_at = now()
   where id = p_review_id returning * into v_row;
  return v_row;
end;
$$;

-- 호스트 예약함(게스트 표시 이름 포함)
create or replace function public.host_reservations(p_org_id uuid, p_status text default null, p_limit integer default 50, p_offset integer default 0)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_org_member(p_org_id) then
    raise exception 'host_reservations: not a member' using errcode = '42501';
  end if;
  return query
  select to_jsonb(r) || jsonb_build_object(
           'listing_title', l.title,
           'guest_display_name', coalesce(nullif(pr.display_name, ''), '게스트'),
           'guest_avatar_url', pr.avatar_url)
    from public.reservations r
    join public.listings l on l.id = r.listing_id
    left join public.profiles pr on pr.id = r.guest_user_id
   where r.org_id = p_org_id and (p_status is null or r.status = p_status)
   order by r.check_in desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- ---------------------------------------------------------------------
-- 13. 게스트 RPC (authenticated, SECURITY DEFINER). 게스트 = auth.uid()
-- ---------------------------------------------------------------------
-- 예약 생성. 리뷰 #3(userId 신뢰), #11(겹침·기간·인원 검사 없음) 대응
create or replace function public.create_reservation(
  p_listing_id uuid, p_check_in date, p_check_out date,
  p_adults integer, p_children integer default 0, p_infants integer default 0,
  p_message text default ''
)
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_l public.listings; v_row public.reservations; v_nights integer;
begin
  v_uid := public.stay_require_active_user();
  perform public.stay_rate_limit('reserve:' || v_uid::text, 10, 3600);
  select * into v_l from public.listings where id = p_listing_id and status = 'published' and deleted_at is null;
  if not found then
    raise exception 'create_reservation: listing not found' using errcode = 'SY001';
  end if;
  if public.is_org_member(v_l.org_id) then
    raise exception 'create_reservation: own listing' using errcode = 'SY006';
  end if;
  if p_check_in is null or p_check_out is null or p_check_in >= p_check_out or p_check_in < public.stay_today() then
    raise exception 'create_reservation: invalid dates' using errcode = 'SY002';
  end if;
  v_nights := p_check_out - p_check_in;
  if v_nights < v_l.min_nights or v_nights > v_l.max_nights then
    raise exception 'create_reservation: nights % outside %-%', v_nights, v_l.min_nights, v_l.max_nights using errcode = 'SY005';
  end if;
  if coalesce(p_adults, 0) < 1 or coalesce(p_children, 0) < 0 or coalesce(p_infants, 0) not between 0 and 5
     or p_adults + coalesce(p_children, 0) > v_l.max_guests then
    raise exception 'create_reservation: guests exceed %', v_l.max_guests using errcode = 'SY004';
  end if;
  if (v_l.available_from is not null and p_check_in < v_l.available_from)
     or (v_l.available_to is not null and p_check_out > v_l.available_to)
     or not public.stay_range_is_free(p_listing_id, p_check_in, p_check_out) then
    raise exception 'create_reservation: dates unavailable' using errcode = 'SY003';
  end if;
  begin
    insert into public.reservations (org_id, listing_id, guest_user_id, check_in, check_out,
                                     adult_count, children_count, infant_count, status,
                                     nightly_price, cleaning_fee, service_fee, total_price, guest_message,
                                     expires_at, responded_at)
    values (v_l.org_id, p_listing_id, v_uid, p_check_in, p_check_out,
            p_adults, coalesce(p_children, 0), coalesce(p_infants, 0),
            case when v_l.instant_book then 'confirmed' else 'requested' end,
            v_l.price_per_night, v_l.cleaning_fee, 0, v_l.price_per_night * v_nights + v_l.cleaning_fee,
            public.stay_clean_text(p_message),
            case when v_l.instant_book then null else now() + interval '24 hours' end,
            case when v_l.instant_book then now() else null end)
    returning * into v_row;
  exception when exclusion_violation then
    raise exception 'create_reservation: dates just taken' using errcode = 'SY003';
  end;
  -- 게스트는 호스트 조직 멤버가 아니므로(write_audit 은 멤버만 허용) 게스트 개인 조직에 남긴다
  perform public.write_audit(public.personal_org_id(), 'reservation.create', 'stay_reservation', v_row.id::text,
                             null, null, jsonb_build_object('host_org', v_l.org_id, 'status', v_row.status));
  return v_row;
end;
$$;

-- 게스트 취소: requested 언제나, confirmed 는 체크인 전날까지(환불 규정은 Phase 2 결제와 함께)
create or replace function public.guest_cancel_reservation(p_reservation_id uuid, p_reason text default null)
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_row public.reservations;
begin
  v_uid := public.stay_require_active_user();
  select * into v_row from public.reservations where id = p_reservation_id for update;
  if not found or v_row.guest_user_id <> v_uid then
    raise exception 'guest_cancel_reservation: not found' using errcode = 'SY001';
  end if;
  if not (v_row.status = 'requested' or (v_row.status = 'confirmed' and v_row.check_in > public.stay_today())) then
    raise exception 'guest_cancel_reservation: % not allowed', v_row.status using errcode = 'SY007';
  end if;
  update public.reservations
     set status = 'canceled_by_guest', canceled_at = now(), cancel_reason = public.stay_clean_text(p_reason), expires_at = null
   where id = p_reservation_id returning * into v_row;
  perform public.write_audit(public.personal_org_id(), 'reservation.guest_cancel', 'stay_reservation', p_reservation_id::text,
                             null, null, jsonb_build_object('host_org', v_row.org_id));
  return v_row;
end;
$$;

-- 리뷰 작성: completed 예약의 게스트, 체크아웃 후 14일 이내, 예약당 1개. 리뷰 #12 대응
create or replace function public.create_review(p_reservation_id uuid, p_rating integer, p_content text)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_res public.reservations; v_row public.reviews;
begin
  v_uid := public.stay_require_active_user();
  perform public.stay_rate_limit('review:' || v_uid::text, 10, 3600);
  select * into v_res from public.reservations where id = p_reservation_id;
  if not found or v_res.guest_user_id <> v_uid then
    raise exception 'create_review: reservation not found' using errcode = 'SY001';
  end if;
  if v_res.status <> 'completed' or public.stay_today() > v_res.check_out + 14 then
    raise exception 'create_review: not allowed' using errcode = 'SY008';
  end if;
  begin
    insert into public.reviews (org_id, listing_id, reservation_id, guest_user_id, rating, content)
    values (v_res.org_id, v_res.listing_id, p_reservation_id, v_uid, p_rating, public.stay_clean_text(p_content))
    returning * into v_row;
  exception when unique_violation then
    raise exception 'create_review: duplicate' using errcode = 'SY009';
  end;
  return v_row;
end;
$$;

-- 찜 켜기/끄기. 공개 숙소만 추가. 반환: 찜 상태
create or replace function public.toggle_wishlist(p_listing_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := public.stay_require_active_user();
  perform public.stay_rate_limit('wishlist:' || v_uid::text, 120, 60);
  delete from public.wishlists where user_id = v_uid and listing_id = p_listing_id;
  if found then
    return false;
  end if;
  if not exists (select 1 from public.listings l where l.id = p_listing_id and l.status = 'published' and l.deleted_at is null) then
    raise exception 'toggle_wishlist: listing not found' using errcode = 'SY001';
  end if;
  insert into public.wishlists (user_id, listing_id) values (v_uid, p_listing_id) on conflict do nothing;
  return true;
end;
$$;

-- 내 찜 목록(공개 카드)
create or replace function public.my_wishlist()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := public.stay_require_active_user();
  return query
  select public.stay_listing_card(l) || jsonb_build_object('wished_at', w.created_at)
    from public.wishlists w join public.listings l on l.id = w.listing_id
   where w.user_id = v_uid and l.status = 'published' and l.deleted_at is null
   order by w.created_at desc;
end;
$$;

-- 내 여행(예약 + 숙소 카드, 확정·완료면 주소와 체크인 안내 포함)
create or replace function public.my_trips()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := public.stay_require_active_user();
  return query
  select to_jsonb(r) || jsonb_build_object(
           'listing', public.stay_listing_card(l),
           'private', case when r.status in ('confirmed', 'completed') then
                        jsonb_build_object('street_address', p.street_address, 'detail_address', p.detail_address,
                                           'postcode', p.postcode, 'lat', p.lat, 'lng', p.lng, 'checkin_guide', p.checkin_guide)
                      end,
           'review_id', (select rv.id from public.reviews rv where rv.reservation_id = r.id))
    from public.reservations r
    join public.listings l on l.id = r.listing_id
    left join public.listing_private p on p.listing_id = r.listing_id
   where r.guest_user_id = v_uid
   order by r.check_in desc;
end;
$$;

-- ---------------------------------------------------------------------
-- 14. 정리 RPC (service_role 전용, 크론 매시간)
-- ---------------------------------------------------------------------
create or replace function public.stay_run_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_expired integer; v_completed integer;
begin
  if not public.is_service_caller() then
    raise exception 'stay_run_maintenance: service_role only' using errcode = '42501';
  end if;
  update public.reservations set status = 'expired', expires_at = null
   where status = 'requested' and expires_at < now();
  get diagnostics v_expired = row_count;
  update public.reservations set status = 'completed', completed_at = now()
   where status = 'confirmed' and check_out <= public.stay_today();
  get diagnostics v_completed = row_count;
  return jsonb_build_object('expired', v_expired, 'completed', v_completed, 'at', now());
end;
$$;

-- ---------------------------------------------------------------------
-- 15. 함수 EXECUTE 정리
-- ---------------------------------------------------------------------
do $$
declare r record;
begin
  -- 코어 함수 권한을 건드리지 않도록 이 파일이 만든 함수 이름만 대상으로 한다
  for r in select p.oid::regprocedure as sig from pg_proc p
           where p.pronamespace = (select c.relnamespace from pg_class c where c.oid = 'public.listings'::regclass)
             and p.prokind = 'f'
             and p.proname = any (array[
               'stay_clean_text', 'stay_today', 'listing_private_sync_public_geo', 'reviews_refresh_listing_rating',
               'stay_plan_feature_int', 'stay_require_active_user', 'stay_rate_limit', 'stay_listing_card',
               'stay_range_is_free', 'search_listings', 'get_listing_public', 'listing_unavailable_ranges',
               'listing_reviews_public', 'create_listing', 'transition_listing', 'suspend_listing', 'delete_listing',
               'block_dates', 'unblock_dates', 'respond_reservation', 'host_cancel_reservation', 'reply_review',
               'host_reservations', 'create_reservation', 'guest_cancel_reservation', 'create_review',
               'toggle_wishlist', 'my_wishlist', 'my_trips', 'stay_run_maintenance'])
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    execute format('grant execute on function %s to service_role', r.sig);
  end loop;
end $$;

-- 서울 기준 날짜(순수 함수). 클라이언트 달력이 서버와 같은 '오늘'을 쓰게 연다
grant execute on function public.stay_today() to anon, authenticated;
-- 공개 RPC(비로그인 검색·상세)
grant execute on function public.search_listings(numeric, numeric, numeric, numeric, text, date, date, integer, integer, integer, text, integer, integer) to anon, authenticated;
grant execute on function public.get_listing_public(uuid) to anon, authenticated;
grant execute on function public.listing_unavailable_ranges(uuid, date, date) to anon, authenticated;
grant execute on function public.listing_reviews_public(uuid, integer, integer) to anon, authenticated;
-- 호스트 RPC
grant execute on function public.create_listing(uuid) to authenticated;
grant execute on function public.transition_listing(uuid, text) to authenticated;
grant execute on function public.delete_listing(uuid) to authenticated;
grant execute on function public.block_dates(uuid, date, date, text) to authenticated;
grant execute on function public.unblock_dates(uuid) to authenticated;
grant execute on function public.respond_reservation(uuid, boolean) to authenticated;
grant execute on function public.host_cancel_reservation(uuid, text) to authenticated;
grant execute on function public.reply_review(uuid, text) to authenticated;
grant execute on function public.host_reservations(uuid, text, integer, integer) to authenticated;
-- 게스트 RPC
grant execute on function public.create_reservation(uuid, date, date, integer, integer, integer, text) to authenticated;
grant execute on function public.guest_cancel_reservation(uuid, text) to authenticated;
grant execute on function public.create_review(uuid, integer, text) to authenticated;
grant execute on function public.toggle_wishlist(uuid) to authenticated;
grant execute on function public.my_wishlist() to authenticated;
grant execute on function public.my_trips() to authenticated;
-- suspend_listing, stay_run_maintenance 는 service_role 만(위 루프에서 부여). anon/authenticated 는 42501.
