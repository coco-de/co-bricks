# Feature Diff Report: auth

Generated: 2025-11-24 17:16:26.397620

---

## 📊 Executive Summary

### File Structure
- **Total Files**: 143
- **Common Files**: 86
- **Project A Only**: 42
- **Project B Only**: 15

### Interface Compatibility
- **Common Methods**: 0
- **Method Conflicts**: 0
- **Project A Methods**: 0
- **Project B Methods**: 0

### Implementation Quality
- **Winner**: N/A
- **Error Handling**: 0/100
- **Caching**: 0/100
- **Logging**: 0/100
- **Complexity**: 0/100

---

## 📁 File Structure Analysis

### Common Files (86)

- `test/src/unit/usecase/sign_in_with_annoymously_test.mocks.dart`
- `test/src/unit/usecase/launch_naver_login_test.dart`
- `test/src/unit/usecase/sign_in_with_apple_test.dart`
- `test/src/unit/usecase/sign_in_with_annoymously_test.dart`
- `test/src/unit/usecase/launch_naver_login_test.mocks.dart`
- `test/src/unit/usecase/sign_in_with_kakao_test.mocks.dart`
- `test/src/unit/usecase/sign_in_with_kakao_test.dart`
- `test/src/unit/usecase/sign_in_with_apple_test.mocks.dart`
- `test/src/unit/usecase/sign_in_with_naver_test.mocks.dart`
- `test/src/unit/usecase/sign_in_with_naver_test.dart`
- `test/src/unit/usecase/sign_in_with_google_test.dart`
- `test/src/unit/usecase/sign_in_with_google_test.mocks.dart`
- `test/src/mock/firebase_auth_mock.dart`
- `test/src/mock/set_up_mocks.dart`
- `test/src/mock/firebase_crashlytics_mock.dart`
- `test/src/mock/path_provider_mock.dart`
- `test/src/mock/package_info_mock.dart`
- `test/src/mock/mock.dart`
- `test/src/mock/mock_url_launcher_platform.dart`
- `test/src/auth_test.dart`
- `lib/auth.dart`
- `lib/src/di/injector.dart`
- `lib/src/di/injector.module.dart`
- `lib/src/di/di.dart`
- `lib/src/route/auth_route.dart`
- `lib/src/route/route.dart`
- `lib/src/route/auth_route.g.dart`
- `lib/src/utils/utils.dart`
- `lib/src/utils/auth_utils.dart`
- `lib/src/utils/auth_init.dart`
- `lib/src/data/repository/mixins/mixins.dart`
- `lib/src/data/repository/auth_repository.dart`
- `lib/src/data/repository/repository.dart`
- `lib/src/data/data.dart`
- `lib/src/data/local/tables/tables.dart`
- `lib/src/data/local/tables/user_infos_table.dart`
- `lib/src/data/local/local.dart`
- `lib/src/data/local/auth_database.dart`
- `lib/src/data/local/dao/user_info_dao.g.dart`
- `lib/src/data/local/dao/dao.dart`
- `lib/src/data/local/dao/user_info_dao.dart`
- `lib/src/data/local/auth_database.g.dart`
- `lib/src/domain/repository/i_auth_repository.dart`
- `lib/src/domain/repository/repository.dart`
- `lib/src/domain/entity/login_response.dart`
- `lib/src/domain/entity/login_params.dart`
- `lib/src/domain/entity/user_info.dart`
- `lib/src/domain/entity/entity.dart`
- `lib/src/domain/failure/failure.dart`
- `lib/src/domain/failure/auth_error_messages.dart`
- `lib/src/domain/failure/auth_failure.dart`
- `lib/src/domain/domain.dart`
- `lib/src/domain/usecase/social_login_usecase.dart`
- `lib/src/domain/usecase/launch_naver_login_usecase.dart`
- `lib/src/domain/usecase/sign_in_with_naver_usecase.dart`
- `lib/src/domain/usecase/login_usecase.dart`
- `lib/src/domain/usecase/sign_in_with_apple_usecase.dart`
- `lib/src/domain/usecase/sign_in_with_kakao_usecase.dart`
- `lib/src/domain/usecase/update_user_profile_usecase.dart`
- `lib/src/domain/usecase/update_user_name_usecase.dart`
- `lib/src/domain/usecase/sign_in_with_google_usecase.dart`
- `lib/src/domain/usecase/get_my_info_usecase.dart`
- `lib/src/domain/usecase/upload_profile_image_usecase.dart`
- `lib/src/domain/usecase/get_user_usecase.dart`
- `lib/src/domain/usecase/sign_out_usecase.dart`
- `lib/src/domain/usecase/usecase.dart`
- `lib/src/domain/usecase/sign_in_with_anonymously_usecase.dart`
- `lib/src/domain/exception/auth_exception.dart`
- `lib/src/domain/exception/exception.dart`
- `lib/src/presentation/page/page.dart`
- `lib/src/presentation/page/login_page.dart`
- `lib/src/presentation/route/route_navigator_keys.dart`
- `lib/src/presentation/route/route.dart`
- `lib/src/presentation/route/route_refresh_listener.dart`
- `lib/src/presentation/presentation.dart`
- `lib/src/presentation/widgets/widgets.dart`
- `lib/src/presentation/widgets/social_login_button.dart`
- `lib/src/presentation/bloc/auth/auth_event.dart`
- `lib/src/presentation/bloc/auth/auth_bloc.dart`
- `lib/src/presentation/bloc/auth/auth_state.dart`
- `lib/src/presentation/bloc/bloc.dart`
- `lib/src/presentation/bloc/login/login_bloc.dart`
- `lib/src/presentation/bloc/login/login_event.dart`
- `lib/src/presentation/bloc/login/login_state.dart`
- `lib/src/src.dart`
- `.dart_tool/build/entrypoint/build.dart`

### Project A Only (42)

Path: `../good-teacher/feature/common/auth`

- `lib/src/utils/permission_utils.dart`
- `lib/src/utils/auth_validators.dart`
- `lib/src/data/repository/mixins/auth_openapi_mixin.dart`
- `lib/src/domain/entity/app_permission.dart`
- `lib/src/domain/entity/login_response.freezed.dart`
- `lib/src/domain/usecase/sign_in_with_id_usecase.dart`
- `lib/src/domain/usecase/check_duplicated_id_usecase.dart`
- `lib/src/domain/usecase/register_usecase.dart`
- `lib/src/domain/usecase/verify_sms_code_usecase.dart`
- `lib/src/domain/usecase/send_sms_verification_usecase.dart`
- `lib/src/presentation/page/signup_phone_typing_page.dart`
- `lib/src/presentation/page/signup_page.dart`
- `lib/src/presentation/page/signup_complete_page.dart`
- `lib/src/presentation/page/sms_verification_page.dart`
- `lib/src/presentation/page/signup_sms_complete_page.dart`
- `lib/src/presentation/page/login_with_id_page.dart`
- `lib/src/presentation/widgets/auth_divided_buttons.dart`
- `lib/src/presentation/widgets/auth_input_field.dart`
- `lib/src/presentation/widgets/auth_permission_dialog.dart`
- `lib/src/presentation/widgets/auth_radio_tab.dart`
- `lib/src/presentation/widgets/terms_agreement_bottom_sheet.dart`
- `lib/src/presentation/widgets/signup/user_id_step.dart`
- `lib/src/presentation/widgets/signup/member_type_step.dart`
- `lib/src/presentation/widgets/signup/org_name_step.dart`
- `lib/src/presentation/widgets/signup/org_type_step.dart`
- `lib/src/presentation/widgets/signup/password_step.dart`
- `lib/src/presentation/widgets/signup/name_step.dart`
- `lib/src/presentation/widgets/signup/permissions_step.dart`
- `lib/src/presentation/widgets/auth_tooltip.dart`
- `lib/src/presentation/widgets/auth_validation_chip.dart`
- `lib/src/presentation/widgets/auth_banner.dart`
- `lib/src/presentation/widgets/auth_validate_dialog.dart`
- `lib/src/presentation/widgets/auth_hyperlink_button.dart`
- `lib/src/presentation/widgets/social_login_buttons.dart`
- `lib/src/presentation/widgets/auth_permission_item.dart`
- `lib/src/presentation/widgets/auth_action_button.dart`
- `lib/src/presentation/bloc/sms_verification/sms_verification_state.dart`
- `lib/src/presentation/bloc/sms_verification/sms_verification_bloc.dart`
- `lib/src/presentation/bloc/sms_verification/sms_verification_event.dart`
- `lib/src/presentation/bloc/signup/signup_event.dart`
- `lib/src/presentation/bloc/signup/signup_bloc.dart`
- `lib/src/presentation/bloc/signup/signup_state.dart`

### Project B Only (15)

Path: `../blueprint/feature/common/auth`

- `test/src/unit/usecase/get_user_usecase_test.dart`
- `test/src/unit/usecase/get_my_info_usecase_test.dart`
- `test/src/unit/usecase/update_user_name_usecase_test.dart`
- `test/src/unit/usecase/sign_out_usecase_test.dart`
- `test/src/unit/usecase/upload_profile_image_usecase_test.dart`
- `test/src/presentation/widget/social_login_button_test.dart`
- `test/src/presentation/bloc/auth_bloc_test.dart`
- `lib/src/data/repository/mixins/auth_serverpod_mixin.dart`
- `lib/src/data/cache/cache.dart`
- `lib/src/data/cache/user_info_cache_repository.dart`
- `lib/src/data/cache/user_info_cache_query.dart`
- `lib/src/data/cache/user_info_network_repository.dart`
- `lib/src/presentation/widgets/login_text_field.dart`
- `lib/src/presentation/widgets/login_form_field.dart`
- `.dart_tool/flutter_build/dart_plugin_registrant.dart`

---

## 🔌 Interface Comparison

### Common Methods (0)

*No common methods found*

### Project A Only Methods (0)

*All methods are common or in Project B*

### Project B Only Methods (0)

*All methods are common or in Project A*

---

## ⭐ Implementation Quality

### Recommendation: N/A

### Detailed Scores

| Metric | Project A | Details |
|--------|-----------|---------|
| Error Handling | 0/100 | Not analyzed |
| Caching | 0/100 | Not analyzed |
| Logging | 0/100 | Not analyzed |
| Complexity | 0/100 | Not analyzed |
| **Total** | **0/400** | |

### Analysis

**Error Handling (0/100)**

Not analyzed

**Caching (0/100)**

Not analyzed

**Logging (0/100)**

Not analyzed

**Complexity (0/100)**

Not analyzed

---

## 💡 Recommendations

### File Structure

- **Add to Project B**: 42 files missing
  - Consider: lib/src/utils/permission_utils.dart, lib/src/utils/auth_validators.dart, lib/src/data/repository/mixins/auth_openapi_mixin.dart...

- **Add to Project A**: 15 files missing
  - Consider: test/src/unit/usecase/get_user_usecase_test.dart, test/src/unit/usecase/get_my_info_usecase_test.dart, test/src/unit/usecase/update_user_name_usecase_test.dart...

### Quality Improvements

**Low scores needing attention:**
- Error Handling: 0/100
- Caching: 0/100
- Logging: 0/100
- Complexity: 0/100

### Overall Recommendation

Project N/A has better implementation quality.
Consider adopting patterns from Project N/A.

---

*Report generated by co-bricks diff detection engine*
