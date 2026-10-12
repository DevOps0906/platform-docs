-- =====================================================================
-- 1800_poll.sql
-- live-poll 도메인(실시간 청중 투표 + Q&A). 선행: core 0000~0006
-- 기획: docs/products/live-poll/05_DATA_MODEL.md
-- 모놀리스 사본: docs/products/live-poll/supabase/monolith/migrations/0002_poll_domain.sql
--   (이 파일에서 @@modular-only 블록을 지우고 core./poll. 접두사를 public.으로 바꾼 것. 본문은 같다)
--
-- 설계 요점
--   1) 진행자(host)는 Supabase 사용자다. 조직 멤버 + 'poll' 엔타이틀먼트로 RLS를 통과한다.
--   2) 청중(participant)은 Supabase 사용자가 아니다. 서버가 발급한 참가자 토큰(쿠키)만 가진다.
--      DB에는 토큰의 sha256만 둔다. 익명 로그인(signInAnonymously)을 쓰지 않는 이유는
--      core.handle_new_user 가 익명 사용자마다 프로필과 개인 조직을 만들기 때문이다(05장 7절).
--   3) anon 역할은 poll 스키마에 어떤 권한도 없다. 청중의 입장/투표/질문은 Route Handler가
--      service_role로 부르는 RPC(레이트 리밋 포함)로만 들어온다.
--   4) 투표는 votes INSERT 1회(unique(poll_id, participant_id))뿐이다. 집계 카운터 행을 갱신하지 않아
--      핫 로우 경합이 없다. 집계는 브로드캐스터 워커가 250ms~1s 간격으로 collect_broadcasts()에서 만든다.
--   5) 오류 처리: 청중 RPC는 업무 오류를 raise 하지 않고 {ok:false, code} jsonb로 돌려준다.
--      raise 하면 같은 트랜잭션의 레이트 리밋 히트가 롤백되어 대입 공격 카운트가 남지 않기 때문이다.
-- 반복 실행 가능.
-- =====================================================================

-- @@modular-only-begin
create schema if not exists poll;
comment on schema poll is 'live-poll: 실시간 청중 투표와 Q&A';
-- anon 에는 USAGE도 주지 않는다. 청중 경로는 service_role RPC뿐이다.
grant usage on schema poll to authenticated, service_role;
alter default privileges in schema poll grant all on tables to service_role;
alter default privileges in schema poll grant all on sequences to service_role;
alter default privileges in schema poll grant execute on functions to service_role;
alter default privileges in schema poll revoke execute on functions from public;

insert into core.apps (id, name, schema_name, signup_policy, status)
values ('poll', 'Live Poll', 'poll', 'open', 'beta')
on conflict (id) do nothing;
-- @@modular-only-end

-- ---------------------------------------------------------------------
-- 0. 공용 시퀀스와 순수 함수
-- ---------------------------------------------------------------------
-- Q&A 변경 감지용 단조 증가 번호(질문 INSERT/UPDATE, 추천 INSERT마다 증가)
create sequence if not exists poll.poll_change_seq;

-- 금칙어 비교용 정규화: 소문자, 공백/구두점 제거. 한글에 \b 단어 경계를 쓰지 않는다.
create or replace function poll.normalize_text(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(lower(coalesce(p_text, '')), '[[:space:][:punct:]]+', '', 'g');
$$;

-- 사용자 입력 정리: 제어문자 제거 + 앞뒤 공백 제거. HTML은 저장 그대로 두고 렌더에서 텍스트로만 출력한다.
create or replace function poll.clean_text(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select btrim(regexp_replace(coalesce(p_text, ''), '[[:cntrl:]]+', ' ', 'g'));
$$;

-- ---------------------------------------------------------------------
-- 1. events: 행사(방). 6자리 입장 코드, 상태 draft/live/ended/archived
-- ---------------------------------------------------------------------
create table if not exists poll.events (
  id                          uuid primary key default gen_random_uuid(),
  org_id                      uuid not null references core.organizations(id) on delete cascade,
  code                        text not null constraint events_code_check check (code ~ '^[0-9]{6}$'),
  title                       text not null constraint events_title_check check (char_length(title) between 1 and 120),
  description                 text not null default '' constraint events_description_check check (char_length(description) <= 500),
  status                      text not null default 'draft'
                              constraint events_status_check check (status in ('draft', 'live', 'ended', 'archived')),
  join_locked                 boolean not null default false,
  passcode_hash               text,
  settings                    jsonb not null default '{}'::jsonb
                              constraint events_settings_check check (jsonb_typeof(settings) = 'object' and pg_column_size(settings) <= 4096),
  current_poll_id             uuid,
  max_participants            integer not null default 100 constraint events_max_participants_check check (max_participants between 1 and 100000),
  overlay_key_hash            text,
  state_version               bigint not null default 1,
  broadcast_state_version     bigint not null default 0,
  broadcast_vote_seq          bigint not null default 0,
  broadcast_qna_seq           bigint not null default 0,
  broadcast_participant_count integer not null default 0,
  broadcast_seq               bigint not null default 0,
  broadcast_at                timestamptz,
  started_at                  timestamptz,
  ended_at                    timestamptz,
  archived_at                 timestamptz,
  retention_until             timestamptz,
  purged_at                   timestamptz,
  created_by                  uuid,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  deleted_at                  timestamptz,
  constraint events_id_org_uniq unique (id, org_id)
);
comment on column poll.events.code is '6자리 숫자 입장 코드. archived/삭제 전까지 전역 유일(부분 유니크 인덱스)';
comment on column poll.events.settings is 'qna_enabled, qna_moderation, allow_anonymous, share_results_after_end, require_captcha (01_PRD 3장)';
comment on column poll.events.passcode_hash is 'sha256(event_id:passcode) hex. null이면 코드만으로 입장';
comment on column poll.events.overlay_key_hash is 'OBS 오버레이 키의 sha256 hex. 원문 키는 rotate_overlay_key 반환값으로 1회만 보여 준다';
comment on column poll.events.state_version is '공개 상태(제목, 상태, 현재 문항, 잠금, 설정)가 바뀔 때마다 트리거가 1 올린다';

create unique index if not exists events_code_active_uniq on poll.events (code) where status <> 'archived' and deleted_at is null;
create index if not exists events_org_created_idx on poll.events (org_id, created_at desc);
create index if not exists events_live_idx on poll.events (broadcast_at) where status = 'live' and deleted_at is null;

-- ---------------------------------------------------------------------
-- 2. polls: 행사 안의 투표 문항. 단일/복수 선택, 평점
-- ---------------------------------------------------------------------
create table if not exists poll.polls (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references core.organizations(id) on delete cascade,
  event_id           uuid not null,
  position           integer not null default 0,
  kind               text not null default 'single_choice'
                     constraint polls_kind_check check (kind in ('single_choice', 'multiple_choice', 'rating')),
  title              text not null constraint polls_title_check check (char_length(title) between 1 and 200),
  max_choices        smallint not null default 1 constraint polls_max_choices_check check (max_choices between 1 and 10),
  rating_scale       smallint not null default 5 constraint polls_rating_scale_check check (rating_scale between 2 and 10),
  results_visibility text not null default 'live'
                     constraint polls_results_visibility_check check (results_visibility in ('live', 'after_close', 'host_only')),
  status             text not null default 'draft'
                     constraint polls_status_check check (status in ('draft', 'open', 'closed')),
  opened_at          timestamptz,
  closed_at          timestamptz,
  created_by         uuid,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint polls_event_fk foreign key (event_id, org_id) references poll.events (id, org_id) on delete cascade,
  constraint polls_id_org_uniq unique (id, org_id),
  constraint polls_id_event_uniq unique (id, event_id)
);
-- 한 행사에 열린 문항은 하나뿐
create unique index if not exists polls_one_open_per_event_uniq on poll.polls (event_id) where status = 'open';
create index if not exists polls_event_position_idx on poll.polls (event_id, position);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'events_current_poll_fk') then
    alter table poll.events
      add constraint events_current_poll_fk foreign key (current_poll_id) references poll.polls (id) on delete set null;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. poll_options: 선택지(문항당 2~10개, 열기 전 검사)
-- ---------------------------------------------------------------------
create table if not exists poll.poll_options (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references core.organizations(id) on delete cascade,
  poll_id    uuid not null,
  position   integer not null default 0,
  label      text not null constraint poll_options_label_check check (char_length(label) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint poll_options_poll_fk foreign key (poll_id, org_id) references poll.polls (id, org_id) on delete cascade
);
create index if not exists poll_options_poll_idx on poll.poll_options (poll_id, position);

-- ---------------------------------------------------------------------
-- 4. participants: 청중. Supabase 사용자가 아니다. 토큰 원문은 저장하지 않는다
-- ---------------------------------------------------------------------
create table if not exists poll.participants (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references core.organizations(id) on delete cascade,
  event_id     uuid not null,
  token_hash   text not null constraint participants_token_hash_check check (token_hash ~ '^[0-9a-f]{64}$'),
  nickname     text constraint participants_nickname_check check (nickname is null or char_length(nickname) between 1 and 30),
  is_blocked   boolean not null default false,
  joined_at    timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint participants_event_fk foreign key (event_id, org_id) references poll.events (id, org_id) on delete cascade,
  constraint participants_token_uniq unique (token_hash),
  constraint participants_id_event_uniq unique (id, event_id)
);
comment on column poll.participants.token_hash is 'sha256(참가자 토큰) hex. 진행자에게 노출하지 않는다(컬럼 GRANT 제외)';
create index if not exists participants_event_idx on poll.participants (event_id, joined_at);

-- ---------------------------------------------------------------------
-- 5. votes: 1인 1문항 1제출. 선택지 배열 또는 평점 중 하나
-- ---------------------------------------------------------------------
create table if not exists poll.votes (
  id             bigint generated always as identity primary key,
  org_id         uuid not null references core.organizations(id) on delete cascade,
  event_id       uuid not null,
  poll_id        uuid not null,
  participant_id uuid not null,
  option_ids     uuid[] not null default '{}',
  rating         smallint,
  created_at     timestamptz not null default now(),
  constraint votes_poll_fk foreign key (poll_id, event_id) references poll.polls (id, event_id) on delete cascade,
  constraint votes_participant_fk foreign key (participant_id, event_id) references poll.participants (id, event_id) on delete cascade,
  constraint votes_one_per_participant_uniq unique (poll_id, participant_id),
  constraint votes_payload_check check ((rating is null) <> (cardinality(option_ids) = 0)),
  constraint votes_option_count_check check (cardinality(option_ids) <= 10)
);
create index if not exists votes_poll_id_idx on poll.votes (poll_id, id);

-- ---------------------------------------------------------------------
-- 6. poll_results: 문항 종료 시 확정 집계. 보존 기간이 지나 원본 투표를 지워도 남는다
-- ---------------------------------------------------------------------
create table if not exists poll.poll_results (
  poll_id      uuid primary key references poll.polls (id) on delete cascade,
  org_id       uuid not null references core.organizations(id) on delete cascade,
  event_id     uuid not null,
  total_votes  integer not null default 0,
  counts       jsonb not null default '{}'::jsonb,
  finalized_at timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists poll_results_event_idx on poll.poll_results (event_id);

-- ---------------------------------------------------------------------
-- 7. qna_questions / qna_upvotes: 청중 질문과 추천
-- ---------------------------------------------------------------------
create table if not exists poll.qna_questions (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references core.organizations(id) on delete cascade,
  event_id       uuid not null,
  participant_id uuid not null,
  body           text not null constraint qna_questions_body_check check (char_length(body) between 1 and 300),
  show_nickname  boolean not null default true,
  status         text not null default 'pending'
                 constraint qna_questions_status_check check (status in ('pending', 'visible', 'answered', 'hidden', 'rejected')),
  hidden_reason  text constraint qna_questions_hidden_reason_check check (hidden_reason is null or hidden_reason in ('banned_word', 'host', 'blocked_participant')),
  change_seq     bigint not null default nextval('poll.poll_change_seq'),
  moderated_by   uuid,
  moderated_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint qna_questions_event_fk foreign key (event_id, org_id) references poll.events (id, org_id) on delete cascade,
  constraint qna_questions_participant_fk foreign key (participant_id, event_id) references poll.participants (id, event_id) on delete cascade,
  constraint qna_questions_id_event_uniq unique (id, event_id)
);
create index if not exists qna_questions_event_status_idx on poll.qna_questions (event_id, status, created_at);
create index if not exists qna_questions_event_seq_idx on poll.qna_questions (event_id, change_seq);

create table if not exists poll.qna_upvotes (
  id             bigint generated always as identity primary key,
  org_id         uuid not null references core.organizations(id) on delete cascade,
  event_id       uuid not null,
  question_id    uuid not null,
  participant_id uuid not null,
  change_seq     bigint not null default nextval('poll.poll_change_seq'),
  created_at     timestamptz not null default now(),
  constraint qna_upvotes_question_fk foreign key (question_id, event_id) references poll.qna_questions (id, event_id) on delete cascade,
  constraint qna_upvotes_participant_fk foreign key (participant_id, event_id) references poll.participants (id, event_id) on delete cascade,
  constraint qna_upvotes_once_uniq unique (question_id, participant_id)
);
create index if not exists qna_upvotes_event_seq_idx on poll.qna_upvotes (event_id, change_seq);

-- ---------------------------------------------------------------------
-- 8. banned_words: 닉네임/질문 금칙어. org_id null = 플랫폼 기본 목록(service_role만 관리)
-- ---------------------------------------------------------------------
create table if not exists poll.banned_words (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid references core.organizations(id) on delete cascade,
  word       text not null constraint banned_words_word_check check (char_length(word) between 1 and 40),
  normalized text generated always as (poll.normalize_text(word)) stored,
  created_by uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists banned_words_org_word_uniq
  on poll.banned_words (coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid), normalized);

-- ---------------------------------------------------------------------
-- 9. 트리거: updated_at, 상태 전이 강제, state_version 증가, 작성자 기록
-- ---------------------------------------------------------------------
drop trigger if exists events_set_updated_at on poll.events;
create trigger events_set_updated_at before update on poll.events
  for each row execute function core.set_updated_at();
drop trigger if exists polls_set_updated_at on poll.polls;
create trigger polls_set_updated_at before update on poll.polls
  for each row execute function core.set_updated_at();
drop trigger if exists poll_options_set_updated_at on poll.poll_options;
create trigger poll_options_set_updated_at before update on poll.poll_options
  for each row execute function core.set_updated_at();
drop trigger if exists poll_results_set_updated_at on poll.poll_results;
create trigger poll_results_set_updated_at before update on poll.poll_results
  for each row execute function core.set_updated_at();
drop trigger if exists qna_questions_set_updated_at on poll.qna_questions;
create trigger qna_questions_set_updated_at before update on poll.qna_questions
  for each row execute function core.set_updated_at();

-- events: 상태 전이(service_role 쓰기에도 적용) + 공개 상태 변경 시 state_version 증가
create or replace function poll.events_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status, new.status) in (('draft', 'live'), ('draft', 'archived'), ('live', 'ended'),
                                         ('ended', 'live'), ('ended', 'archived'))) then
      raise exception 'events: transition % -> % not allowed', old.status, new.status using errcode = '22023';
    end if;
  end if;
  if new.org_id is distinct from old.org_id or new.code is distinct from old.code then
    raise exception 'events: org_id/code are immutable' using errcode = '42501';
  end if;
  if (new.title, new.description, new.status, new.join_locked, new.settings, new.current_poll_id, new.passcode_hash)
     is distinct from
     (old.title, old.description, old.status, old.join_locked, old.settings, old.current_poll_id, old.passcode_hash) then
    new.state_version := old.state_version + 1;
  end if;
  return new;
end;
$$;
drop trigger if exists events_before_update on poll.events;
create trigger events_before_update before update on poll.events
  for each row execute function poll.events_before_update();

-- polls: 상태 전이 + 열린 뒤에는 내용 변경 금지 + 작성자 기록
create or replace function poll.polls_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, auth.uid());
    if new.status <> 'draft' then
      raise exception 'polls: new poll must be draft' using errcode = '22023';
    end if;
    return new;
  end if;
  if new.org_id is distinct from old.org_id or new.event_id is distinct from old.event_id then
    raise exception 'polls: org_id/event_id are immutable' using errcode = '42501';
  end if;
  if new.status is distinct from old.status then
    if not ((old.status, new.status) in (('draft', 'open'), ('open', 'closed'), ('closed', 'open'))) then
      raise exception 'polls: transition % -> % not allowed', old.status, new.status using errcode = '22023';
    end if;
  end if;
  if old.status <> 'draft' and (new.kind, new.title, new.max_choices, new.rating_scale)
                               is distinct from (old.kind, old.title, old.max_choices, old.rating_scale) then
    raise exception 'polls: content is frozen after opening' using errcode = 'PL011';
  end if;
  return new;
end;
$$;
drop trigger if exists polls_before_write on poll.polls;
create trigger polls_before_write before insert or update on poll.polls
  for each row execute function poll.polls_before_write();

-- qna_questions: 상태 전이 + 변경 번호 갱신
create or replace function poll.qna_questions_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not ((old.status, new.status) in (('pending', 'visible'), ('pending', 'rejected'), ('pending', 'hidden'),
                                         ('visible', 'answered'), ('visible', 'hidden'), ('answered', 'visible'),
                                         ('hidden', 'visible'), ('rejected', 'visible'))) then
      raise exception 'qna_questions: transition % -> % not allowed', old.status, new.status using errcode = '22023';
    end if;
  end if;
  new.change_seq := nextval('poll.poll_change_seq');
  return new;
end;
$$;
drop trigger if exists qna_questions_before_update on poll.qna_questions;
create trigger qna_questions_before_update before update on poll.qna_questions
  for each row execute function poll.qna_questions_before_update();

-- 청중 데이터와 집계는 사용자 세션에서 직접 쓰지 못한다(이중 잠금). DEFINER RPC와 service_role만.
drop trigger if exists participants_guard_write on poll.participants;
create trigger participants_guard_write before insert or update or delete on poll.participants
  for each row execute function core.guard_privileged_write();
drop trigger if exists votes_guard_write on poll.votes;
create trigger votes_guard_write before insert or update or delete on poll.votes
  for each row execute function core.guard_privileged_write();
drop trigger if exists poll_results_guard_write on poll.poll_results;
create trigger poll_results_guard_write before insert or update or delete on poll.poll_results
  for each row execute function core.guard_privileged_write();
drop trigger if exists qna_questions_guard_write on poll.qna_questions;
create trigger qna_questions_guard_write before insert or update or delete on poll.qna_questions
  for each row execute function core.guard_privileged_write();
drop trigger if exists qna_upvotes_guard_write on poll.qna_upvotes;
create trigger qna_upvotes_guard_write before insert or update or delete on poll.qna_upvotes
  for each row execute function core.guard_privileged_write();

-- ---------------------------------------------------------------------
-- 10. RLS와 GRANT
--   진행자(authenticated): 자기 조직 + 'poll' 엔타이틀먼트일 때만 읽는다.
--   쓰기: events 는 비상태 컬럼만(컬럼 GRANT), polls/poll_options 는 draft 일 때만, 나머지는 RPC.
--   anon: 아무 권한 없음.
-- ---------------------------------------------------------------------
alter table poll.events        enable row level security;
alter table poll.polls         enable row level security;
alter table poll.poll_options  enable row level security;
alter table poll.participants  enable row level security;
alter table poll.votes         enable row level security;
alter table poll.poll_results  enable row level security;
alter table poll.qna_questions enable row level security;
alter table poll.qna_upvotes   enable row level security;
alter table poll.banned_words  enable row level security;

revoke all on table poll.events, poll.polls, poll.poll_options, poll.participants, poll.votes,
                    poll.poll_results, poll.qna_questions, poll.qna_upvotes, poll.banned_words
  from public, anon, authenticated;
revoke all on sequence poll.poll_change_seq from public, anon, authenticated;
grant all on table poll.events, poll.polls, poll.poll_options, poll.participants, poll.votes,
                   poll.poll_results, poll.qna_questions, poll.qna_upvotes, poll.banned_words
  to service_role;
grant usage, select on sequence poll.poll_change_seq to service_role;

-- events
grant select on poll.events to authenticated;
grant update (title, description, settings, join_locked) on poll.events to authenticated;
drop policy if exists events_select on poll.events;
create policy events_select on poll.events for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll') and deleted_at is null);
drop policy if exists events_update on poll.events;
create policy events_update on poll.events for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'poll')
         and deleted_at is null and status <> 'archived')
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'poll'));

-- polls (draft 만 편집. 상태는 transition_poll 로만)
grant select, delete on poll.polls to authenticated;
grant insert (org_id, event_id, position, kind, title, max_choices, rating_scale, results_visibility) on poll.polls to authenticated;
grant update (position, kind, title, max_choices, rating_scale, results_visibility) on poll.polls to authenticated;
drop policy if exists polls_select on poll.polls;
create policy polls_select on poll.polls for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll'));
drop policy if exists polls_insert on poll.polls;
create policy polls_insert on poll.polls for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'poll')
              and exists (select 1 from poll.events e
                          where e.id = polls.event_id and e.org_id = polls.org_id and e.status in ('draft', 'live') and e.deleted_at is null));
drop policy if exists polls_update on poll.polls;
create policy polls_update on poll.polls for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'poll') and status = 'draft')
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and status = 'draft');
drop policy if exists polls_delete on poll.polls;
create policy polls_delete on poll.polls for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin']) and status <> 'open');

-- poll_options (부모 문항이 draft 일 때만)
grant select, delete on poll.poll_options to authenticated;
grant insert (org_id, poll_id, position, label) on poll.poll_options to authenticated;
grant update (position, label) on poll.poll_options to authenticated;
drop policy if exists poll_options_select on poll.poll_options;
create policy poll_options_select on poll.poll_options for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll'));
drop policy if exists poll_options_insert on poll.poll_options;
create policy poll_options_insert on poll.poll_options for insert to authenticated
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member']) and core.has_entitlement(org_id, 'poll')
              and exists (select 1 from poll.polls p where p.id = poll_options.poll_id and p.org_id = poll_options.org_id and p.status = 'draft')
              and (select count(*) from poll.poll_options o where o.poll_id = poll_options.poll_id) < 10);
drop policy if exists poll_options_update on poll.poll_options;
create policy poll_options_update on poll.poll_options for update to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member'])
         and exists (select 1 from poll.polls p where p.id = poll_options.poll_id and p.status = 'draft'))
  with check (core.has_org_role(org_id, array['owner', 'admin', 'member'])
              and exists (select 1 from poll.polls p where p.id = poll_options.poll_id and p.status = 'draft'));
drop policy if exists poll_options_delete on poll.poll_options;
create policy poll_options_delete on poll.poll_options for delete to authenticated
  using (core.has_org_role(org_id, array['owner', 'admin', 'member'])
         and exists (select 1 from poll.polls p where p.id = poll_options.poll_id and p.status = 'draft'));

-- participants: token_hash 컬럼은 진행자에게도 주지 않는다
grant select (id, org_id, event_id, nickname, is_blocked, joined_at, last_seen_at) on poll.participants to authenticated;
drop policy if exists participants_select on poll.participants;
create policy participants_select on poll.participants for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll'));

-- votes / poll_results / qna (읽기만)
grant select on poll.votes, poll.poll_results, poll.qna_questions, poll.qna_upvotes to authenticated;
drop policy if exists votes_select on poll.votes;
create policy votes_select on poll.votes for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll'));
drop policy if exists poll_results_select on poll.poll_results;
create policy poll_results_select on poll.poll_results for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll'));
drop policy if exists qna_questions_select on poll.qna_questions;
create policy qna_questions_select on poll.qna_questions for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll'));
drop policy if exists qna_upvotes_select on poll.qna_upvotes;
create policy qna_upvotes_select on poll.qna_upvotes for select to authenticated
  using (core.is_org_member(org_id) and core.has_entitlement(org_id, 'poll'));

-- banned_words: 자기 조직 목록만. 플랫폼 기본 목록(org_id null)은 보이지 않는다
grant select, delete on poll.banned_words to authenticated;
grant insert (org_id, word) on poll.banned_words to authenticated;
drop policy if exists banned_words_select on poll.banned_words;
create policy banned_words_select on poll.banned_words for select to authenticated
  using (org_id is not null and core.is_org_member(org_id));
drop policy if exists banned_words_insert on poll.banned_words;
create policy banned_words_insert on poll.banned_words for insert to authenticated
  with check (org_id is not null and core.has_org_role(org_id, array['owner', 'admin']) and core.has_entitlement(org_id, 'poll'));
drop policy if exists banned_words_delete on poll.banned_words;
create policy banned_words_delete on poll.banned_words for delete to authenticated
  using (org_id is not null and core.has_org_role(org_id, array['owner', 'admin']));

-- ---------------------------------------------------------------------
-- 11. 내부 헬퍼 (SECURITY DEFINER, EXECUTE 없음: 같은 소유자의 DEFINER 함수 안에서만 호출)
-- ---------------------------------------------------------------------
-- 플랜 features 정수 값. 없으면 기본값. -1 은 무제한
create or replace function poll.plan_feature_int(p_org_id uuid, p_key text, p_default integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case when jsonb_typeof(pl.features -> p_key) = 'number' then (pl.features ->> p_key)::integer end
    from core.app_entitlements e
    join core.plans pl on pl.id = e.plan_id
    where e.org_id = p_org_id and e.app_id = 'poll' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now())
    limit 1
  ), p_default);
$$;

create or replace function poll.contains_banned_word(p_org_id uuid, p_text text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from poll.banned_words w
    where (w.org_id is null or w.org_id = p_org_id)
      and w.normalized <> ''
      and position(w.normalized in poll.normalize_text(p_text)) > 0
  );
$$;

-- 암호학적 난수 6자리 코드. archived/삭제되지 않은 행사와 겹치지 않게 최대 20회 시도
create or replace function poll.new_event_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare v_code text; i integer;
begin
  for i in 1..20 loop
    v_code := lpad(((('x' || lpad(encode(extensions.gen_random_bytes(6), 'hex'), 16, '0'))::bit(64)::bigint) % 1000000)::text, 6, '0');
    if not exists (select 1 from poll.events e where e.code = v_code and e.status <> 'archived' and e.deleted_at is null) then
      return v_code;
    end if;
  end loop;
  raise exception 'new_event_code: no free code' using errcode = 'PL014';
end;
$$;

create or replace function poll.token_hash(p_token text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
$$;

-- 문항 집계 jsonb: {total, counts: {option_id|rating: n}}
create or replace function poll.build_poll_result(p_poll_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'total', (select count(*) from poll.votes v where v.poll_id = p_poll_id),
    'counts', coalesce((
      select jsonb_object_agg(x.k, x.c) from (
        select o.option_id::text as k, count(*) as c
        from poll.votes v cross join lateral unnest(v.option_ids) as o(option_id)
        where v.poll_id = p_poll_id
        group by o.option_id
        union all
        select v.rating::text, count(*)
        from poll.votes v
        where v.poll_id = p_poll_id and v.rating is not null
        group by v.rating
      ) x
    ), '{}'::jsonb)
  );
$$;

-- 문항 종료 시 확정 집계 저장(upsert)
create or replace function poll.finalize_poll(p_poll_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_r jsonb; v_p poll.polls;
begin
  select * into v_p from poll.polls where id = p_poll_id;
  if not found then return; end if;
  v_r := poll.build_poll_result(p_poll_id);
  insert into poll.poll_results (poll_id, org_id, event_id, total_votes, counts, finalized_at)
  values (p_poll_id, v_p.org_id, v_p.event_id, (v_r ->> 'total')::integer, v_r -> 'counts', now())
  on conflict (poll_id) do update
    set total_votes = excluded.total_votes, counts = excluded.counts, finalized_at = excluded.finalized_at;
end;
$$;

-- 청중/오버레이에 공개되는 문항 상태. draft 는 공개하지 않는다. 결과는 results_visibility 규칙을 따른다
create or replace function poll.build_public_poll(p_poll_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_p poll.polls; v_show boolean;
begin
  if p_poll_id is null then return null; end if;
  select * into v_p from poll.polls where id = p_poll_id;
  if not found or v_p.status = 'draft' then return null; end if;
  v_show := v_p.results_visibility = 'live' or (v_p.results_visibility = 'after_close' and v_p.status = 'closed');
  return jsonb_build_object(
    'id', v_p.id, 'kind', v_p.kind, 'title', v_p.title, 'status', v_p.status,
    'max_choices', v_p.max_choices, 'rating_scale', v_p.rating_scale, 'results_visibility', v_p.results_visibility,
    'options', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'label', o.label) order by o.position, o.created_at)
                         from poll.poll_options o where o.poll_id = v_p.id), '[]'::jsonb),
    'results', case when v_show then poll.build_poll_result(v_p.id) end
  );
end;
$$;

-- 행사 공개 상태(브로드캐스트와 참가자/오버레이 스냅샷 공용). ended 는 제목과 상태만(공유 설정 시 마지막 결과)
create or replace function poll.build_public_state(p_event_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_e poll.events; v_qna boolean; v_count integer;
begin
  select * into v_e from poll.events where id = p_event_id and deleted_at is null;
  if not found then return null; end if;
  v_qna := coalesce((v_e.settings ->> 'qna_enabled')::boolean, true);
  select count(*) into v_count from poll.participants pa where pa.event_id = v_e.id;
  if v_e.status <> 'live' then
    return jsonb_build_object(
      'event', jsonb_build_object('id', v_e.id, 'title', v_e.title, 'status', v_e.status, 'state_version', v_e.state_version),
      'poll', case when v_e.status = 'ended' and coalesce((v_e.settings ->> 'share_results_after_end')::boolean, false)
                   then poll.build_public_poll(v_e.current_poll_id) end,
      'qna', null);
  end if;
  return jsonb_build_object(
    'event', jsonb_build_object('id', v_e.id, 'title', v_e.title, 'status', v_e.status, 'join_locked', v_e.join_locked,
                                'participant_count', v_count, 'qna_enabled', v_qna, 'state_version', v_e.state_version),
    'poll', poll.build_public_poll(v_e.current_poll_id),
    'qna', case when v_qna then coalesce((
      select jsonb_agg(to_jsonb(x) order by x.upvotes desc, x.created_at asc) from (
        select q.id, q.body, case when q.show_nickname then pa.nickname end as nickname, q.status, q.created_at,
               (select count(*) from poll.qna_upvotes u where u.question_id = q.id) as upvotes
        from poll.qna_questions q
        join poll.participants pa on pa.id = q.participant_id
        where q.event_id = v_e.id and q.status in ('visible', 'answered')
        order by upvotes desc, q.created_at asc
        limit 30
      ) x), '[]'::jsonb) end
  );
end;
$$;

-- 행사 종료 내부 처리: 열린 문항 확정 → ended
create or replace function poll.end_event_internal(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_poll uuid; v_e poll.events;
begin
  select * into v_e from poll.events where id = p_event_id for update;
  if not found or v_e.status <> 'live' then return; end if;
  for v_poll in select id from poll.polls where event_id = p_event_id and status = 'open' loop
    update poll.polls set status = 'closed', closed_at = now() where id = v_poll;
    perform poll.finalize_poll(v_poll);
  end loop;
  update poll.events
     set status = 'ended', ended_at = now(),
         retention_until = now() + make_interval(days => greatest(poll.plan_feature_int(v_e.org_id, 'retention_days', 30), 1))
   where id = p_event_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 12. 진행자 RPC (authenticated, SECURITY DEFINER)
--     호출자 판정: core.is_service_caller() + core.has_org_role(...)  (SECURITY_BASELINE 1, 2장)
-- ---------------------------------------------------------------------
create or replace function poll.create_event(p_org_id uuid, p_title text, p_description text default '', p_settings jsonb default '{}'::jsonb)
returns poll.events
language plpgsql
security definer
set search_path = ''
as $$
declare v_row poll.events; v_limit integer; v_count integer; v_rl record;
begin
  if not core.is_service_caller() and not core.has_org_role(p_org_id, array['owner', 'admin', 'member']) then
    raise exception 'create_event: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(p_org_id, 'poll') then
    raise exception 'create_event: no entitlement' using errcode = '42501';
  end if;
  select * into v_rl from core.rate_limit_hit('poll:create_event:' || p_org_id::text, 30, 3600);
  if not v_rl.allowed then
    raise exception 'create_event: rate limited' using errcode = 'PL429';
  end if;
  v_limit := poll.plan_feature_int(p_org_id, 'max_events', 50);
  select count(*) into v_count from poll.events e
   where e.org_id = p_org_id and e.status <> 'archived' and e.deleted_at is null;
  if v_limit >= 0 and v_count >= v_limit then
    raise exception 'create_event: plan limit % events', v_limit using errcode = 'PL012';
  end if;
  insert into poll.events (org_id, code, title, description, settings, created_by)
  values (p_org_id, poll.new_event_code(), poll.clean_text(p_title), poll.clean_text(coalesce(p_description, '')),
          coalesce(p_settings, '{}'::jsonb), auth.uid())
  returning * into v_row;
  perform core.write_audit(p_org_id, 'event.create', 'poll_event', v_row.id::text);
  return v_row;
end;
$$;

-- 상태 전이: draft→live, draft→archived, live→ended, ended→live(종료 24시간 이내), ended→archived
create or replace function poll.transition_event(p_event_id uuid, p_to text)
returns poll.events
language plpgsql
security definer
set search_path = ''
as $$
declare v_row poll.events; v_limit integer; v_live integer;
begin
  select * into v_row from poll.events where id = p_event_id and deleted_at is null for update;
  if not found then
    raise exception 'transition_event: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'transition_event: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_row.org_id, 'poll') then
    raise exception 'transition_event: no entitlement' using errcode = '42501';
  end if;
  if not ((v_row.status, p_to) in (('draft', 'live'), ('draft', 'archived'), ('live', 'ended'), ('ended', 'live'), ('ended', 'archived'))) then
    raise exception 'transition_event: % -> % not allowed', v_row.status, p_to using errcode = 'PL011';
  end if;
  if p_to = 'live' then
    if v_row.status = 'ended' and (v_row.ended_at < now() - interval '24 hours' or v_row.purged_at is not null) then
      raise exception 'transition_event: reopen window passed' using errcode = 'PL011';
    end if;
    v_limit := poll.plan_feature_int(v_row.org_id, 'max_live_events', 1);
    select count(*) into v_live from poll.events e
     where e.org_id = v_row.org_id and e.status = 'live' and e.deleted_at is null and e.id <> v_row.id;
    if v_limit >= 0 and v_live >= v_limit then
      raise exception 'transition_event: plan limit % live events', v_limit using errcode = 'PL012';
    end if;
    update poll.events
       set status = 'live', started_at = coalesce(started_at, now()), ended_at = null, retention_until = null,
           max_participants = greatest(poll.plan_feature_int(v_row.org_id, 'max_participants', 100), 1)
     where id = p_event_id returning * into v_row;
  elsif p_to = 'ended' then
    perform poll.end_event_internal(p_event_id);
    select * into v_row from poll.events where id = p_event_id;
  else
    update poll.events set status = 'archived', archived_at = now() where id = p_event_id returning * into v_row;
  end if;
  perform core.write_audit(v_row.org_id, 'event.' || p_to, 'poll_event', p_event_id::text);
  return v_row;
end;
$$;

-- 발표 화면의 현재 문항 지정(null 이면 대기 화면)
create or replace function poll.set_current_poll(p_event_id uuid, p_poll_id uuid)
returns poll.events
language plpgsql
security definer
set search_path = ''
as $$
declare v_row poll.events;
begin
  select * into v_row from poll.events where id = p_event_id and deleted_at is null for update;
  if not found then
    raise exception 'set_current_poll: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_row.org_id, array['owner', 'admin', 'member']) then
    raise exception 'set_current_poll: not a member' using errcode = '42501';
  end if;
  if v_row.status not in ('draft', 'live') then
    raise exception 'set_current_poll: event is %', v_row.status using errcode = 'PL011';
  end if;
  if p_poll_id is not null and not exists (select 1 from poll.polls p where p.id = p_poll_id and p.event_id = p_event_id) then
    raise exception 'set_current_poll: poll not in event' using errcode = '22023';
  end if;
  update poll.events set current_poll_id = p_poll_id where id = p_event_id returning * into v_row;
  return v_row;
end;
$$;

-- 문항 전이: draft→open, open→closed, closed→open. 열면 같은 행사의 다른 열린 문항을 닫고 현재 문항으로 지정
create or replace function poll.transition_poll(p_poll_id uuid, p_to text)
returns poll.polls
language plpgsql
security definer
set search_path = ''
as $$
declare v_p poll.polls; v_e poll.events; v_opts integer; v_other uuid; v_limit integer;
begin
  select * into v_p from poll.polls where id = p_poll_id for update;
  if not found then
    raise exception 'transition_poll: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_p.org_id, array['owner', 'admin', 'member']) then
    raise exception 'transition_poll: not a member' using errcode = '42501';
  end if;
  if not core.has_entitlement(v_p.org_id, 'poll') then
    raise exception 'transition_poll: no entitlement' using errcode = '42501';
  end if;
  select * into v_e from poll.events where id = v_p.event_id for update;
  if not ((v_p.status, p_to) in (('draft', 'open'), ('open', 'closed'), ('closed', 'open'))) then
    raise exception 'transition_poll: % -> % not allowed', v_p.status, p_to using errcode = 'PL011';
  end if;
  if p_to = 'open' then
    if v_e.status <> 'live' or v_e.deleted_at is not null then
      raise exception 'transition_poll: event is not live' using errcode = 'PL002';
    end if;
    if v_p.kind in ('single_choice', 'multiple_choice') then
      select count(*) into v_opts from poll.poll_options o where o.poll_id = v_p.id;
      if v_opts < 2 or v_opts > 10 then
        raise exception 'transition_poll: options must be 2..10 (got %)', v_opts using errcode = 'PL007';
      end if;
      if v_p.kind = 'multiple_choice' and v_p.max_choices > v_opts then
        raise exception 'transition_poll: max_choices exceeds options' using errcode = 'PL007';
      end if;
    end if;
    if v_p.status = 'draft' then
      v_limit := poll.plan_feature_int(v_p.org_id, 'polls_per_event', 50);
      if v_limit >= 0 and (select count(*) from poll.polls p where p.event_id = v_p.event_id and p.status <> 'draft') >= v_limit then
        raise exception 'transition_poll: plan limit % polls per event', v_limit using errcode = 'PL012';
      end if;
    end if;
    for v_other in select id from poll.polls where event_id = v_p.event_id and status = 'open' and id <> v_p.id loop
      update poll.polls set status = 'closed', closed_at = now() where id = v_other;
      perform poll.finalize_poll(v_other);
    end loop;
    update poll.polls set status = 'open', opened_at = now(), closed_at = null where id = p_poll_id returning * into v_p;
    update poll.events set current_poll_id = p_poll_id, state_version = state_version + 1 where id = v_p.event_id;
  else
    update poll.polls set status = 'closed', closed_at = now() where id = p_poll_id returning * into v_p;
    perform poll.finalize_poll(p_poll_id);
    update poll.events set state_version = state_version + 1 where id = v_p.event_id;
  end if;
  perform core.write_audit(v_p.org_id, 'poll_item.' || p_to, 'poll_item', p_poll_id::text);
  return v_p;
end;
$$;

-- Q&A 모더레이션
create or replace function poll.moderate_question(p_question_id uuid, p_to text)
returns poll.qna_questions
language plpgsql
security definer
set search_path = ''
as $$
declare v_q poll.qna_questions;
begin
  select * into v_q from poll.qna_questions where id = p_question_id for update;
  if not found then
    raise exception 'moderate_question: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_q.org_id, array['owner', 'admin', 'member']) then
    raise exception 'moderate_question: not a member' using errcode = '42501';
  end if;
  if p_to not in ('visible', 'answered', 'hidden', 'rejected') then
    raise exception 'moderate_question: invalid target %', p_to using errcode = '22023';
  end if;
  update poll.qna_questions
     set status = p_to,
         hidden_reason = case when p_to = 'hidden' then 'host' when p_to = 'visible' then null else hidden_reason end,
         moderated_by = auth.uid(), moderated_at = now()
   where id = p_question_id returning * into v_q;
  perform core.write_audit(v_q.org_id, 'question.' || p_to, 'poll_question', p_question_id::text);
  return v_q;
end;
$$;

-- 참가자 차단/해제. 차단하면 그 참가자의 질문을 숨긴다(투표는 집계에 남는다)
create or replace function poll.block_participant(p_participant_id uuid, p_blocked boolean default true)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_pa poll.participants;
begin
  select * into v_pa from poll.participants where id = p_participant_id for update;
  if not found then
    raise exception 'block_participant: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_pa.org_id, array['owner', 'admin', 'member']) then
    raise exception 'block_participant: not a member' using errcode = '42501';
  end if;
  update poll.participants set is_blocked = coalesce(p_blocked, true) where id = p_participant_id;
  if coalesce(p_blocked, true) then
    update poll.qna_questions set status = 'hidden', hidden_reason = 'blocked_participant', moderated_by = auth.uid(), moderated_at = now()
     where participant_id = p_participant_id and status in ('pending', 'visible', 'answered');
  end if;
  perform core.write_audit(v_pa.org_id, case when coalesce(p_blocked, true) then 'participant.block' else 'participant.unblock' end,
                           'poll_participant', p_participant_id::text);
end;
$$;

-- 오버레이 키 재발급. 원문은 이 반환값으로 한 번만 보여 준다
create or replace function poll.rotate_overlay_key(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_e poll.events; v_key text;
begin
  select * into v_e from poll.events where id = p_event_id and deleted_at is null for update;
  if not found then
    raise exception 'rotate_overlay_key: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_e.org_id, array['owner', 'admin', 'member']) then
    raise exception 'rotate_overlay_key: not a member' using errcode = '42501';
  end if;
  v_key := encode(extensions.gen_random_bytes(24), 'hex');
  update poll.events set overlay_key_hash = poll.token_hash(v_key) where id = p_event_id;
  perform core.write_audit(v_e.org_id, 'event.overlay_key_rotate', 'poll_event', p_event_id::text);
  return v_key;
end;
$$;

-- 입장 비밀번호 설정/해제(4~12자). 저장은 sha256(event_id:passcode)
create or replace function poll.set_event_passcode(p_event_id uuid, p_passcode text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_e poll.events;
begin
  select * into v_e from poll.events where id = p_event_id and deleted_at is null for update;
  if not found then
    raise exception 'set_event_passcode: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_e.org_id, array['owner', 'admin']) then
    raise exception 'set_event_passcode: owner/admin only' using errcode = '42501';
  end if;
  if p_passcode is not null and char_length(p_passcode) not between 4 and 12 then
    raise exception 'set_event_passcode: length 4..12' using errcode = '22023';
  end if;
  update poll.events
     set passcode_hash = case when p_passcode is null then null else poll.token_hash(p_event_id::text || ':' || p_passcode) end
   where id = p_event_id;
  perform core.write_audit(v_e.org_id, 'event.passcode_set', 'poll_event', p_event_id::text);
end;
$$;

-- 행사 삭제(소프트). live 면 먼저 종료. 7일 뒤 purge_expired_events 가 물리 삭제
create or replace function poll.delete_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_e poll.events;
begin
  select * into v_e from poll.events where id = p_event_id and deleted_at is null for update;
  if not found then
    raise exception 'delete_event: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not core.has_org_role(v_e.org_id, array['owner', 'admin']) then
    raise exception 'delete_event: owner/admin only' using errcode = '42501';
  end if;
  if v_e.status = 'live' then
    perform poll.end_event_internal(p_event_id);
  end if;
  update poll.events set deleted_at = now() where id = p_event_id;
  perform core.write_audit(v_e.org_id, 'event.delete', 'poll_event', p_event_id::text);
end;
$$;

-- 진행자 화면 실시간 집계(결과 공개 설정과 무관하게 진행자는 항상 본다)
create or replace function poll.host_poll_results(p_poll_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_org uuid;
begin
  select org_id into v_org from poll.polls where id = p_poll_id;
  if v_org is null then
    raise exception 'host_poll_results: not found' using errcode = 'P0002';
  end if;
  if not core.is_service_caller() and not (core.is_org_member(v_org) and core.has_entitlement(v_org, 'poll')) then
    raise exception 'host_poll_results: not a member' using errcode = '42501';
  end if;
  return poll.build_poll_result(p_poll_id);
end;
$$;

-- ---------------------------------------------------------------------
-- 13. 청중 RPC (service_role 전용. Route Handler 가 쿠키의 참가자 토큰과 ip_hash 를 넘긴다)
--     업무 오류는 {ok:false, code} 로 반환한다(레이트 리밋 히트 보존). 인자 형식 오류만 raise.
-- ---------------------------------------------------------------------
create or replace function poll.join_event(p_code text, p_token text, p_nickname text default null,
                                           p_ip_hash text default null, p_passcode text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash text; v_pa poll.participants; v_e poll.events; v_nick text; v_count integer; v_rl record; v_fail_key text;
begin
  if not core.is_privileged_session() then
    raise exception 'join_event: service_role only' using errcode = '42501';
  end if;
  if p_token is null or char_length(p_token) not between 32 and 128 then
    raise exception 'join_event: bad token' using errcode = '22023';
  end if;
  v_hash := poll.token_hash(p_token);
  v_fail_key := 'poll:join_fail:' || coalesce(nullif(p_ip_hash, ''), 'noip');

  -- 대입 차단: 실패가 10분 30회를 넘은 ip_hash 는 조회 자체를 하지 않는다(코어 버킷 읽기만)
  if exists (select 1 from core.rate_limit_buckets b
             where b.key = v_fail_key and b.window_start > now() - interval '10 minutes' and b.count >= 30) then
    return jsonb_build_object('ok', false, 'code', 'PL429');
  end if;

  select * into v_e from poll.events e
   where e.code = p_code and e.status <> 'archived' and e.deleted_at is null;
  if not found then
    select * into v_rl from core.rate_limit_hit(v_fail_key, 30, 600);
    return jsonb_build_object('ok', false, 'code', case when v_rl.allowed then 'PL001' else 'PL429' end);
  end if;
  if v_e.status <> 'live' then
    return jsonb_build_object('ok', false, 'code', 'PL002', 'event_status', v_e.status, 'title', v_e.title);
  end if;

  -- 같은 기기 재입장(쿠키 토큰 동일)은 기존 참가자를 돌려준다
  select * into v_pa from poll.participants where token_hash = v_hash;
  if found then
    if v_pa.event_id <> v_e.id then
      raise exception 'join_event: token belongs to another event' using errcode = '22023';
    end if;
    if v_pa.is_blocked then
      return jsonb_build_object('ok', false, 'code', 'PL009');
    end if;
    update poll.participants set last_seen_at = now() where id = v_pa.id;
    return jsonb_build_object('ok', true, 'rejoined', true, 'participant_id', v_pa.id, 'event_id', v_e.id,
                              'org_id', v_e.org_id, 'topic', 'poll:' || v_e.org_id::text || ':' || v_e.id::text);
  end if;

  if v_e.passcode_hash is not null
     and v_e.passcode_hash is distinct from poll.token_hash(v_e.id::text || ':' || coalesce(p_passcode, '')) then
    select * into v_rl from core.rate_limit_hit(v_fail_key, 30, 600);
    return jsonb_build_object('ok', false, 'code', case when v_rl.allowed then 'PL013' else 'PL429' end);
  end if;
  if v_e.join_locked then
    return jsonb_build_object('ok', false, 'code', 'PL003');
  end if;
  select count(*) into v_count from poll.participants pa where pa.event_id = v_e.id;
  if v_count >= v_e.max_participants then
    return jsonb_build_object('ok', false, 'code', 'PL004');
  end if;

  v_nick := nullif(poll.clean_text(p_nickname), '');
  if v_nick is not null then
    if char_length(v_nick) > 30 then
      return jsonb_build_object('ok', false, 'code', 'PL007', 'field', 'nickname');
    end if;
    if poll.contains_banned_word(v_e.org_id, v_nick) then
      return jsonb_build_object('ok', false, 'code', 'PL008');
    end if;
  elsif not coalesce((v_e.settings ->> 'allow_anonymous')::boolean, true) then
    return jsonb_build_object('ok', false, 'code', 'PL007', 'field', 'nickname');
  end if;

  insert into poll.participants (org_id, event_id, token_hash, nickname)
  values (v_e.org_id, v_e.id, v_hash, v_nick)
  returning * into v_pa;
  return jsonb_build_object('ok', true, 'rejoined', false, 'participant_id', v_pa.id, 'event_id', v_e.id,
                            'org_id', v_e.org_id, 'topic', 'poll:' || v_e.org_id::text || ':' || v_e.id::text);
end;
$$;

-- 참가자 토큰 → 참가자 + 행사 (내부)
create or replace function poll.resolve_participant(p_token text)
returns poll.participants
language sql
stable
security definer
set search_path = ''
as $$
  select pa.* from poll.participants pa where pa.token_hash = poll.token_hash(p_token);
$$;

create or replace function poll.cast_vote(p_token text, p_poll_id uuid, p_option_ids uuid[] default '{}', p_rating integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_pa poll.participants; v_p poll.polls; v_e poll.events; v_opts uuid[]; v_valid integer; v_id bigint; v_rl record;
begin
  if not core.is_privileged_session() then
    raise exception 'cast_vote: service_role only' using errcode = '42501';
  end if;
  v_pa := poll.resolve_participant(p_token);
  if v_pa.id is null or v_pa.is_blocked then
    return jsonb_build_object('ok', false, 'code', 'PL009');
  end if;
  select * into v_rl from core.rate_limit_hit('poll:vote:' || v_pa.id::text, 20, 60);
  if not v_rl.allowed then
    return jsonb_build_object('ok', false, 'code', 'PL429');
  end if;
  -- 다른 행사의 문항은 존재 여부도 알려 주지 않는다(같은 PL006)
  select * into v_p from poll.polls where id = p_poll_id and event_id = v_pa.event_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'PL006');
  end if;
  select * into v_e from poll.events where id = v_pa.event_id;
  if v_e.status <> 'live' or v_e.deleted_at is not null then
    return jsonb_build_object('ok', false, 'code', 'PL002');
  end if;
  if v_p.status <> 'open' then
    return jsonb_build_object('ok', false, 'code', 'PL006');
  end if;

  v_opts := coalesce((select array_agg(distinct x) from unnest(coalesce(p_option_ids, '{}'::uuid[])) as x where x is not null), '{}'::uuid[]);
  if v_p.kind = 'rating' then
    if cardinality(v_opts) > 0 or p_rating is null or p_rating < 1 or p_rating > v_p.rating_scale then
      return jsonb_build_object('ok', false, 'code', 'PL007');
    end if;
  else
    if p_rating is not null or cardinality(v_opts) < 1
       or (v_p.kind = 'single_choice' and cardinality(v_opts) <> 1)
       or (v_p.kind = 'multiple_choice' and cardinality(v_opts) > v_p.max_choices) then
      return jsonb_build_object('ok', false, 'code', 'PL007');
    end if;
    select count(*) into v_valid from poll.poll_options o where o.poll_id = v_p.id and o.id = any (v_opts);
    if v_valid <> cardinality(v_opts) then
      return jsonb_build_object('ok', false, 'code', 'PL007');
    end if;
  end if;

  insert into poll.votes (org_id, event_id, poll_id, participant_id, option_ids, rating)
  values (v_p.org_id, v_p.event_id, v_p.id, v_pa.id, v_opts, case when v_p.kind = 'rating' then p_rating end)
  on conflict (poll_id, participant_id) do nothing
  returning id into v_id;
  if v_id is null then
    return jsonb_build_object('ok', false, 'code', 'PL005');
  end if;
  return jsonb_build_object('ok', true, 'vote_id', v_id);
end;
$$;

create or replace function poll.ask_question(p_token text, p_body text, p_show_nickname boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_pa poll.participants; v_e poll.events; v_body text; v_status text; v_reason text; v_rl record; v_q poll.qna_questions;
begin
  if not core.is_privileged_session() then
    raise exception 'ask_question: service_role only' using errcode = '42501';
  end if;
  v_pa := poll.resolve_participant(p_token);
  if v_pa.id is null or v_pa.is_blocked then
    return jsonb_build_object('ok', false, 'code', 'PL009');
  end if;
  select * into v_e from poll.events where id = v_pa.event_id;
  if v_e.status <> 'live' or v_e.deleted_at is not null then
    return jsonb_build_object('ok', false, 'code', 'PL002');
  end if;
  if not coalesce((v_e.settings ->> 'qna_enabled')::boolean, true) then
    return jsonb_build_object('ok', false, 'code', 'PL010');
  end if;
  select * into v_rl from core.rate_limit_hit('poll:ask:' || v_pa.id::text, 3, 60);
  if not v_rl.allowed then
    return jsonb_build_object('ok', false, 'code', 'PL429');
  end if;
  if (select count(*) from poll.qna_questions q where q.participant_id = v_pa.id) >= 20 then
    return jsonb_build_object('ok', false, 'code', 'PL429', 'scope', 'event');
  end if;
  v_body := poll.clean_text(p_body);
  if char_length(v_body) < 1 or char_length(v_body) > 300 then
    return jsonb_build_object('ok', false, 'code', 'PL007', 'field', 'body');
  end if;
  if poll.contains_banned_word(v_e.org_id, v_body) then
    v_status := 'hidden'; v_reason := 'banned_word';
  elsif coalesce((v_e.settings ->> 'qna_moderation')::boolean, false) then
    v_status := 'pending';
  else
    v_status := 'visible';
  end if;
  insert into poll.qna_questions (org_id, event_id, participant_id, body, show_nickname, status, hidden_reason)
  values (v_e.org_id, v_e.id, v_pa.id, v_body, coalesce(p_show_nickname, true), v_status, v_reason)
  returning * into v_q;
  -- 금칙어로 숨긴 질문도 작성자에게는 "검토 중"으로 보인다(우회 시도 유도 방지)
  return jsonb_build_object('ok', true, 'question_id', v_q.id,
                            'status', case when v_status = 'hidden' then 'pending' else v_status end);
end;
$$;

create or replace function poll.upvote_question(p_token text, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_pa poll.participants; v_q poll.qna_questions; v_id bigint; v_rl record;
begin
  if not core.is_privileged_session() then
    raise exception 'upvote_question: service_role only' using errcode = '42501';
  end if;
  v_pa := poll.resolve_participant(p_token);
  if v_pa.id is null or v_pa.is_blocked then
    return jsonb_build_object('ok', false, 'code', 'PL009');
  end if;
  select * into v_rl from core.rate_limit_hit('poll:upvote:' || v_pa.id::text, 60, 60);
  if not v_rl.allowed then
    return jsonb_build_object('ok', false, 'code', 'PL429');
  end if;
  select * into v_q from poll.qna_questions
   where id = p_question_id and event_id = v_pa.event_id and status in ('visible', 'answered');
  if not found then
    return jsonb_build_object('ok', false, 'code', 'PL006');
  end if;
  if not exists (select 1 from poll.events e where e.id = v_pa.event_id and e.status = 'live' and e.deleted_at is null) then
    return jsonb_build_object('ok', false, 'code', 'PL002');
  end if;
  insert into poll.qna_upvotes (org_id, event_id, question_id, participant_id)
  values (v_q.org_id, v_q.event_id, v_q.id, v_pa.id)
  on conflict (question_id, participant_id) do nothing
  returning id into v_id;
  return jsonb_build_object('ok', true, 'already', v_id is null);
end;
$$;

-- 참가자 스냅샷: 입장 직후, 재연결 직후, seq 공백 감지 시 1회 호출(폴링 아님)
create or replace function poll.participant_snapshot(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_pa poll.participants; v_e poll.events; v_state jsonb; v_rl record;
begin
  if not core.is_privileged_session() then
    raise exception 'participant_snapshot: service_role only' using errcode = '42501';
  end if;
  v_pa := poll.resolve_participant(p_token);
  if v_pa.id is null then
    return jsonb_build_object('ok', false, 'code', 'PL009');
  end if;
  select * into v_rl from core.rate_limit_hit('poll:snapshot:' || v_pa.id::text, 30, 60);
  if not v_rl.allowed then
    return jsonb_build_object('ok', false, 'code', 'PL429');
  end if;
  select * into v_e from poll.events where id = v_pa.event_id;
  if v_e.deleted_at is not null or v_e.status = 'archived' then
    return jsonb_build_object('ok', false, 'code', 'PL002');
  end if;
  update poll.participants set last_seen_at = now() where id = v_pa.id;
  v_state := poll.build_public_state(v_e.id);
  if v_e.status <> 'live' then
    return jsonb_build_object('ok', true, 'seq', v_e.broadcast_seq, 'state', v_state, 'blocked', v_pa.is_blocked);
  end if;
  return jsonb_build_object(
    'ok', true, 'seq', v_e.broadcast_seq, 'state', v_state, 'blocked', v_pa.is_blocked,
    'topic', 'poll:' || v_e.org_id::text || ':' || v_e.id::text,
    'me', jsonb_build_object(
      'participant_id', v_pa.id, 'nickname', v_pa.nickname,
      'vote', (select jsonb_build_object('poll_id', v.poll_id, 'option_ids', to_jsonb(v.option_ids), 'rating', v.rating)
                 from poll.votes v where v.participant_id = v_pa.id and v.poll_id = v_e.current_poll_id),
      'questions', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'body', q.body,
                                    'status', case when q.status = 'hidden' and q.hidden_reason = 'banned_word' then 'pending' else q.status end)
                                    order by q.created_at desc)
                               from poll.qna_questions q where q.participant_id = v_pa.id), '[]'::jsonb),
      'upvoted', coalesce((select jsonb_agg(u.question_id) from poll.qna_upvotes u where u.participant_id = v_pa.id), '[]'::jsonb)
    )
  );
end;
$$;

-- OBS 오버레이 스냅샷: 오버레이 키(원문)를 서버가 넘긴다
create or replace function poll.overlay_snapshot(p_event_id uuid, p_overlay_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_e poll.events;
begin
  if not core.is_privileged_session() then
    raise exception 'overlay_snapshot: service_role only' using errcode = '42501';
  end if;
  select * into v_e from poll.events where id = p_event_id and deleted_at is null and status in ('live', 'ended');
  if not found or v_e.overlay_key_hash is null or v_e.overlay_key_hash <> poll.token_hash(p_overlay_key) then
    return jsonb_build_object('ok', false, 'code', 'PL009');
  end if;
  return jsonb_build_object('ok', true, 'seq', v_e.broadcast_seq, 'state', poll.build_public_state(v_e.id),
                            'topic', 'poll:' || v_e.org_id::text || ':' || v_e.id::text);
end;
$$;

-- ---------------------------------------------------------------------
-- 14. 브로드캐스터 워커 RPC (service_role 전용)
--     워커가 250ms~1s 간격으로 호출한다. 바뀐 행사만 공개 상태를 만들고, 바뀌지 않은 live 행사는
--     p_heartbeat_seconds 마다 hb 메시지를 만든다. 반환 행을 Realtime Broadcast(private 채널)로 보낸다.
--     seq 는 행사별 단조 증가. 클라이언트는 seq 공백을 감지하면 스냅샷을 1회 다시 받는다.
-- ---------------------------------------------------------------------
create or replace function poll.collect_broadcasts(p_limit integer default 200, p_heartbeat_seconds integer default 5)
returns table (event_id uuid, topic text, payload jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  r poll.events; v_vote_seq bigint; v_qna_seq bigint; v_count integer; v_dirty boolean; v_seq bigint;
begin
  if not core.is_privileged_session() then
    raise exception 'collect_broadcasts: service_role only' using errcode = '42501';
  end if;
  for r in
    select e.* from poll.events e
    where e.deleted_at is null
      and (e.status = 'live' or e.state_version > e.broadcast_state_version)
    order by e.broadcast_at nulls first
    limit greatest(coalesce(p_limit, 200), 1)
    for update skip locked
  loop
    v_vote_seq := 0;
    if r.current_poll_id is not null then
      select coalesce(max(v.id), 0) into v_vote_seq from poll.votes v where v.poll_id = r.current_poll_id;
    end if;
    v_qna_seq := greatest(
      coalesce((select max(q.change_seq) from poll.qna_questions q where q.event_id = r.id), 0),
      coalesce((select max(u.change_seq) from poll.qna_upvotes u where u.event_id = r.id), 0));
    select count(*) into v_count from poll.participants pa where pa.event_id = r.id;
    v_dirty := r.state_version > r.broadcast_state_version or v_vote_seq <> r.broadcast_vote_seq
               or v_qna_seq <> r.broadcast_qna_seq or v_count <> r.broadcast_participant_count;
    if v_dirty or r.broadcast_at is null
       or r.broadcast_at < now() - make_interval(secs => greatest(coalesce(p_heartbeat_seconds, 5), 1)) then
      v_seq := r.broadcast_seq + 1;
      update poll.events e
         set broadcast_state_version = r.state_version, broadcast_vote_seq = v_vote_seq, broadcast_qna_seq = v_qna_seq,
             broadcast_participant_count = v_count, broadcast_seq = v_seq, broadcast_at = now()
       where e.id = r.id;
      event_id := r.id;
      topic := 'poll:' || r.org_id::text || ':' || r.id::text;
      if v_dirty then
        payload := jsonb_build_object('type', 'state', 'seq', v_seq, 'state', poll.build_public_state(r.id));
      else
        payload := jsonb_build_object('type', 'hb', 'seq', v_seq, 'event_id', r.id);
      end if;
      return next;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 15. 보존/정리 (service_role, 매시간)
--   1) 24시간 넘게 live 인 행사 자동 종료  2) 종료 7일 뒤 archived(코드 반납)
--   3) retention_until 이 지난 행사의 참가자/투표/질문 삭제(poll_results 는 남김)
--   4) 소프트 삭제 7일 뒤 물리 삭제
-- ---------------------------------------------------------------------
create or replace function poll.purge_expired_events()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid; v_ended integer := 0; v_archived integer := 0; v_purged integer := 0; v_deleted integer := 0;
begin
  if not core.is_privileged_session() then
    raise exception 'purge_expired_events: service_role only' using errcode = '42501';
  end if;
  for v_id in select id from poll.events where status = 'live' and deleted_at is null
                and started_at < now() - interval '24 hours' loop
    perform poll.end_event_internal(v_id);
    v_ended := v_ended + 1;
  end loop;
  update poll.events set status = 'archived', archived_at = now()
   where status = 'ended' and deleted_at is null and ended_at < now() - interval '7 days';
  get diagnostics v_archived = row_count;
  for v_id in select id from poll.events where status in ('ended', 'archived') and purged_at is null
                and retention_until is not null and retention_until < now() loop
    delete from poll.participants where event_id = v_id;
    update poll.events set purged_at = now() where id = v_id;
    v_purged := v_purged + 1;
  end loop;
  delete from poll.events where deleted_at is not null and deleted_at < now() - interval '7 days';
  get diagnostics v_deleted = row_count;
  return jsonb_build_object('ended', v_ended, 'archived', v_archived, 'purged', v_purged, 'deleted', v_deleted);
end;
$$;

-- ---------------------------------------------------------------------
-- 16. 함수 EXECUTE 정리
-- ---------------------------------------------------------------------
do $$
declare r record;
begin
  -- 모놀리스(public)에서도 코어 함수 권한을 건드리지 않도록 이 파일이 만든 함수 이름만 대상으로 한다
  for r in select p.oid::regprocedure as sig from pg_proc p
           where p.pronamespace = (select c.relnamespace from pg_class c where c.oid = 'poll.events'::regclass)
             and p.prokind = 'f'
             and p.proname = any (array[
               'normalize_text', 'clean_text', 'events_before_update', 'polls_before_write', 'qna_questions_before_update',
               'plan_feature_int', 'contains_banned_word', 'new_event_code', 'token_hash', 'build_poll_result', 'finalize_poll',
               'build_public_poll', 'build_public_state', 'end_event_internal', 'create_event', 'transition_event',
               'set_current_poll', 'transition_poll', 'moderate_question', 'block_participant', 'rotate_overlay_key',
               'set_event_passcode', 'delete_event', 'host_poll_results', 'join_event', 'resolve_participant', 'cast_vote',
               'ask_question', 'upvote_question', 'participant_snapshot', 'overlay_snapshot', 'collect_broadcasts',
               'purge_expired_events'])
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    execute format('grant execute on function %s to service_role', r.sig);
  end loop;
end $$;

-- PostgreSQL 전역 기본값(PUBLIC EXECUTE)은 alter default privileges 로 지워지지 않는다(core 0007과 같은 규칙).
-- 스키마 전체에서 한 번 더 회수하고 아래 허용 목록만 준다. 모놀리스는 위 루프(이름 목록)가 같은 일을 한다.
-- @@modular-only-begin
revoke execute on all functions in schema poll from public, anon, authenticated;
grant execute on all functions in schema poll to service_role;
-- @@modular-only-end

-- banned_words.normalized 생성 컬럼 계산에 필요
grant execute on function poll.normalize_text(text) to authenticated;
-- 진행자 RPC
grant execute on function poll.create_event(uuid, text, text, jsonb) to authenticated;
grant execute on function poll.transition_event(uuid, text) to authenticated;
grant execute on function poll.set_current_poll(uuid, uuid) to authenticated;
grant execute on function poll.transition_poll(uuid, text) to authenticated;
grant execute on function poll.moderate_question(uuid, text) to authenticated;
grant execute on function poll.block_participant(uuid, boolean) to authenticated;
grant execute on function poll.rotate_overlay_key(uuid) to authenticated;
grant execute on function poll.set_event_passcode(uuid, text) to authenticated;
grant execute on function poll.delete_event(uuid) to authenticated;
grant execute on function poll.host_poll_results(uuid) to authenticated;
-- 청중 RPC, 브로드캐스터, 정리 함수는 service_role 만(위 루프에서 부여). anon/authenticated 는 42501.

-- ---------------------------------------------------------------------
-- 17. Realtime Broadcast 권한(private 채널). realtime 스키마가 있는 Supabase 에서만 적용된다.
--   토픽: poll:<org_id>:<event_id> (공개 상태), poll:<org_id>:<event_id>:host (진행자 알림)
--   진행자: 조직 멤버면 수신. 청중/오버레이: 서버가 발급한 단기 JWT(role anon, claim poll_topic)의
--   토픽과 정확히 같을 때만 수신. 송신(INSERT) 정책은 없다. 송신은 service_role(워커)만.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('realtime.messages') is not null then
    execute 'drop policy if exists poll_broadcast_read_member on realtime.messages';
    execute $p$
      create policy poll_broadcast_read_member on realtime.messages for select to authenticated
      using (
        realtime.messages.extension = 'broadcast'
        and split_part((select realtime.topic()), ':', 1) = 'poll'
        and split_part((select realtime.topic()), ':', 2) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and core.is_org_member(split_part((select realtime.topic()), ':', 2)::uuid)
      )$p$;
    execute 'drop policy if exists poll_broadcast_read_audience on realtime.messages';
    execute $p$
      create policy poll_broadcast_read_audience on realtime.messages for select to anon
      using (
        realtime.messages.extension = 'broadcast'
        and (select realtime.topic()) = (select auth.jwt() ->> 'poll_topic')
        and coalesce((select auth.jwt() ->> 'poll_aud'), '') in ('participant', 'overlay')
      )$p$;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 18. 플랫폼 기본 금칙어(최소 목록. 운영 목록은 service_role 이 관리, 01_PRD 6장)
-- ---------------------------------------------------------------------
insert into poll.banned_words (org_id, word)
select null, w from unnest(array['시발', '씨발', '병신', '개새끼', '좆', 'fuck', 'shit']) as w
where not exists (select 1 from poll.banned_words b where b.org_id is null and b.normalized = poll.normalize_text(w));
