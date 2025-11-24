# Feature Diff Report: common

Generated: 2025-11-24 17:19:17.426614

---

## 📊 Executive Summary

### File Structure
- **Total Files**: 311
- **Common Files**: 0
- **Project A Only**: 311
- **Project B Only**: 0

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

### Common Files (0)

*No common files found*

### Project A Only (311)

Path: `../good-teacher/feature/common`

- `settings/test/src/settings_test.dart`
- `settings/lib/settings.dart`
- `settings/lib/src/di/injector.dart`
- `settings/lib/src/di/injector.module.dart`
- `settings/lib/src/di/di.dart`
- `settings/lib/src/route/settings_route.dart`
- `settings/lib/src/route/route.dart`
- `settings/lib/src/route/settings_route.g.dart`
- `settings/lib/src/data/repository/mixins/settings_openapi_mixin.dart`
- `settings/lib/src/data/repository/mixins/mixins.dart`
- `settings/lib/src/data/repository/settings_repository.dart`
- `settings/lib/src/data/repository/repository.dart`
- `settings/lib/src/data/data.dart`
- `settings/lib/src/data/local/settings_database.g.dart`
- `settings/lib/src/data/local/tables/settings_table.dart`
- `settings/lib/src/data/local/tables/tables.dart`
- `settings/lib/src/data/local/local.dart`
- `settings/lib/src/data/local/dao/dao.dart`
- `settings/lib/src/data/local/dao/settings_dao.g.dart`
- `settings/lib/src/data/local/dao/settings_dao.dart`
- `settings/lib/src/data/local/settings_database.dart`
- `settings/lib/src/domain/repository/i_settings_repository.dart`
- `settings/lib/src/domain/repository/repository.dart`
- `settings/lib/src/domain/entity/settings.freezed.dart`
- `settings/lib/src/domain/entity/settings.g.dart`
- `settings/lib/src/domain/entity/entity.dart`
- `settings/lib/src/domain/entity/settings.dart`
- `settings/lib/src/domain/domain.dart`
- `settings/lib/src/domain/usecase/update_settings.dart`
- `settings/lib/src/domain/usecase/usecase.dart`
- `settings/lib/src/presentation/page/page.dart`
- `settings/lib/src/presentation/page/settings_page.dart`
- `settings/lib/src/presentation/widget/theme_icon_button.dart`
- `settings/lib/src/presentation/widget/widget.dart`
- `settings/lib/src/presentation/widget/toggle_card.dart`
- `settings/lib/src/presentation/widget/info_card.dart`
- `settings/lib/src/presentation/presentation.dart`
- `settings/lib/src/presentation/bloc/settings/settings_bloc.dart`
- `settings/lib/src/presentation/bloc/settings/settings_state.dart`
- `settings/lib/src/presentation/bloc/settings/settings_event.dart`
- `settings/lib/src/presentation/bloc/bloc.dart`
- `settings/.dart_tool/build/entrypoint/build.dart`
- `extra_info/test/src/extra_info_test.dart`
- `extra_info/lib/extra_info.dart`
- `extra_info/lib/src/di/injector.dart`
- `extra_info/lib/src/di/injector.module.dart`
- `extra_info/lib/src/di/di.dart`
- `extra_info/lib/src/route/route.dart`
- `extra_info/lib/src/route/extra_info_route.dart`
- `extra_info/lib/src/route/extra_info_route.g.dart`
- `extra_info/lib/src/data/repository/extra_info_repository.dart`
- `extra_info/lib/src/data/repository/mixins/mixins.dart`
- `extra_info/lib/src/data/repository/mixins/extra_info_openapi_mixin.dart`
- `extra_info/lib/src/data/repository/repository.dart`
- `extra_info/lib/src/data/data.dart`
- `extra_info/lib/src/data/local/tables/user_extra_infos_table.dart`
- `extra_info/lib/src/data/local/tables/tables.dart`
- `extra_info/lib/src/data/local/local.dart`
- `extra_info/lib/src/data/local/extra_info_database.g.dart`
- `extra_info/lib/src/data/local/dao/user_extra_info_dao.g.dart`
- `extra_info/lib/src/data/local/dao/user_extra_info_dao.dart`
- `extra_info/lib/src/data/local/dao/dao.dart`
- `extra_info/lib/src/data/local/extra_info_database.dart`
- `extra_info/lib/src/domain/repository/i_extra_info_repository.dart`
- `extra_info/lib/src/domain/repository/repository.dart`
- `extra_info/lib/src/domain/entity/user_extra_info.dart`
- `extra_info/lib/src/domain/entity/entity.dart`
- `extra_info/lib/src/domain/failure/failure.dart`
- `extra_info/lib/src/domain/failure/extra_info_failure_messages.dart`
- `extra_info/lib/src/domain/failure/extra_info_failure.dart`
- `extra_info/lib/src/domain/domain.dart`
- `extra_info/lib/src/domain/usecase/create_user_extra_info_usecase.dart`
- `extra_info/lib/src/domain/usecase/extra_info.dart`
- `extra_info/lib/src/domain/usecase/get_user_extra_info_usecase.dart`
- `extra_info/lib/src/domain/usecase/delete_user_extra_info_usecase.dart`
- `extra_info/lib/src/domain/usecase/update_user_extra_info_usecase.dart`
- `extra_info/lib/src/domain/usecase/usecase.dart`
- `extra_info/lib/src/domain/exception/exception.dart`
- `extra_info/lib/src/domain/exception/extra_info_exception.dart`
- `extra_info/lib/src/presentation/page/page.dart`
- `extra_info/lib/src/presentation/page/extra_info_page.dart`
- `extra_info/lib/src/presentation/presentation.dart`
- `extra_info/lib/src/presentation/widgets/widgets.dart`
- `extra_info/lib/src/presentation/widgets/user_extra_info_form.dart`
- `extra_info/lib/src/presentation/bloc/extra_info/extra_info_event.dart`
- `extra_info/lib/src/presentation/bloc/extra_info/extra_info_state.dart`
- `extra_info/lib/src/presentation/bloc/extra_info/extra_info_bloc.dart`
- `extra_info/lib/src/presentation/bloc/bloc.dart`
- `extra_info/.dart_tool/build/entrypoint/build.dart`
- `splash/test/src/splash_test.dart`
- `splash/lib/splash.dart`
- `splash/lib/src/route/splash_route.g.dart`
- `splash/lib/src/route/splash_route.dart`
- `splash/lib/src/route/route.dart`
- `splash/lib/src/util/platform_helper.dart`
- `splash/lib/src/util/util.dart`
- `splash/lib/src/util/web_platform_stub.dart`
- `splash/lib/src/utils/platform_helper.dart`
- `splash/lib/src/utils/web_platform_stub.dart`
- `splash/lib/src/data/repository/mixins/mixins.dart`
- `splash/lib/src/data/repository/mixins/splash_openapi_mixin.dart`
- `splash/lib/src/data/repository/repository.dart`
- `splash/lib/src/data/repository/splash_repository.dart`
- `splash/lib/src/data/data.dart`
- `splash/lib/src/domain/interface/interface.dart`
- `splash/lib/src/domain/interface/i_splash_repository.dart`
- `splash/lib/src/domain/domain.dart`
- `splash/lib/src/presentation/page/page.dart`
- `splash/lib/src/presentation/page/splash_page.dart`
- `splash/lib/src/presentation/widget/splash_widget.dart`
- `splash/lib/src/presentation/widget/widget.dart`
- `splash/lib/src/presentation/presentation.dart`
- `splash/lib/src/presentation/stub/stub.dart`
- `splash/lib/src/presentation/stub/web_platform_stub.dart`
- `splash/.dart_tool/build/entrypoint/build.dart`
- `auth/test/src/unit/usecase/sign_in_with_annoymously_test.mocks.dart`
- `auth/test/src/unit/usecase/launch_naver_login_test.dart`
- `auth/test/src/unit/usecase/sign_in_with_apple_test.dart`
- `auth/test/src/unit/usecase/sign_in_with_annoymously_test.dart`
- `auth/test/src/unit/usecase/launch_naver_login_test.mocks.dart`
- `auth/test/src/unit/usecase/sign_in_with_kakao_test.mocks.dart`
- `auth/test/src/unit/usecase/sign_in_with_kakao_test.dart`
- `auth/test/src/unit/usecase/sign_in_with_apple_test.mocks.dart`
- `auth/test/src/unit/usecase/sign_in_with_naver_test.mocks.dart`
- `auth/test/src/unit/usecase/sign_in_with_naver_test.dart`
- `auth/test/src/unit/usecase/sign_in_with_google_test.dart`
- `auth/test/src/unit/usecase/sign_in_with_google_test.mocks.dart`
- `auth/test/src/mock/firebase_auth_mock.dart`
- `auth/test/src/mock/set_up_mocks.dart`
- `auth/test/src/mock/firebase_crashlytics_mock.dart`
- `auth/test/src/mock/path_provider_mock.dart`
- `auth/test/src/mock/package_info_mock.dart`
- `auth/test/src/mock/mock.dart`
- `auth/test/src/mock/mock_url_launcher_platform.dart`
- `auth/test/src/auth_test.dart`
- `auth/lib/auth.dart`
- `auth/lib/src/di/injector.dart`
- `auth/lib/src/di/injector.module.dart`
- `auth/lib/src/di/di.dart`
- `auth/lib/src/route/auth_route.dart`
- `auth/lib/src/route/route.dart`
- `auth/lib/src/route/auth_route.g.dart`
- `auth/lib/src/utils/permission_utils.dart`
- `auth/lib/src/utils/utils.dart`
- `auth/lib/src/utils/auth_utils.dart`
- `auth/lib/src/utils/auth_init.dart`
- `auth/lib/src/utils/auth_validators.dart`
- `auth/lib/src/data/repository/mixins/auth_openapi_mixin.dart`
- `auth/lib/src/data/repository/mixins/mixins.dart`
- `auth/lib/src/data/repository/auth_repository.dart`
- `auth/lib/src/data/repository/repository.dart`
- `auth/lib/src/data/data.dart`
- `auth/lib/src/data/local/tables/tables.dart`
- `auth/lib/src/data/local/tables/user_infos_table.dart`
- `auth/lib/src/data/local/local.dart`
- `auth/lib/src/data/local/auth_database.dart`
- `auth/lib/src/data/local/dao/user_info_dao.g.dart`
- `auth/lib/src/data/local/dao/dao.dart`
- `auth/lib/src/data/local/dao/user_info_dao.dart`
- `auth/lib/src/data/local/auth_database.g.dart`
- `auth/lib/src/domain/repository/i_auth_repository.dart`
- `auth/lib/src/domain/repository/repository.dart`
- `auth/lib/src/domain/entity/login_response.dart`
- `auth/lib/src/domain/entity/app_permission.dart`
- `auth/lib/src/domain/entity/login_response.freezed.dart`
- `auth/lib/src/domain/entity/login_params.dart`
- `auth/lib/src/domain/entity/user_info.dart`
- `auth/lib/src/domain/entity/entity.dart`
- `auth/lib/src/domain/failure/failure.dart`
- `auth/lib/src/domain/failure/auth_error_messages.dart`
- `auth/lib/src/domain/failure/auth_failure.dart`
- `auth/lib/src/domain/domain.dart`
- `auth/lib/src/domain/usecase/social_login_usecase.dart`
- `auth/lib/src/domain/usecase/launch_naver_login_usecase.dart`
- `auth/lib/src/domain/usecase/sign_in_with_naver_usecase.dart`
- `auth/lib/src/domain/usecase/sign_in_with_id_usecase.dart`
- `auth/lib/src/domain/usecase/check_duplicated_id_usecase.dart`
- `auth/lib/src/domain/usecase/register_usecase.dart`
- `auth/lib/src/domain/usecase/login_usecase.dart`
- `auth/lib/src/domain/usecase/sign_in_with_apple_usecase.dart`
- `auth/lib/src/domain/usecase/sign_in_with_kakao_usecase.dart`
- `auth/lib/src/domain/usecase/update_user_profile_usecase.dart`
- `auth/lib/src/domain/usecase/verify_sms_code_usecase.dart`
- `auth/lib/src/domain/usecase/update_user_name_usecase.dart`
- `auth/lib/src/domain/usecase/sign_in_with_google_usecase.dart`
- `auth/lib/src/domain/usecase/get_my_info_usecase.dart`
- `auth/lib/src/domain/usecase/upload_profile_image_usecase.dart`
- `auth/lib/src/domain/usecase/get_user_usecase.dart`
- `auth/lib/src/domain/usecase/send_sms_verification_usecase.dart`
- `auth/lib/src/domain/usecase/sign_out_usecase.dart`
- `auth/lib/src/domain/usecase/usecase.dart`
- `auth/lib/src/domain/usecase/sign_in_with_anonymously_usecase.dart`
- `auth/lib/src/domain/exception/auth_exception.dart`
- `auth/lib/src/domain/exception/exception.dart`
- `auth/lib/src/presentation/page/signup_phone_typing_page.dart`
- `auth/lib/src/presentation/page/signup_page.dart`
- `auth/lib/src/presentation/page/page.dart`
- `auth/lib/src/presentation/page/signup_complete_page.dart`
- `auth/lib/src/presentation/page/login_page.dart`
- `auth/lib/src/presentation/page/sms_verification_page.dart`
- `auth/lib/src/presentation/page/signup_sms_complete_page.dart`
- `auth/lib/src/presentation/page/login_with_id_page.dart`
- `auth/lib/src/presentation/route/route_navigator_keys.dart`
- `auth/lib/src/presentation/route/route.dart`
- `auth/lib/src/presentation/route/route_refresh_listener.dart`
- `auth/lib/src/presentation/presentation.dart`
- `auth/lib/src/presentation/widgets/auth_divided_buttons.dart`
- `auth/lib/src/presentation/widgets/auth_input_field.dart`
- `auth/lib/src/presentation/widgets/auth_permission_dialog.dart`
- `auth/lib/src/presentation/widgets/widgets.dart`
- `auth/lib/src/presentation/widgets/auth_radio_tab.dart`
- `auth/lib/src/presentation/widgets/terms_agreement_bottom_sheet.dart`
- `auth/lib/src/presentation/widgets/signup/user_id_step.dart`
- `auth/lib/src/presentation/widgets/signup/member_type_step.dart`
- `auth/lib/src/presentation/widgets/signup/org_name_step.dart`
- `auth/lib/src/presentation/widgets/signup/org_type_step.dart`
- `auth/lib/src/presentation/widgets/signup/password_step.dart`
- `auth/lib/src/presentation/widgets/signup/name_step.dart`
- `auth/lib/src/presentation/widgets/signup/permissions_step.dart`
- `auth/lib/src/presentation/widgets/auth_tooltip.dart`
- `auth/lib/src/presentation/widgets/auth_validation_chip.dart`
- `auth/lib/src/presentation/widgets/auth_banner.dart`
- `auth/lib/src/presentation/widgets/auth_validate_dialog.dart`
- `auth/lib/src/presentation/widgets/auth_hyperlink_button.dart`
- `auth/lib/src/presentation/widgets/social_login_buttons.dart`
- `auth/lib/src/presentation/widgets/auth_permission_item.dart`
- `auth/lib/src/presentation/widgets/auth_action_button.dart`
- `auth/lib/src/presentation/widgets/social_login_button.dart`
- `auth/lib/src/presentation/bloc/sms_verification/sms_verification_state.dart`
- `auth/lib/src/presentation/bloc/sms_verification/sms_verification_bloc.dart`
- `auth/lib/src/presentation/bloc/sms_verification/sms_verification_event.dart`
- `auth/lib/src/presentation/bloc/auth/auth_event.dart`
- `auth/lib/src/presentation/bloc/auth/auth_bloc.dart`
- `auth/lib/src/presentation/bloc/auth/auth_state.dart`
- `auth/lib/src/presentation/bloc/signup/signup_event.dart`
- `auth/lib/src/presentation/bloc/signup/signup_bloc.dart`
- `auth/lib/src/presentation/bloc/signup/signup_state.dart`
- `auth/lib/src/presentation/bloc/bloc.dart`
- `auth/lib/src/presentation/bloc/login/login_bloc.dart`
- `auth/lib/src/presentation/bloc/login/login_event.dart`
- `auth/lib/src/presentation/bloc/login/login_state.dart`
- `auth/lib/src/src.dart`
- `auth/.dart_tool/build/entrypoint/build.dart`
- `life/test/src/app_core_test.dart`
- `life/lib/life.dart`
- `life/lib/src/di/injector.dart`
- `life/lib/src/di/injector.module.dart`
- `life/lib/src/di/di.dart`
- `life/lib/src/data/repository/local_storage_repository.dart`
- `life/lib/src/data/repository/mixins/user_openapi_mixin.dart`
- `life/lib/src/data/repository/mixins/mixins.dart`
- `life/lib/src/data/repository/repository.dart`
- `life/lib/src/data/repository/user_repository.dart`
- `life/lib/src/data/repository/remote_config_repository.dart`
- `life/lib/src/data/data.dart`
- `life/lib/src/data/local/tables/users_table.dart`
- `life/lib/src/data/local/tables/tables.dart`
- `life/lib/src/data/local/local.dart`
- `life/lib/src/data/local/life_database.dart`
- `life/lib/src/data/local/dao/user_dao.dart`
- `life/lib/src/data/local/dao/user_dao.g.dart`
- `life/lib/src/data/local/dao/dao.dart`
- `life/lib/src/data/local/life_database.g.dart`
- `life/lib/src/data/model/enum.dart`
- `life/lib/src/data/model/model.dart`
- `life/lib/src/domain/interface/i_user_repository.dart`
- `life/lib/src/domain/interface/i_remote_config_repository.dart`
- `life/lib/src/domain/interface/interface.dart`
- `life/lib/src/domain/interface/i_local_storage_repository.dart`
- `life/lib/src/domain/entity/user.dart`
- `life/lib/src/domain/entity/entity.dart`
- `life/lib/src/domain/domain.dart`
- `life/lib/src/domain/usecase/get_blocked_versions_usecase.dart`
- `life/lib/src/domain/usecase/update_device_usecase.dart`
- `life/lib/src/domain/usecase/usecase.dart`
- `life/lib/src/domain/bloc/app/app_cubit.dart`
- `life/lib/src/domain/bloc/app/app_state.dart`
- `life/lib/src/domain/bloc/version/version_state.dart`
- `life/lib/src/domain/bloc/version/version_cubit.dart`
- `life/lib/src/domain/bloc/theme/theme_bloc.dart`
- `life/lib/src/domain/bloc/bloc.dart`
- `life/lib/src/domain/bloc/hidable/hidable_bloc.dart`
- `life/lib/src/domain/bloc/app_life_cycle/app_life_cycle_bloc.dart`
- `life/lib/src/domain/bloc/app_life_cycle/app_life_cycle_state.dart`
- `life/.dart_tool/build/entrypoint/build.dart`
- `withdraw/test/src/withdraw_test.dart`
- `withdraw/lib/withdraw.dart`
- `withdraw/lib/src/di/injector.dart`
- `withdraw/lib/src/di/injector.module.dart`
- `withdraw/lib/src/di/di.dart`
- `withdraw/lib/src/route/withdraw_route.dart`
- `withdraw/lib/src/route/route.dart`
- `withdraw/lib/src/route/withdraw_route.g.dart`
- `withdraw/lib/src/data/repository/withdraw_repository.dart`
- `withdraw/lib/src/data/repository/mixins/withdraw_openapi_mixin.dart`
- `withdraw/lib/src/data/repository/mixins/mixins.dart`
- `withdraw/lib/src/data/repository/repository.dart`
- `withdraw/lib/src/data/data.dart`
- `withdraw/lib/src/domain/interface/i_withdraw_repository.dart`
- `withdraw/lib/src/domain/interface/interface.dart`
- `withdraw/lib/src/domain/domain.dart`
- `withdraw/lib/src/domain/usecase/withdraw_usecase.dart`
- `withdraw/lib/src/domain/usecase/usecase.dart`
- `withdraw/lib/src/presentation/page/page.dart`
- `withdraw/lib/src/presentation/page/withdraw_page.dart`
- `withdraw/lib/src/presentation/presentation.dart`
- `withdraw/lib/src/presentation/bloc/bloc.dart`
- `withdraw/lib/src/presentation/bloc/withdraw/withdraw_event.dart`
- `withdraw/lib/src/presentation/bloc/withdraw/withdraw_state.dart`
- `withdraw/lib/src/presentation/bloc/withdraw/withdraw_bloc.dart`
- `withdraw/.dart_tool/build/entrypoint/build.dart`

### Project B Only (0)

Path: ``

*All files are common or in Project A*

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

- **Add to Project B**: 311 files missing
  - Consider: settings/test/src/settings_test.dart, settings/lib/settings.dart, settings/lib/src/di/injector.dart...

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
