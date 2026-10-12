-- =====================================================================
-- admin-suite / hms 모놀리스 seed.sql
-- apps 1행('hms', 초대제), 계약형 기본 플랜 1행(온라인 결제 없음, Toss 절 제거), 검사 카탈로그.
-- 검사 정상 범위는 Hospital/src/lib/lab-ranges.ts 를 그대로 옮겼다(임상 검증 필요, 01_PRD 8절).
-- 병원 워크스페이스는 프로비저닝 스크립트(service_role)가 만든다. 환자/진료 데이터는 seed 에 넣지 않는다.
-- =====================================================================
insert into public.apps (id, name, schema_name, signup_policy, status) values
  ('hms', 'Admin Suite Hospital', 'hms', 'invite', 'active')
on conflict (id) do update set name = excluded.name, signup_policy = excluded.signup_policy, status = excluded.status;

insert into public.plans (app_id, code, name, price_krw, billing_interval, monthly_credits, signup_credits, carry_over, features, is_default, is_active, sort_order) values
  ('hms', 'contract', 'Contract', 0, 'none', 0, 0, false, '{"max_staff": 50, "phi_log_retention_days": 730, "export_xlsx": true}', true, true, 0)
on conflict (app_id, code) do update
  set name = excluded.name, features = excluded.features, is_default = excluded.is_default, is_active = excluded.is_active;

insert into public.lab_test_catalog (code, name, parameters) values
  ('CBC', 'CBC 혈액검사', '[
    {"key":"wbc","label":"WBC (백혈구)","unit":"x10^3/uL","min":4.0,"max":10.0},
    {"key":"rbc","label":"RBC (적혈구)","unit":"x10^6/uL","min":4.2,"max":5.4},
    {"key":"hgb","label":"HGB (헤모글로빈)","unit":"g/dL","min":12.0,"max":16.0},
    {"key":"hct","label":"HCT (헤마토크리트)","unit":"%","min":36.0,"max":48.0},
    {"key":"plt","label":"PLT (혈소판)","unit":"x10^3/uL","min":150,"max":400},
    {"key":"neut","label":"NEUT (호중구)","unit":"%","min":45.0,"max":75.0}]'),
  ('LFT', 'LFT 간기능', '[
    {"key":"alt","label":"ALT","unit":"U/L","min":7,"max":56},
    {"key":"ast","label":"AST","unit":"U/L","min":10,"max":40},
    {"key":"alp","label":"ALP","unit":"U/L","min":44,"max":147},
    {"key":"bilirubin","label":"총 빌리루빈","unit":"mg/dL","min":0.1,"max":1.2},
    {"key":"albumin","label":"알부민","unit":"g/dL","min":3.5,"max":5.0}]'),
  ('UA', '소변검사', '[
    {"key":"glucose","label":"포도당","unit":"mg/dL","min":0,"max":15},
    {"key":"protein","label":"단백질","unit":"mg/dL","min":0,"max":14},
    {"key":"ph","label":"pH","unit":"","min":4.5,"max":8.0}]')
on conflict (code) do update set name = excluded.name, parameters = excluded.parameters;
