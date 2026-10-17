#!/usr/bin/env python3
"""develop_V2 제품별 개발서 생성기.

사용: python -I gen_v2.py            (저장소 루트 기준 경로를 스스로 찾음)
제품 데이터는 아래 PRODUCTS. V1 작업 이름·웨이브는 products/<제품>/06_AGENT_PLAN.md에서 읽는다.
"""
import io
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'develop_V2')
PLAT = 'D:/WorkSpace/platform/docs'

MODS = {  # 번호 순
    'compliance': ('0150', '법정 표기·동의·라벨'),
    'media': ('0250', '미디어 라이브러리'),
    'community': ('0350', '댓글·방명록·신고'),
    'search': ('0450', '한국어 검색'),
    'membership': ('0550', '최종 이용자·구독·후원'),
    'ads': ('0650', '광고'),
    'editorial': ('0750', '콘텐츠 워크플로'),
}
BUILD_MODEL = {'compliance': 'Opus(+Fable 계획 검토)', 'membership': 'Opus(+Fable 계획 검토)'}

# st: 채택 / 부분 채택 / 보류.  role: 기준 구현 / 두 번째 적용 / ''
PRODUCTS = {
    'study-note': dict(
        name='Study Note', app='notes', pfx='NT', stage='1',
        domain=['20261013000002_study_note_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='두 번째 적용(v1.0 출시 조건 검증)', deps=['021', '013', '052'],
                use='약관·개인정보처리방침 페이지와 첫 실행 동의 모달(021), 설정 화면의 동의 API(013 일부), AI 고지문(국외 이전·음성 처리·강의 녹음, 052)',
                rep='자체 동의 저장과 고지문 버전 관리 → `compliance.consents`, `policy_documents`(kind `terms`, `privacy`, `ai_notice`)',
                keep='강의 녹음 시작 전 고지 모달의 흐름(045, 051)과 녹음 원본 처리',
                inj='`profileKind: kr_business`(플랫폼 운영자 표기, 플랫폼 공통 행), `signupConsents: { required: [terms, privacy], optional: [marketing_email, cross_border_ai] }`'),
            'search': dict(st='보류', why='보관함 날짜·키워드 검색(019)은 본인 노트만 대상이라 제품 쿼리로 충분', when='노트가 사용자당 수천 건을 넘거나 공유 노트가 생길 때'),
            'membership': dict(st='보류', why='유료 강좌가 아직 기획에 없음', when='lms 모듈 착수 때 함께'),
            'community': dict(st='보류', why='질문 게시판이 아직 기획에 없음', when='과목별 Q&A를 만들 때'),
        },
        extra='notify(가입·작업 완료 알림), analytics(전환 이벤트)는 기존 공용모듈 로드맵대로.',
        db=[('`notes.*`', '변경 없음(동의를 따로 저장하는 표가 없음). 동의 기록은 `compliance.consents`에 새로 쌓는다')],
        changes=[('021', '축소', '약관·처리방침 본문은 `compliance.policy_documents` seed, 화면은 `ConsentCheckboxes`·`LegalFooter` 사용. 페이지 레이아웃만 제품 작업'),
                 ('013', '연결', '동의 API는 `recordConsent`·`hasConsent` 호출로'),
                 ('052', '축소', 'AI 고지문은 `policy_documents`(kind `ai_notice`) 버전으로 관리, 재동의는 `needsReconsent`')],
        dec=[('V2-NT-1', '플랫폼 공통 정책만 쓸지(조직별 정책 없음)', '공통만(개인 사용자 SaaS)')],
    ),
    'website-floria': dict(
        name='Floria (Botanic Architecture)', app='site', pfx='SI', stage='1',
        domain=['20261013000002_website_floria_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='기준 구현', deps=['023', '022', '038'],
                use='개인정보처리방침·동의 문구·푸터 사업자 정보(023), 콘솔 설정의 처리방침 버전(022), 문의·뉴스레터 폼 동의, 콘솔 AI 설정의 국외 이전 동의(038)',
                rep='`site.sites.privacy_policy_version`, `site.inquiries.consent_version`·`consent_at`, `site.newsletter_subscribers.consent_version`·`consent_at` → `compliance.policy_documents` 버전과 `compliance.consents`(subject `email` 해시), 푸터 사업자 정보 → `legal_profiles`(`kr_business`)',
                keep='문의 접수 RPC와 스팸 점수, 뉴스레터 이중 동의 흐름(017)',
                inj='`profileKind: kr_business`, 방문자 로그인 없음 → 폼 제출 때 `recordConsent({ subject: { kind: "email", hash } })`'),
            'media': dict(st='보류', why='이미지가 빌드 때 들어가는 정적 자산(007 매니페스트 검사)이고 업로드 기능이 없음', when='콘솔에서 시공 사례 사진을 올리게 될 때(editorial과 함께)'),
            'editorial': dict(st='보류', why='시공 사례·소식은 지금 정적 콘텐츠·지식 원고(039)', when='콘솔에서 사례·소식을 직접 게시하게 될 때'),
        },
        extra='notify 보강분(뉴스레터 목록·이중 동의, 017·021)은 notify v1이 나오면 `site.newsletter_subscribers`를 `notify.list_subscriptions`로 옮긴다(이번 V2 범위 밖, 06장 메모만).',
        db=[('`site.sites`', '`privacy_policy_version` 삭제 → `compliance.current_policy`'),
            ('`site.inquiries`', '`consent_version`, `consent_at` 삭제 → `compliance.consents`(purpose `privacy`, evidence: inquiry id)'),
            ('`site.newsletter_subscribers`', '`consent_version`, `consent_at` 삭제 → `compliance.consents`(purpose `marketing_email`). 확인·해지 시각 컬럼은 유지'),
            ('`site.submit_inquiry` 등 RPC', '인자 `p_consent_version`, `p_privacy_policy_version` 대신 서버가 `compliance.current_policy`로 버전을 정하고 기록')],
        changes=[('023', '대체', '처리방침·동의 문구·푸터는 compliance 기준 구현 작업(V2)이 만든다. 제품은 문구 원고와 사업자 정보 seed만'),
                 ('022', '축소', '콘솔 설정에서 처리방침 버전 입력 제거(정책 게시 화면은 compliance 관리 UI)'),
                 ('017', '연결', '구독 확인 시 `recordConsent(marketing_email)`'),
                 ('038', '연결', '국외 이전 동의를 `recordConsent(cross_border_ai)`로')],
        dec=[('V2-SI-1', 'compliance 관리 화면을 콘솔에 넣을지, 플랫폼 운영자만 쓸지', '콘솔에 넣음(단일 사이트 운영자)')],
    ),
    'flora-publishing': dict(
        name='FLORA Publishing', app='publishing', pfx='PB', stage='2',
        domain=['20261013000002_publishing_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['025'],
                use='법무 페이지 5종(약관, 처리방침, 환불, AI 이용 안내 등, 025), 가입 동의, 대기 명단의 마케팅 동의',
                rep='`publishing.waitlist.consent_marketing` → `compliance.consents`(subject `email`), 법무 페이지 본문 → `policy_documents`',
                keep='원고 저작권 안내 문구(제품 원고)',
                inj='`profileKind: kr_ecommerce`(유료 플랜 판매), `signupConsents` 필수 terms·privacy·refund'),
            'media': dict(st='채택', role='기준 구현', deps=['015', '036'],
                use='원고 업로드(서명 URL·완료 검증, 015), 표지 이미지, 탈퇴 시 파일 정리(036)',
                rep='`publishing.manuscript_uploads`의 저장 경로·용량·MIME·해시 → `media.assets`(kind `file`), `publishing.cover_images` → `media.assets`(kind `image`) + 프리셋 `cover_1600x2560`(제품 추가)',
                keep='원고 파싱 잡(업로드 완료 이벤트 `media.asset.ready` 구독), 인쇄용 산출물 `book_exports`(PDF·ePub), 책별 RAG 참고 파일(045, 코어 AI)',
                inj='`presets: { cover_1600x2560 }`, `allowedMime`(docx, hwp, txt, md, pdf, 이미지), `maxUploadMb: 50`(제안), 표지 `requireAlt: true`'),
            'editorial': dict(st='보류', why='원고는 웹에 게시하지 않고 인쇄·전자책으로 내보냄. 장·절 버전은 제품 구조(chapters, sections)', when='작가 블로그·연재 게시 기능을 만들 때'),
            'community': dict(st='보류', why='독자 리뷰 기능이 기획에 없음', when='작가 독자 페이지를 만들 때'),
            'membership': dict(st='보류', why='작가 유료 멤버십은 확장 아이디어 단계', when='멤버십 확장 착수 때(`COMMON_MODULES_ROADMAP.md` 4.7절 lms와 함께)'),
        },
        extra='notify(작업 완료·결제), analytics, cms(랜딩)는 기존 공용모듈 로드맵 Phase 1 그대로.',
        db=[('`publishing.manuscript_uploads`', '파일 메타 컬럼 삭제, `asset_id`(→ `media.assets`)와 파싱 상태만 남김'),
            ('`publishing.cover_images`', '표 삭제 → `books.cover_asset_id`(→ `media.assets`)'),
            ('`publishing.waitlist`', '`consent_marketing` 삭제 → `compliance.consents`')],
        changes=[('015', '축소', '서명 URL·완료 검증·중복 검사는 media. 제품은 파싱 잡과 원고 상태'),
                 ('036', '연결', '탈퇴 purge에서 `media.detach` 후 media 휴지통 규칙을 따름'),
                 ('025', '축소', '법무 페이지 본문은 `policy_documents` seed, 화면은 compliance 컴포넌트')],
        dec=[('V2-PB-1', 'HWP 업로드 허용', '허용(국내 원고 비중), 변환은 파싱 잡'), ('V2-PB-2', '표지 프리셋 크기', '1600x2560(전자책 표지 일반 비율 1:1.6, 플랫폼별 규격은 확인 필요)')],
    ),
    'astro-ai': dict(
        name='신비로운AI', app='astro', pfx='AS', stage='2',
        domain=['20261013000002_astro_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['007', '025'],
                use='보관함·동의 API(007), 법적 페이지(약관, 처리방침, 환불, 면책, 025), 대상 인물(가족·지인) 정보 제공 동의',
                rep='`astro.consents`(kind, version, granted, ip_hash) → `compliance.consents`. 대상 인물 동의는 purpose `astro.subject_info` + evidence `subject_id`. `astro.subjects.consent_version` → 같은 기록으로',
                keep='`astro.subjects.third_party_consent_at`(대상별 화면 표시용 캐시), 면책 문구 원고',
                inj='`profileKind: kr_ecommerce`, 제품 목적 코드 `astro.subject_info`'),
            'media': dict(st='보류', why='이미지 업로드가 없고 리포트 PDF는 렌더 산출물', when='사용자 사진(손금·관상 등) 기능을 만들 때'),
        },
        extra='notify(리포트 메일·알림톡, 036)는 기존 공용모듈 로드맵대로.',
        db=[('`astro.consents`', '표 삭제 → `compliance.consents`'),
            ('`astro.subjects`', '`consent_version` 삭제, `third_party_consent_at`은 표시용으로 유지')],
        changes=[('007', '축소', '동의 API는 compliance 호출로. 보관함 API는 그대로'),
                 ('025', '축소', '법적 페이지 본문은 `policy_documents` seed')],
        dec=[('V2-AS-1', '제품 목적 코드(`astro.subject_info`)를 compliance 표준 목적에 넣을지', '제품 접두어 코드로 유지')],
    ),
    'shortsflow': dict(
        name='ShortsFlow', app='video', pfx='VID', stage='3',
        domain=['20261013000002_video_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['035', '058'],
                use='마케팅 랜딩·요금·약관 페이지(035), 클립 위험 동의(058), 채널 자동화 동의, 업로드 문구의 대가성·AI 표시',
                rep='`video.channels.automation_consent_version`·`automation_consented_at`·`automation_consented_by` → `compliance.consents`(purpose `video.automation`), 클립 위험 동의 → purpose `video.clip_risk`, 업로드 문구 표시 판정 → `required_labels`(대가성은 코어 `effective_disclosure`)',
                keep='`video.compliance_checks`(플랫폼 정책 검사), `video.banned_words`(대본 금칙어), 업로드 문구 삽입(021)',
                inj='`profileKind: kr_ecommerce`, 제품 목적 코드 `video.automation`, `video.clip_risk`'),
            'media': dict(st='보류', why='영상·음원은 Python 미디어 워커 파이프라인(011, 016)이 소유', when='썸네일·채널 아트 라이브러리를 만들 때'),
            'editorial': dict(st='보류', why='업로드 예약은 외부 플랫폼(YouTube 등) 발행 일정이라 웹 콘텐츠 워크플로와 다름', when='-'),
        },
        extra='notify(작업 완료·고객 승인 메일, 061), analytics, cms(랜딩·링크인바이오)는 기존 로드맵대로.',
        db=[('`video.channels`', '자동화 동의 3개 컬럼 삭제 → `compliance.consents`')],
        changes=[('058', '축소', '동의 기록은 `recordConsent(video.clip_risk)`, 고지문은 `policy_documents`. 화면은 제품'),
                 ('035', '축소', '약관 본문은 `policy_documents` seed'),
                 ('021', '연결', '표시 문구 필요 여부를 `requiredLabels`로 판정')],
        dec=[],
    ),
    'nomad-blog': dict(
        name='NOMAD Blog', app='blog', pfx='BL', stage='3',
        domain=['20261013000002_blog_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['023', '026', '027'],
                use='채널 위험 동의 모달(023), 랜딩·약관·처리방침(026), 대가성 문구 설정(027), AI 작성 원고 표시',
                rep='`blog.channel_accounts.automation_risk_consented_at`·`_by` → `compliance.consents`(purpose `blog.channel_risk`), AI·대가성 표시 판정 → `required_labels`',
                keep='대가성 문구 편집 화면(027, 코어 `upsert_affiliate_disclosure`), 금지 표현 체크리스트(036)',
                inj='`profileKind: kr_ecommerce`, 라벨 위치 `ai_assisted: footer`'),
            'media': dict(st='채택', role='', deps=['013', '021'],
                use='원고 이미지·대표 이미지(워드프레스 어댑터 대표 이미지, 013), 원고 목록 썸네일',
                rep='원고 본문의 이미지 URL 직접 저장 → `media.assets` + `usages`(owner `editorial.entry`)',
                keep='외부 플랫폼 업로드(각 어댑터가 media 사본 URL을 받아 업로드)',
                inj='`presets: { blog_1200 }`, `requireAlt: true`(SEO)'),
            'editorial': dict(st='채택', role='기준 구현', deps=['014', '021', '005'],
                use='원고 상태(초안 → 검토 → 예약 → 발행), 예약 발행, 원고 목록·캘린더(021), 수정 이력',
                rep='`blog.posts`의 제목·본문·상태·예약 시각·AI 표시 → `editorial.entries`(entry_type `blog.post`), 발행 오케스트레이션의 상태 전이(014) → `editorial.transition`',
                keep='`blog.posts` 확장 표(채널, 키워드, 브랜드커넥트 연결), `post_publications`(채널별 외부 발행 기록), `post_affiliate_links`, 월 발행 한도(005 → 가드 `blog.monthly_quota_guard`)',
                inj='`entryTypes: [blog.post]`, 워크플로 `draft → scheduled → published`(검토 단계 생략, 1인 사용자), `onPublished`: 채널별 발행 잡 enqueue, 가드 `blog.monthly_quota_guard`'),
            'community': dict(st='보류', why='글이 외부 플랫폼(네이버·티스토리·워드프레스)에 게시돼 댓글도 외부', when='-'),
            'ads': dict(st='보류', why='자체 사이트 광고 슬롯이 없음', when='-'),
            'search': dict(st='보류', why='원고 목록 필터로 충분', when='원고가 계정당 수천 건을 넘을 때'),
        },
        extra='notify, analytics, cms(랜딩)는 기존 로드맵대로.',
        db=[('`blog.posts`', '공통 필드(제목·본문·상태·예약·발행 시각·AI 표시) 삭제, `entry_id`(→ `editorial.entries`, PK 겸 FK) + 블로그 전용 필드만 남김'),
            ('`blog.channel_accounts`', '위험 동의 컬럼 2개 삭제 → `compliance.consents`')],
        changes=[('014', '축소', '상태 전이·예약은 editorial. 제품은 채널별 발행·취소·재시도(외부 API)'),
                 ('021', '축소', '상태 배지·전이 버튼·예약 대화상자·이력은 editorial UI, 캘린더 레이아웃만 제품'),
                 ('005', '연결', '월 발행 한도를 editorial 게시 가드로 등록'),
                 ('023', '연결', '동의 기록을 compliance로'),
                 ('013', '연결', '대표 이미지는 media 사본 URL 사용')],
        dec=[('V2-BL-1', '검토 단계를 둘지', '1인 사용자 기본은 생략, 팀 플랜에서 켬(워크플로 org 덮어쓰기)')],
    ),
    'nomad-commerce': dict(
        name='NOMAD Commerce', app='commerce', pfx='CM', stage='3',
        domain=['20261013000002_commerce_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['033'],
                use='법적 문서(약관, 처리방침, AI 고지, 033), 생성 이미지 AI 표시',
                rep='법적 문서 본문 → `policy_documents`, AI 생성 이미지 표시 판정 → `required_labels`',
                keep='상세페이지 법적고지 템플릿(015, 셀러 상품 정보 고시), 마켓 금칙어 `commerce.banned_words`',
                inj='`profileKind: kr_ecommerce`'),
            'media': dict(st='채택', role='', deps=['014', '023'],
                use='상품 원본 이미지, 슬롯 이미지 엔진 결과(014), 등록 폼 업로드(023)',
                rep='`commerce.market_images`의 저장 경로·크기·MIME → `media.assets`(+ `ai_generated` 표시), 업로드 API의 서명 URL·완료 검증 → media',
                keep='슬롯 이미지 엔진(fal 제출·웹훅), 마켓 규격 리사이즈(`market_*` 프리셋은 제품 추가), `export_files`',
                inj='`presets: { market_1000, market_780 }`(마켓 규격 확인 필요), `allowedMime` 이미지만'),
            'search': dict(st='보류', why='상품 DB 검색은 필터 목록으로 시작', when='상품이 계정당 1만 건을 넘을 때'),
        },
        extra='notify, analytics, cms(랜딩)는 기존 로드맵대로.',
        db=[('`commerce.market_images`', '파일 메타 컬럼 삭제 → `asset_id`(→ `media.assets`)와 마켓·슬롯 연결만')],
        changes=[('014', '연결', '생성 결과를 `registerUpload` 대신 서버 등록(`media.register_generated`, 패키지 요청)으로 저장'),
                 ('023', '축소', '서명 URL·완료 검증은 media'),
                 ('033', '축소', '법적 문서 본문은 `policy_documents` seed')],
        dec=[('V2-CM-1', 'AI 생성 이미지를 media에 서버 등록하는 API', 'media v1.1에 `registerGenerated` 추가 요청(업로드 없이 워커가 등록)')],
    ),
    'microweb-studio': dict(
        name='Microweb Studio', app='microweb', pfx='MW', stage='4',
        domain=['20261013000002_microweb_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['029', '019'],
                use='약관·처리방침·하객 개인정보 고지(029), 견적 문의 리드 동의(019), 사이트 공개 동의(대가성·공개 범위)',
                rep='`microweb.leads.privacy_consent_at` → `compliance.consents`(subject `email`), `microweb.sites.disclosure_consent_*` → purpose `microweb.disclosure`',
                keep='계좌·연락처 노출 설정(사이트 편집기)',
                inj='`profileKind: kr_ecommerce`(팩 판매), 제품 목적 코드 `microweb.disclosure`'),
            'media': dict(st='채택', role='', deps=['010', '014', '051'],
                use='업로드 파이프라인(010), 편집기 사진(014), 하객 음성 방명록(051, kind `audio`)',
                rep='`microweb.site_assets` → `media.assets` + `usages`(owner `microweb.site`), 서명 업로드·완료 검증 → media',
                keep='쇼룸 포트폴리오 이미지 매니페스트, 인사말 TTS 생성(050)',
                inj='`presets: { square_1080, card_640 }`, `strip_exif: true`(하객 사진 위치정보)'),
            'community': dict(st='채택', role='기준 구현', deps=['009', '018', '051'],
                use='하객 방명록(비회원 이름·비밀번호), 방명록 숨김·스팸·삭제(018), 음성 방명록 글(051)',
                rep='`microweb.guestbook_entries` → `community.posts`(author `guest`, `relation`은 `meta`), 하객 쓰기 라우트의 IP 해시·레이트 리밋(009) → community',
                keep='RSVP(`rsvp_responses`), 음성 녹음·고지 흐름(051, 녹음 파일은 media)',
                inj='`targetTypes: [microweb.site]`, 정책 `{ who: anyone, guest_allowed: true, moderation: post }`, 금칙어 플랫폼 공통'),
            'editorial': dict(st='보류', why='사이트 게시(013)는 크레딧 소비가 묶인 단일 게시 흐름', when='사이트 버전 관리·예약 공개가 필요할 때'),
            'ads': dict(st='보류', why='부고장·청첩장 협찬은 사업 결정 전', when='협찬 상품을 팔기로 정할 때'),
        },
        extra='tenancy는 V1 설계대로, notify(초대·리드 알림), analytics, cms(쇼룸)는 기존 로드맵대로.',
        db=[('`microweb.guestbook_entries`', '표 삭제 → `community.posts`(+ `threads` target `microweb.site`)'),
            ('`microweb.site_assets`', '표 삭제 → `media.assets` + `media.usages`'),
            ('`microweb.leads`', '`privacy_consent_at` 삭제 → `compliance.consents`'),
            ('`microweb.sites`', '`disclosure_consent_at`, `_by`, `_basis` 삭제 → `compliance.consents`')],
        changes=[('009', '대체', '방명록 쓰기는 community `createPost`(비회원). RSVP 쓰기만 제품'),
                 ('018', '축소', '방명록 관리 화면은 community `ModerationQueue`. RSVP 합계 화면은 제품'),
                 ('010', '대체', '업로드 파이프라인은 media 적용 작업으로'),
                 ('051', '연결', '음성 파일은 media(kind `audio`), 글은 community'),
                 ('029', '축소', '법적 고지 본문은 `policy_documents` seed')],
        dec=[('V2-MW-1', '방명록 비회원 비밀번호를 받을지', '받음(본인 삭제용), 실패 5회 잠금')],
    ),
    'live-poll': dict(
        name='Live Poll', app='poll', pfx='LP', stage='4',
        domain=['20261013000002_poll_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['032'],
                use='진행자 가입 약관·처리방침, 진행자 가이드·FAQ의 개인정보 안내(032), 청중 참여 안내',
                rep='약관·처리방침 본문 → `policy_documents`, 진행자 가입 동의 → `consents`',
                keep='청중 익명 참여 규칙(로그인 없음)',
                inj='`profileKind: kr_business`'),
            'community': dict(st='부분 채택', role='', deps=['021'],
                use='조직 금칙어 설정(021)과 금칙어 검사 함수만',
                rep='`poll.banned_words` → `community.banned_words`(app `poll`), 금칙어 매칭 → community `filters`',
                keep='Q&A 질문·추천(`qna_questions`, `qna_upvotes`), 모더레이션 패널(019), 실시간 전달',
                inj='금칙어 동작 `review`(Q&A 대기 큐로)'),
            'ads': dict(st='보류', why='지금 기획에 스폰서·광고 기능이 없음', when='행사 스폰서 배너를 팔기로 정할 때(발표 화면 슬롯)'),
        },
        extra='notify, analytics, cms(랜딩)는 기존 로드맵대로.',
        db=[('`poll.banned_words`', '표 삭제 → `community.banned_words`')],
        changes=[('021', '축소', '금칙어 추가·삭제 화면은 community 설정 컴포넌트'),
                 ('019', '연결', '질문 접수 시 community 금칙어 검사 결과로 대기 큐 여부 결정')],
        dec=[('V2-LP-1', 'Q&A 전체를 community로 옮길지', '옮기지 않음(실시간·익명 투표 성격). 금칙어만')],
    ),
    'toon-factory': dict(
        name='Toon Factory', app='toon', pfx='TN', stage='4',
        domain=['20261013000002_toon_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['028', '064'],
                use='약관·처리방침·AI 이용 고지·에셋 이용 허락(028), 렌더 대가성·가상인물 표시(064)',
                rep='법적 문서 본문 → `policy_documents`, 표시 필요 판정 → `required_labels`(코드 `sponsored`, `ai_generated` + 신규 요청 `virtual_character`)',
                keep='`toon.sponsorships`(협찬 기록·승인), 이미지 상단 표시 렌더(064)',
                inj='`profileKind: kr_ecommerce`, 라벨 위치 `sponsored: before_title`'),
            'media': dict(st='채택', role='', deps=['018', '032'],
                use='내 에셋 화면(AI 배지·용량·보관, 032), 사용자 업로드·생성 이미지',
                rep='`toon.user_assets` → `media.assets`(`ai_generated`, 라이선스 `ugc`·`ai_generated`)',
                keep='카탈로그 에셋(`asset_packs`, `characters`, `assets`), 내보내기(`exports`, 018·019)',
                inj='`presets: { cut_1080 }`, 플랜별 용량은 제품 entitlement'),
            'editorial': dict(st='보류', why='회차는 외부 플랫폼용 내보내기 산출물', when='자체 웹툰 뷰어를 열 때'),
            'community': dict(st='보류', why='자체 뷰어가 없음', when='자체 뷰어와 함께'),
            'membership': dict(st='보류', why='유료 회차 판매가 기획에 없음', when='자체 뷰어와 함께'),
            'ads': dict(st='보류', why='협찬(브랜디드 툰)은 콘텐츠 협찬 기록이지 광고 슬롯이 아님', when='-'),
        },
        extra='notify, analytics, cms(랜딩)는 기존 로드맵대로.',
        db=[('`toon.user_assets`', '표 삭제 → `media.assets` + `usages`(owner `toon.episode`)')],
        changes=[('064', '연결', '표시할 라벨을 `requiredLabels`로 판정, 문구는 `label_definitions`'),
                 ('032', '축소', '목록·필터는 `MediaLibrary`, 플랜 용량 표시만 제품'),
                 ('028', '축소', '법적 문서 본문은 `policy_documents` seed')],
        dec=[('V2-TN-1', '`virtual_character` 라벨을 compliance 표준에 추가', '추가 요청(가상인물 광고 표시)')],
    ),
    'admin-suite': dict(
        name='Admin Suite', app='erp, sms, hms', pfx='ADM', stage='5',
        domain=['erp/20261013000002_erp_domain.sql', 'sms/20261013000002_sms_domain.sql', 'hms/20261013000002_hms_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['014', '022', '029'],
                use='erp·sms·hms 로그인 화면의 약관·처리방침 동의(014, 022, 029), 기관 사업자 표기',
                rep='가입 동의 기록 → `compliance.consents`',
                keep='hms 의료정보 동의·열람 기록(의료법 영역, hms 제품 표)',
                inj='`profileKind: kr_business`. hms는 compliance 표에 환자 정보를 넣지 않고 직원 동의만'),
            'media': dict(st='보류', why='SMS 자산 이식(029)은 정적 이미지', when='-'),
            'search': dict(st='보류', why='기관 데이터 검색은 제품 목록 필터', when='-'),
        },
        extra='notify(SMS 알림, 032)는 기존 로드맵대로. hms는 의료정보 격리로 공용모듈 표 사용을 compliance 동의 기록에만 한정.',
        db=[('3개 앱 모두', '제품 표 변경 없음. 앱 폴더(`supabase/erp`, `sms`, `hms`)마다 compliance 변환본 추가')],
        changes=[('014', '연결', 'erp 가입 동의를 compliance로'), ('022', '연결', 'hms 직원 초대 수락 동의를 compliance로'), ('029', '연결', 'sms 동의를 compliance로')],
        dec=[],
    ),
    'stock-dashboard': dict(
        name='Stock Dashboard', app='stock', pfx='ST', stage='5',
        domain=['20261013000002_stock_domain.sql', '20261013000003_stock_orders_paper.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['010', '028'],
                use='고지 동의와 법적 페이지(010), 계정 설정의 동의 이력·내 데이터 내려받기·탈퇴(028)',
                rep='`stock.consents`(kind, version, accepted_at) → `compliance.consents`, 동의 이력 화면 → compliance, 데이터 요청 → `data_requests`(compliance v1.1)',
                keep='투자 고지 문구와 단계별 AI 처리 고지(법률 검토 결과, 005), 금칙어·카피 점검(026)',
                inj='`profileKind: kr_business`, 제품 목적 코드 `stock.investment_notice`'),
        },
        extra='notify, analytics는 기존 로드맵대로.',
        db=[('`stock.consents`', '표 삭제 → `compliance.consents`')],
        changes=[('010', '축소', '동의 저장은 compliance, 투자 고지 문구는 `policy_documents`(제품 kind)'),
                 ('028', '축소', '동의 이력은 compliance 화면, 탈퇴·내려받기는 compliance v1.1 `data_requests`가 나오기 전까지 제품')],
        dec=[],
    ),
    'nomad-docs': dict(
        name='NOMAD Docs', app='docs', pfx='DC', stage='2 이후',
        domain=['20261013000002_nomad_docs_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['046'],
                use='법무 페이지·고지문·문구 사전(046), 가입 동의',
                rep='법무 페이지 본문 → `policy_documents`',
                keep='문서 고지문 문구 사전(생성 문서 안에 들어가는 문구)',
                inj='`profileKind: kr_ecommerce`'),
            'media': dict(st='채택', role='', deps=['031', '042'],
                use='자료 업로드(서명 URL·완료 검증, 031), 자료 올리기 화면(042)',
                rep='`docs.uploads`의 파일 메타 → `media.assets`(kind `file`)',
                keep='업로드 자료의 추출·RAG 색인(032), 직인 이미지 처리(015)',
                inj='`allowedMime`(pdf, docx, xlsx, hwp, 이미지), `strip_exif: true`'),
            'editorial': dict(st='보류', why='문서 결재(`approval_steps`)는 다단계 승인이라 editorial 1차(1단 승인) 범위 밖', when='editorial 확장 "승인 단계 2단 이상"이 나올 때'),
            'search': dict(st='보류', why='지금은 RAG(032)와 목록 필터로 충분', when='거래처·문서가 많아져 검색창이 필요할 때'),
        },
        extra='notify, analytics, cms(랜딩)는 기존 로드맵대로.',
        db=[('`docs.uploads`', '파일 메타 컬럼 삭제 → `asset_id`(→ `media.assets`)와 추출 상태만')],
        changes=[('031', '대체', '서명 업로드·완료 검증은 media 적용 작업으로. 추출 잡 연결만 제품'),
                 ('046', '축소', '법무 페이지 본문은 `policy_documents` seed')],
        dec=[],
    ),
    'book-trailer': dict(
        name='NOMAD Book Trailer(가칭)', app='trailer', pfx='TR', stage='4',
        domain=['20261013000002_trailer_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['051', '016', '031'],
                use='법적 고지 페이지(약관, 개인정보, AI 표시 안내, 051), 가입 동의, 국외 이전 동의(016), 엔드카드 AI 표시 문구(031)',
                rep='법적 고지 본문 → `policy_documents`(kind `terms`, `privacy`, `ai_notice`, `refund`), 가입·국외 이전 동의 → `consents`(purpose `cross_border_ai` 등), 엔드카드 AI 표시 문구 → `label_definitions`(`ai_generated`, `ai_voice`) 텍스트',
                keep='책별 권리 확인(`trailer.books.rights_ack_*`, 감사 로그), 음악 권리 확인, 렌더 `ai_label` CHECK와 표시 여부 판정(`start_render`), 메타데이터 대가성 문구 트리거',
                inj='`profileKind: kr_ecommerce`(유료 플랜 판매), `signupConsents: { required: [terms, privacy, refund], optional: [marketing_email, cross_border_ai] }`'),
            'media': dict(st='보류', why='원고·표지·사용자 음악은 책·트레일러에 하나씩 붙는 고정 경로 파일이고 경로를 CHECK로 강제한다. 장면 에셋은 렌더 스냅샷이 경로를 고정해야 해서 공용 자산의 삭제·교체 흐름과 맞지 않는다', when='여러 책에서 같은 이미지·로고를 다시 쓰는 라이브러리가 필요할 때(브랜드 키트 로고, Phase 2 화이트라벨)'),
            'editorial': dict(st='보류', why='외부 승인 링크(057)는 로그인 없는 저자 1명의 승인·수정 요청이 핵심이라 editorial 1단 승인(조직 멤버 주체)과 다르다', when='publisher 팀 안에서 마케터 → 편집장 다단계 승인을 만들 때'),
            'search': dict(st='보류', why='책·트레일러 목록 필터와 책별 RAG(022)로 충분', when='출판사 계정의 책이 수백 권을 넘을 때'),
        },
        extra='notify(렌더 완료·승인 링크 만료 알림, 052), analytics(퍼널 이벤트만. 구매 링크 클릭은 제품 `link_clicks`), cms(랜딩·샘플 페이지)는 기존 로드맵대로. 화이트라벨(Phase 2)은 tenancy 검토.',
        db=[('`trailer.*`', '변경 없음. 가입·국외 이전 동의 기록은 `compliance.consents`에 새로 쌓는다. 책 권리 확인(`books.rights_ack_*`)과 음악 권리 확인(`trailers.music_rights_ack*`)은 책·트레일러 단위 확인이라 제품에 남긴다')],
        changes=[('051', '축소', '법적 고지 본문은 `policy_documents` seed, 화면은 `LegalFooter`·`ConsentCheckboxes`. 페이지 배치와 AI 표시 안내 원고만 제품'),
                 ('016', '연결', '국외 이전 동의를 `recordConsent(cross_border_ai)`로도 남긴다. 코어 `set_ai_cross_border_ack` 호출은 그대로'),
                 ('031', '연결', '엔드카드 AI 표시 문구는 `label_definitions` 텍스트를 읽어 렌더 스냅샷에 고정. 표시 여부 판정과 `ai_label` CHECK는 제품 그대로')],
        dec=[('V2-TR-1', '책 권리 확인 고지문(`rights-2026-10-v1`) 본문 버전을 compliance로 옮길지', '본문 버전만 `policy_documents` 제품 kind(`rights_notice`, compliance 확장 요청)로, 책별 확인 기록은 제품 표 유지')],
    ),
    'local-news': dict(
        name='로컬뉴스 클라우드(가칭)', app='news', pfx='NW', stage='6',
        domain=['20261013000002_tenant_theming.sql(유지)', '20261013000003_local_news_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['022', '034'],
                use='필요적 게재사항 10개·법정 푸터(022), 광고·AI 표시, 독자 가입 동의, 준수 데스크(034)',
                rep='`news.newspapers` 법정 표기 필드·`news.is_profile_complete` → `legal_profiles`(`kr_newspaper`)·`is_profile_complete`, 라벨 CHECK → `labels_ok`',
                keep='자체기사 비율, 정정·반론보도(`correction_requests`), 선거 모드(`election_periods`)',
                inj='`profileKind: kr_newspaper`, `publishGuard: true`'),
            'media': dict(st='채택', role='', deps=['014'],
                use='기사 사진·대체 텍스트·출처·저작권 만료(014), 이관 사진(018)',
                rep='`news.media_assets` → `media.assets`',
                keep='-',
                inj='`requireAlt: true`, 프리셋 `og_1200x630`, `hero_1600`'),
            'editorial': dict(st='채택', role='', deps=['011', '012', '037'],
                use='기사 작성 → 데스크 승인 → 예약 → 게시 → 정정, 수정 이력, 미리보기, 조회 집계',
                rep='`news.articles` 공통 필드, `article_revisions`, `article_view_hourly`, 게시 RPC → `editorial.*`',
                keep='기사 확장 표(유형·바이라인·섹션·지역·태그·`is_poll`), 홈 편집, 지면, 라이브',
                inj='`entryTypes: [news.article]`, 가드 `compliance.is_profile_complete:kr_newspaper`, `news.election_guard`'),
            'community': dict(st='채택', role='', deps=['031'],
                use='기사 댓글, 신고, 임시조치, 금칙어(031)',
                rep='`news.comments`, `comment_reports`, `newspapers.banned_words`·`comments_enabled` → `community.*`',
                keep='경조사(`life_events`), 제보(`tips`, support 모듈 전까지 제품), 선거 댓글 정책(가드)',
                inj='`targetTypes: [editorial.entry]`, 기본 댓글 끔(D-6)'),
            'search': dict(st='채택', role='기준 구현', deps=['035'],
                use='기사 검색(섹션·지역·기간 필터, 035)',
                rep='`news.search_articles` → `search.query` + 어댑터 `news.article`',
                keep='지원사업 리포트(035 일부)',
                inj='`facetKeys: [section, region]`'),
            'membership': dict(st='채택', role='기준 구현', deps=['023', '024'],
                use='독자 행(023), 후원·유료 멤버십·페이월(024)',
                rep='`news.readers`, `membership_tiers`, `memberships`, `donations`, `paywall_rules` → `membership.*`',
                keep='기사 단위 페이월 문구',
                inj='`accessTargets: [news.article]`, 신문사 자기 Toss 가맹(D-4)'),
            'ads': dict(st='채택', role='기준 구현', deps=['025', '027'],
                use='광고 슬롯·캠페인·소재 검수·집계(025), 외부 광고망(027)',
                rep='`news.ad_slots`, `advertisers`, `ad_campaigns`, `ad_creatives`, `ad_daily_stats` → `ads.*`',
                keep='업소 디렉토리·지자체 공고(026), 정부광고 직판 금지(NW013 → `AD003`)',
                inj='`publicBodyDirectSale: false`'),
        },
        extra='notify 보강분(뉴스레터·웹 푸시, 028·029), cms 보강분(배포·SEO, 033), tenancy(Theming, 005·039)는 기존 공용모듈 v1이 나와 있으면 그것을 쓰고, 없으면 V1(`news` 스키마)대로.',
        db=[('`2500_news.sql` / 모놀리스 `0003`', '공용모듈로 옮긴 표 15개(`media_assets`, `article_revisions`, `article_view_hourly`, 독자·멤버십 5개, 광고 5개, 댓글 2개)를 지우고, `articles`·`newspapers`는 공통 컬럼을 뺀 확장 표로 다시 작성(4.1절 SQL 작업). 뉴스레터·푸시 표 4개는 notify v1이 나올 때까지 유지. 스모크 314개 중 옮긴 표 항목은 모듈 스모크로 이동'),
            ('공용모듈 순서', '`…000002_tenant_theming` 다음에 공용모듈 7개, 도메인은 `…001000_local_news_domain.sql`')],
        changes=[('001', '축소', 'DB 적용에 공용모듈 7개 변환본 포함, `news` 조각은 확장 표만'),
                 ('011', '축소', 'M1 서버는 editorial·media 위 기사 확장 RPC만'),
                 ('012', '축소', '에디터·데스크 화면은 editorial UI + 신문 워크플로 설정'),
                 ('014', '대체', 'media 적용'),
                 ('022', '축소', '법정 표기 판정은 compliance `kr_newspaper`, 법정 푸터 화면만 제품'),
                 ('023', '축소', '독자 행은 membership `ensureEndUser`'),
                 ('024', '축소', '결제·구독은 membership 기준 구현과 함께'),
                 ('025', '대체', 'ads 기준 구현 + 적용'),
                 ('031', '대체', 'community 적용'),
                 ('035', '축소', '검색은 search 기준 구현, 조회 집계는 editorial')],
        dec=[('V2-NW-1', '공용모듈 v1.0이 없는 모듈(search·membership·ads)을 이 제품이 패키지로 만들지, `news` 스키마로 먼저 만들지', '패키지로 만듦(기준 구현, CMX-1)')],
    ),
    'arch-studio': dict(
        name='Arch Studio(가칭)', app='arch', pfx='AR', stage='코어 이후(설치형)',
        domain=['20261013000002_arch_domain.sql'],
        mods={
            'compliance': dict(st='채택', role='', deps=['008', '043', '031', '057', '062'],
                use='온보딩 국외 이전 동의(008), 라이선스·플랜·크레딧팩 구매 약관·환불 규정 동의(043), 설정의 국외 이전·녹음 고지 버전(031), 법적 고지 페이지 `/legal/*`(057), Stage B 온보딩 약관 단계(062)',
                rep='법적 고지 본문(`web/src/content/legal/**`) → `policy_documents`(kind `terms`, `privacy`, `ai_notice`, `refund`), 가입·구매·국외 이전 동의 → `consents`(purpose `cross_border_ai` 등), 판매자 표기 → `legal_profiles`(`kr_ecommerce`)',
                keep='설치형 앱 안의 오프라인 고지 문구, 표제란 고지 상수(`titleblock`, PRD 9.7절), 상담 녹음 제3자 고지 확인(`arch.intake_runs.notice_version`, 녹음 건별), 코어 `set_ai_cross_border_ack` 호출',
                inj='`profileKind: kr_ecommerce`(시리얼 라이선스·플랜 판매), `signupConsents: { required: [terms, privacy, refund], optional: [marketing_email, cross_border_ai] }`'),
            'media': dict(st='보류', why='렌더 결과는 90일 뒤 지우는 실행 결과물(`arch.renders`, `purge_expired`)이고 표제란 로고는 조직당 1장 고정 경로라 공용 자산 라이브러리가 필요 없음', when='클라우드 렌더 갤러리·사무소 자산 라이브러리를 만들 때'),
            'search': dict(st='보류', why='프로젝트·도면 검색은 데스크톱 로컬 SQLite, 법규 해설 위키는 llm-wiki 검색으로 충분', when='클라우드 프로젝트 공유·조직 단위 검색을 만들 때'),
        },
        extra='notify(시리얼 발급 메일·잡 완료 알림), analytics(샘플 다운로드 → 사전예약 전환 이벤트)는 기존 공용모듈 로드맵대로. 데스크톱 앱 안 라이선스 판정·고지는 공용모듈 대상이 아니다.',
        db=[('`arch.*`', '변경 없음(동의를 저장하는 표가 없음). 가입·구매·국외 이전 동의 기록은 `compliance.consents`에 새로 쌓는다. 상담 녹음 제3자 고지(`intake_runs.notice_version`)는 녹음 건별 확인이라 제품에 남긴다'),
            ('모놀리스 `0002_arch_domain.sql`', '모듈러 정본 `2400_arch.sql`의 변환본. 이름만 `…001000_arch_domain.sql`로 바뀌고 내용은 그대로')],
        changes=[('008', '연결', '`/onboarding` 국외 이전 동의를 `recordConsent(cross_border_ai)`로도 남긴다. 코어 `set_ai_cross_border_ack` 호출은 그대로'),
                 ('043', '연결', '구매 전 약관·환불 규정 동의를 `ConsentCheckboxes`·`hasConsent`로 확인한 뒤 서버 주문을 만든다. `AR005`, C-1 전 영구 라이선스 보류는 그대로'),
                 ('031', '연결', '국외 이전·녹음 고지 문구는 `policy_documents`(kind `ai_notice`) 버전을 읽고 재동의는 `needsReconsent`'),
                 ('057', '축소', '`/legal/*` 본문은 `policy_documents` seed, 화면은 `LegalFooter`. 페이지 배치와 도면 고지(PRD 6장·9.7절) 원고만 제품'),
                 ('062', '연결', '온보딩 약관 단계는 `signupConsents` 필수 항목을 `ConsentCheckboxes`로 받고 `recordConsent`')],
        dec=[('V2-AR-1', '영구 라이선스 청약철회 제한 고지를 공통 `refund` 정책 안의 절로 둘지, 제품 kind로 따로 둘지', '공통 `refund` 안의 절(제안). 판매 시작(C-1 반영) 전에 확정')],
    ),
}


def read(p):
    return io.open(p, encoding='utf-8').read()


def plan_info(key, pfx):
    """06장에서 작업 이름과 웨이브를 읽는다."""
    path = os.path.join(ROOT, 'products', key, '06_AGENT_PLAN.md')
    titles, wave_of, order = {}, {}, []
    if not os.path.exists(path):
        return titles, wave_of, order
    for line in read(path).split('\n'):
        m = re.match(r'^\| ' + re.escape(pfx) + r'-06-(\d+) \| ((?:[^|\\]|\\.)*)\|', line)  # 셀 안 \| 는 이어 읽는다
        if m:
            titles[m.group(1)] = m.group(2).replace('\\|', '/').strip()
            continue
        m = re.match(r'^\| (W\d+(?:-[A-Z])?)[^|]*\| ([^|]*)\|', line)
        if m:
            w = m.group(1)
            if w not in order:
                order.append(w)
            for n in re.findall(r'\b(\d{3})\b', m.group(2)):
                wave_of.setdefault(n, w)
    return titles, wave_of, order


def short(t, n=46):
    t = t.replace('|', '/')
    if len(t) <= n:
        return t
    t = t[:n]
    if t.count('`') % 2:  # 코드 표시 안에서 잘리면 그 앞에서 자름
        t = t[:t.rfind('`')]
    return t.rstrip() + '…'


def gen(key, d):
    pfx, v1 = d['pfx'], d.get('v1', True)
    titles, wave_of, order = plan_info(key, pfx)
    adopt = [m for m in MODS if m in d['mods'] and d['mods'][m]['st'] != '보류']
    hold = [m for m in MODS if m in d['mods'] and d['mods'][m]['st'] == '보류']
    rel = '../..'
    L = []
    a = L.append
    a(f"# {key} 개발 방법 V2: 공용모듈 적용판 ({d['name']})")
    a('')
    a(f"작성일 2026-10-15. 생성: `develop_V2/_shared/tools/gen_v2.py`(직접 고치지 말고 스크립트 데이터를 고친 뒤 다시 실행). "
      + (f"V1 안내서 [`develop/{key}/{key}_develop.md`]({rel}/develop/{key}/{key}_develop.md)를 기본으로 하고, 이 문서는 local-news에서 꺼낸 공용모듈을 쓰도록 **바뀌는 부분만** 다룹니다. 두 문서가 다르면 이 문서가 우선합니다. "
         if v1 else "이 제품은 아직 V1 개발 묶음(`develop/arch-studio/`)이 없습니다. 06장을 쓸 때 이 문서의 공용모듈 결정을 반영합니다. ")
      + f"공통 규칙은 [`develop_V2/_shared/V2_RULES.md`]({rel}/develop_V2/_shared/V2_RULES.md).")
    a('')
    # 0
    a('## 0. 한눈에 보기')
    a('')
    a('| 항목 | 내용 |')
    a('|---|---|')
    a(f"| 앱 id / 작업 접두어 | `{d['app']}` / `{pfx}` |")
    a(f"| 개발 단계(`products/README.md` 개발 순서) | {d['stage']} |")
    labels = [m if d['mods'][m]['st'] == '채택' else '%s(%s)' % (m, d['mods'][m]['st']) for m in adopt]
    a(f"| 채택 공용모듈 | {', '.join(labels) or '없음'} |")
    a(f"| 보류 공용모듈 | {', '.join(hold) or '없음'} |")
    roles = [f"{m} {d['mods'][m]['role']}" for m in adopt if d['mods'][m].get('role')]
    a(f"| 이 제품의 역할 | {', '.join(roles) if roles else '패키지 사용(구현하지 않음)'} |")
    a(f"| 기존 공용모듈 | {d['extra']} |")
    a('')
    # 1
    a('## 1. 진행 순서')
    a('')
    a('| 순서 | 할 일 | 문서 |')
    a('|---|---|---|')
    if v1:
        a(f"| 1 | V1 0~6장: 사전 준비, setup 스크립트, project-profile, 로컬 DB 기동 전까지 | V1 안내서 |")
    else:
        a('| 1 | 06장 작성: 이 문서 2·4장을 반영 | `products/arch-studio/` |')
    a('| 2 | 공용모듈 SQL 추가와 도메인 파일 이름 바꾸기, 제품 표 정리 | 이 문서 3장 |')
    a('| 3 | `06_AGENT_PLAN.md`에 V2 작업 추가, V1 작업 축소·대체 반영 → 개발 묶음 다시 만들기 | 이 문서 4장, V2_RULES 4장 |')
    a('| 4 | V1 8~10장 사이클로 웨이브 진행(V2 작업은 해당 웨이브 맨 앞) | V1 안내서 |')
    a('| 5 | 검증 추가 항목 | 이 문서 6장 |')
    a('')
    # 2
    a('## 2. 공용모듈 적용 상세')
    a('')
    for m in adopt:
        x = d['mods'][m]
        num, ko = MODS[m]
        a(f"### 2.{adopt.index(m) + 1} {m} ({ko}, `{m}` {num}){' — ' + x['role'] if x.get('role') else ''}")
        a('')
        a('| 항목 | 내용 |')
        a('|---|---|')
        a(f"| 이 제품에서 쓰는 곳 | {x['use']} |")
        a(f"| 공용모듈이 대체하는 것 | {x['rep']} |")
        a(f"| 제품에 남는 것 | {x['keep']} |")
        a(f"| 제품 주입 값 | {x['inj']} |")
        a(f"| 기획·개발 정본 | [`common-modules/{m}.md`]({rel}/products/_platform-core/common-modules/{m}.md), [`_shared/modules/{m}.md`]({rel}/develop/_shared/modules/{m}.md) |")
        a('')
    if hold:
        a(f"### 2.{len(adopt) + 1} 보류한 모듈")
        a('')
        a('| 모듈 | 보류 이유 | 다시 검토할 때 |')
        a('|---|---|---|')
        for m in hold:
            x = d['mods'][m]
            a(f"| {m} | {x['why']} | {x['when']} |")
        a('')
    # 3
    a('## 3. DB 변경')
    a('')
    if v1 and d['domain']:
        a('V2 적용 후 개발 폴더 `supabase/migrations/`(파일 이름 규칙은 V2_RULES 3장):')
        a('')
        a('```')
        if key == 'admin-suite':
            for app in ('erp', 'sms', 'hms'):
                a(f'supabase/{app}/migrations/')
                a('  20261013000001_core_lite.sql')
                a('  20261013000150_compliance.sql          ← 추가')
                a(f'  20261013001000_{app}_domain.sql        ← 20261013000002에서 이름 변경')
        else:
            a('20261013000001_core_lite.sql')
            if key == 'local-news':
                a('20261013000002_tenant_theming.sql')
            for m in adopt:
                a(f'2026101300{MODS[m][0]}_{m}.sql'.ljust(40) + ' ← 추가(패키지 변환본)')
            doms = [f for f in d['domain'] if '(유지)' not in f]
            for i, f in enumerate(doms):
                base = re.sub(r'^\d+_', '', f)
                a(f'2026101300{1000 + i}_{base}'.ljust(40) + f' ← {f[:14]}에서 이름 변경')
        a('```')
        a('')
    a('| 대상 | 변경 |')
    a('|---|---|')
    for t, c in d['db']:
        a(f'| {t} | {c} |')
    a('')
    # 4
    a('## 4. 작업 계획 변경')
    a('')
    a('### 4.1 V2 작업 (06장 2절 표 맨 아래에 추가)')
    a('')
    a('| ID | 내용 | 웨이브 | 선행 | 모델 | 수용 기준 |')
    a('|---|---|---|---|---|---|')
    rows = []  # (웨이브 순서, 키, 내용, 선행 키 목록 또는 문자열, 모델, 수용 기준, 웨이브 표시)

    def widx(w):
        return order.index(w) if w in order else (-1 if w == 'W0' else 99)
    for m in adopt:
        x = d['mods'][m]
        deps = x.get('deps', [])
        waves = [wave_of[t] for t in deps if t in wave_of]
        if waves and order:
            w = min(waves, key=widx)
        else:
            w = 'W1' if m == 'compliance' else ('06장 작성 때' if not v1 else 'W2')
        wtxt = f"{w} 맨 앞" if v1 else w
        after = ', '.join(deps) if deps else '-'
        kind = '' if x['st'] == '채택' else x['st'] + ': '
        pre = ['sql'] if key == 'local-news' else []
        if x.get('role') == '기준 구현':
            if key == 'local-news':  # DB를 W0에 한 번에 적용하므로 SQL은 W0에 먼저
                rows.append((widx('W0'), 'b_' + m, f"`@nomad/{m}` v0.x 구현(`nomad-modules` 저장소). SQL·스모크는 W0, 서버·UI는 적용 웨이브까지", 'W0 시작', BUILD_MODEL.get(m, 'Opus'), f"`_shared/modules/{m}.md` 3장 전부, 계약 테스트 녹색", 'W0 → ' + wtxt))
            else:
                rows.append((widx(w), 'b_' + m, f"`@nomad/{m}` v0.x 구현(`nomad-modules` 저장소)", 'W0 완료', BUILD_MODEL.get(m, 'Opus'), f"`_shared/modules/{m}.md` 3장 전부, 계약 테스트 녹색", wtxt))
            rows.append((widx(w), 'a_' + m, f"{m} 적용({kind}SQL 변환본, 주입 파일, seed, 어댑터)", ['b_' + m] + pre, 'Sonnet', f"`_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: {after}", wtxt))
        else:
            rows.append((widx(w), 'a_' + m, f"{m} 적용({kind}SQL 변환본, 주입 파일, seed, 어댑터)", pre or f"W0 완료, `@nomad/{m}` 출시", 'Sonnet', f"`_shared/modules/README.md` 5.2절 1~7번. 뒤 작업: {after}", wtxt))
    if key == 'local-news':
        rows.append((widx('W0'), 'sql', '`2500_news.sql`·모놀리스 `0003`을 확장 표만 남기도록 다시 작성(공용모듈 7개 변환본을 앞에), 스모크 재배치', [r[1] for r in rows if r[1].startswith('b_')], 'Fable', 'SQL 체커 정순·역순, 제품 스모크 + 모듈 스모크 녹색', 'W0'))
    if adopt:
        rows.append((999, 'final', 'V2 전환 점검: 모듈 계약 테스트를 CI에 연결, 자체 구현 잔재 검사', [r[1] for r in rows if r[1].startswith('a_')], 'Sonnet', '제품 E2E 녹색, 공용모듈로 옮긴 표·함수를 제품 코드가 직접 쓰는 곳 0', 'E2E 작업과 같은 웨이브'))
    rows.sort(key=lambda r: r[0])
    ids = {r[1]: f'{pfx}-V2-{i + 1:02d}' for i, r in enumerate(rows)}
    for r in rows:
        pre = r[3] if isinstance(r[3], str) else (', '.join(sorted(ids[k] for k in r[3])) or '-')
        a(f"| {ids[r[1]]} | {r[2]} | {r[6]} | {pre} | {r[4]} | {r[5]} |")
    a('')
    a('### 4.2 V1 작업 변경')
    a('')
    if d['changes']:
        a('| V1 작업 | 작업명(06장) | 변경 | 내용 |')
        a('|---|---|---|---|')
        for t, k, c in d['changes']:
            a(f"| {pfx}-06-{t} | {short(titles.get(t, '(06장 확인)'))} | {k} | {c} |")
    else:
        a('V1 작업 변경 없음(06장 작성 때 반영).')
    a('')
    a('변경 종류(축소·대체·연결)의 뜻과 06장 반영 방법은 V2_RULES 4장. 바뀐 V1 작업의 선행 조건에 해당 V2 적용 작업 ID를 더합니다.')
    a('')
    # 5
    a('## 5. 디렉토리와 주입 파일')
    a('')
    a('```')
    for m in adopt:
        a(f'src/lib/{m}/index.ts'.ljust(34) + f'createModule({{ appId: \'{d["app"].split(",")[0]}\', ... }}) — 2.{adopt.index(m) + 1}절 주입 값')
    if 'search' in adopt:
        a('src/lib/search/adapters/'.ljust(34) + 'toSearchDocument 어댑터(색인 대상마다 1개)')
    if 'editorial' in adopt:
        a('src/lib/editorial/guards.ts'.ljust(34) + '제품 게시 가드 함수 등록')
    a('supabase/seed.sql'.ljust(34) + '<스키마>.settings 행, 정책 문서 초안, 프리셋')
    a('```')
    a('')
    a('공용모듈 패키지 코드와 변환본 SQL은 고치지 않습니다. 필요한 변경은 `nomad-modules` 저장소에 요청합니다.')
    a('')
    # 6
    a('## 6. 검증 추가 항목')
    a('')
    a('- [ ] `supabase db reset` 후 제품 RLS 스모크 + 채택 모듈 스모크 녹색')
    a('- [ ] 채택 모듈 계약 테스트가 제품 CI에서 녹색')
    for m in adopt:
        chk = {
            'compliance': '가입·폼 제출 때 동의 기록 1행, 정책 새 버전 게시 후 재동의 화면, 푸터 사업자 정보 표시',
            'media': '같은 파일 두 번 업로드 시 같은 자산, 사본 프리셋 생성, 사용 중 자산 삭제 거부(`MD003`)',
            'editorial': 'AI·service 주체 게시 거부(`ED002`), 예약 게시가 재시작 후에도 실행, 게시 후 캐시 무효화',
            'community': '비회원 글·비밀번호 삭제, 금칙어 3동작, 신고 → 임시조치 → 기한 처리',
            'search': '비공개 문서가 anon 결과에 0건, 시험 질의 세트 정확도',
            'membership': '최종 이용자가 직원 표 0행, 테스트 키로 단건·정기·환불, 웹훅 중복 1회 반영',
            'ads': '라벨 없는 소재 승인 거부, 광고 없는 슬롯 높이 유지(CLS 0.1 이하), 클릭 토큰 위조 거부',
        }[m]
        a(f'- [ ] {m}: {chk}')
    a('- [ ] 공용모듈로 옮긴 제품 표·컬럼을 직접 읽거나 쓰는 코드 0(검색: 3장 "대상" 열 이름)')
    a('')
    # 7
    a('## 7. 결정 필요')
    a('')
    a('| ID | 결정 | 권고 |')
    a('|---|---|---|')
    a('| CMX-1~4 | 공용화 시점, DB 번호 재배정, 검색 엔진, 최종 이용자 결제 수취 | `products/_platform-core/common-modules/README.md` 6장 |')
    for i, q, r in d['dec']:
        a(f'| {i} | {q} | {r} |')
    a('')
    return '\n'.join(L)


STAGE_ORDER = ['1', '2', '2 이후', '3', '4', '5', '6', '코어 이후(설치형)']


def gen_index():
    L = []
    a = L.append
    a('# develop_V2 — 공용모듈을 쓰는 제품별 개발서')
    a('')
    a('작성일 2026-10-15. local-news 기획에서 꺼낸 공용모듈 7개(compliance, media, community, search, membership, ads, editorial)를 사용해 각 제품을 개발하는 방법을 제품마다 정리했습니다. '
      '`develop/`(V1)의 설치 스크립트·개발 묶음·안내서는 그대로 쓰고, 이 폴더의 개발서는 **공용모듈 때문에 바뀌는 부분**(채택 모듈, DB 순서, 추가 작업, 축소·대체되는 V1 작업, 주입 값, 검증)만 다룹니다.')
    a('')
    a('| 문서 | 내용 |')
    a('|---|---|')
    a('| [`_shared/V2_RULES.md`](_shared/V2_RULES.md) | V2 공통 규칙: V1과의 관계, DB 파일 순서·이름, V2 작업 만드는 법, 요청 프롬프트, 공용모듈 저장소가 없을 때 |')
    a('| [`_shared/tools/gen_v2.py`](_shared/tools/gen_v2.py) | 제품별 개발서와 이 색인을 만드는 스크립트. 06장을 고친 뒤 다시 실행하면 V2 작업 웨이브가 따라 바뀝니다 |')
    a('| `products/_platform-core/common-modules/` | 공용모듈 기획서(무엇을 만드는가)와 16개 제품 적용표 |')
    a('| `develop/_shared/modules/` | 공용모듈 개발 지시서(패키지를 어떻게 만드는가) |')
    a('')
    a('## 1. 제품별 개발서')
    a('')
    a('| 개발 단계 | 제품 | V2 개발서 | 채택 공용모듈 | 이 제품이 만드는 패키지(기준 구현) | V2 작업 수 | 바뀌는 V1 작업 수 |')
    a('|---|---|---|---|---|---|---|')
    keys = sorted(PRODUCTS, key=lambda k: (STAGE_ORDER.index(PRODUCTS[k]['stage']), k))
    for k in keys:
        d = PRODUCTS[k]
        adopt = [m for m in MODS if m in d['mods'] and d['mods'][m]['st'] != '보류']
        builds = [m for m in adopt if d['mods'][m].get('role') == '기준 구현']
        nv2 = len(adopt) + len(builds) + (1 if adopt else 0) + (1 if k == 'local-news' else 0)
        lab = [m if d['mods'][m]['st'] == '채택' else '%s(부분)' % m for m in adopt]
        a(f"| {d['stage']} | {k} | [`{k}_develop_v2.md`]({k}/{k}_develop_v2.md) | {', '.join(lab)} | {', '.join(builds) or '-'} | {nv2} | {len(d['changes'])} |")
    a('')
    a('## 2. 공용모듈이 만들어지는 순서')
    a('')
    a('패키지는 그 모듈을 처음 쓰는 제품(기준 구현)이 `nomad-modules` 저장소에서 함께 만들고, 뒤 제품은 출시된 버전을 설치만 합니다.')
    a('')
    a('| 모듈 | 기준 구현 제품 | 다음에 쓰는 제품 |')
    a('|---|---|---|')
    for m in MODS:
        b = [k for k in keys if PRODUCTS[k]['mods'].get(m, {}).get('role') == '기준 구현']
        u = [k for k in keys if PRODUCTS[k]['mods'].get(m, {}).get('st') in ('채택', '부분 채택') and k not in b]
        a(f"| {m} | {', '.join(b) or '-'} | {', '.join(u) or '-'} |")
    a('')
    a('compliance는 website-floria가 만들고 study-note가 두 번째로 적용해 v1.0을 검증합니다. media는 flora-publishing, editorial은 nomad-blog, community는 microweb-studio, search·membership·ads는 local-news가 만듭니다. 기준 구현 제품보다 먼저 개발하는 제품이 그 모듈을 쓰려면 V1 방식으로 만들고 나중에 전환합니다(V2_RULES 6장).')
    a('')
    a('## 3. 사용 순서')
    a('')
    a('| 순서 | 할 일 |')
    a('|---|---|')
    a('| 1 | V1 안내서(`develop/<제품>/<제품>_develop.md`) 0~6장으로 개발 폴더를 만든다 |')
    a('| 2 | 이 폴더의 `<제품>/<제품>_develop_v2.md` 2~4장을 보고 공용모듈 SQL·작업을 반영한다 |')
    a('| 3 | V1 안내서 8~10장 사이클로 웨이브를 진행한다(V2 작업은 해당 웨이브 맨 앞) |')
    a('| 4 | 제품 V2 개발서 6장의 검증 항목을 완료 정의에 더한다 |')
    a('')
    return '\n'.join(L)


def main():
    for key, d in PRODUCTS.items():
        p = os.path.join(OUT, key, f'{key}_develop_v2.md')
        os.makedirs(os.path.dirname(p), exist_ok=True)
        io.open(p, 'w', encoding='utf-8', newline='').write(gen(key, d))
        print('작성', os.path.relpath(p, ROOT))
    io.open(os.path.join(OUT, 'README.md'), 'w', encoding='utf-8', newline='').write(gen_index())
    print('작성 develop_V2/README.md')


if __name__ == '__main__':
    main()
