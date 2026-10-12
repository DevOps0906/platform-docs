-- =====================================================================
-- 0007_core_function_privileges.sql
-- core 함수의 PUBLIC EXECUTE 회수. 반드시 core 마이그레이션(0000~0006) 맨 뒤에 둔다.
--
-- 이유
--   PostgreSQL은 함수를 만들 때 PUBLIC에 EXECUTE를 기본 부여한다.
--   0000의 `alter default privileges in schema core revoke execute on functions from public`은
--   스키마 단위 기본 권한이라 이 전역 기본값을 없애지 못한다(스키마 단위 설정은 권한을 더할 수만 있다).
--   그 결과 명시적 revoke가 없던 core 함수 대부분을 anon/authenticated가 호출할 수 있었다.
--   SECURITY DEFINER 안에서 is_privileged_session()은 항상 true라서, 서비스 전용 함수는
--   EXECUTE 권한이 유일한 잠금이다(purge_organization, confirm_payment_order,
--   on_signup_app_bootstrap, enqueue_job/claim_jobs/fail_job 등).
--
-- 효과
--   - PUBLIC 항목만 회수한다. 0000~0006에서 명시적으로 준 authenticated/anon/service_role
--     권한은 별도 ACL 항목이라 유지된다.
--   - 트리거 함수는 발동 시 EXECUTE를 검사하지 않으므로 영향이 없다.
--   - 이후 core에 함수를 추가하는 마이그레이션도 같은 revoke를 끝에 넣거나, 함수마다
--     `revoke execute on function ... from public`을 명시한다(DB_CONVENTIONS 참조).
-- 선행: 0000 ~ 0006
-- =====================================================================

revoke execute on all functions in schema core from public;

-- service_role은 0000의 default privileges로 받았지만, 명시해 두면 순서와 무관하게 안전하다.
grant execute on all functions in schema core to service_role;
