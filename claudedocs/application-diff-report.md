# Feature Diff Report: application

Generated: 2025-11-24 17:18:43.697753

---

## 📊 Executive Summary

### File Structure
- **Total Files**: 282
- **Common Files**: 219
- **Project A Only**: 8
- **Project B Only**: 55

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

### Common Files (219)

- `home/test/mocks/mocks.dart`
- `home/test/src/home_test.dart`
- `home/test/src/data/repository/home_repository_test.dart`
- `home/test/src/domain/usecase/home_test.dart`
- `home/test/src/presentation/blocs/home_bloc_test.dart`
- `home/test/src/presentation/pages/home_page_test.dart`
- `home/lib/home.dart`
- `home/lib/src/di/injector.dart`
- `home/lib/src/di/injector.module.dart`
- `home/lib/src/di/di.dart`
- `home/lib/src/route/route.dart`
- `home/lib/src/route/home_route.dart`
- `home/lib/src/route/home_route.g.dart`
- `home/lib/src/data/repository/mixins/mixins.dart`
- `home/lib/src/data/repository/home_repository.dart`
- `home/lib/src/data/repository/repository.dart`
- `home/lib/src/data/repository/factories/factories.dart`
- `home/lib/src/data/repository/factories/home_mock_data_factory.dart`
- `home/lib/src/data/cache/cache.dart`
- `home/lib/src/data/cache/home_feed_cache_query.dart`
- `home/lib/src/data/cache/home_feed_network_repository.dart`
- `home/lib/src/data/cache/home_feed_cache_repository.dart`
- `home/lib/src/data/data.dart`
- `home/lib/src/data/local/tables/home_banners_table.dart`
- `home/lib/src/data/local/tables/tables.dart`
- `home/lib/src/data/local/tables/home_feed_items_table.dart`
- `home/lib/src/data/local/home_database.g.dart`
- `home/lib/src/data/local/home_database.dart`
- `home/lib/src/data/local/local.dart`
- `home/lib/src/data/local/dao/home_banner_dao.dart`
- `home/lib/src/data/local/dao/home_banner_dao.g.dart`
- `home/lib/src/data/local/dao/home_feed_item_dao.dart`
- `home/lib/src/data/local/dao/dao.dart`
- `home/lib/src/data/local/dao/home_feed_item_dao.g.dart`
- `home/lib/src/domain/repository/repository.dart`
- `home/lib/src/domain/repository/i_home_repository.dart`
- `home/lib/src/domain/entity/paginated_home_feed_result.dart`
- `home/lib/src/domain/entity/home_feed_response.dart`
- `home/lib/src/domain/entity/home_banner.dart`
- `home/lib/src/domain/entity/home_feed_item.dart`
- `home/lib/src/domain/entity/entity.dart`
- `home/lib/src/domain/failure/failure.dart`
- `home/lib/src/domain/failure/home_failure_messages.dart`
- `home/lib/src/domain/domain.dart`
- `home/lib/src/domain/usecase/get_active_banners_usecase.dart`
- `home/lib/src/domain/usecase/get_home_feed_usecase.dart`
- `home/lib/src/domain/usecase/usecase.dart`
- `home/lib/src/domain/exception/exception.dart`
- `home/lib/src/domain/exception/home_exception.dart`
- `home/lib/src/presentation/page/page.dart`
- `home/lib/src/presentation/page/home_page.dart`
- `home/lib/src/presentation/widget/filter_chip_bar.dart`
- `home/lib/src/presentation/widget/feed_item_card.dart`
- `home/lib/src/presentation/widget/banner_carousel.dart`
- `home/lib/src/presentation/widget/widget.dart`
- `home/lib/src/presentation/presentation.dart`
- `home/lib/src/presentation/bloc/home/home_state.dart`
- `home/lib/src/presentation/bloc/home/home_bloc.dart`
- `home/lib/src/presentation/bloc/home/home_event.dart`
- `home/lib/src/presentation/bloc/home_feed/home_feed_event.dart`
- `home/lib/src/presentation/bloc/home_feed/home_feed_bloc.dart`
- `home/lib/src/presentation/bloc/home_feed/home_feed_state.dart`
- `home/lib/src/presentation/bloc/bloc.dart`
- `home/.dart_tool/build/entrypoint/build.dart`
- `mypage/test/mocks/mocks.dart`
- `mypage/test/src/mypage_test.dart`
- `mypage/test/src/data/repository/mypage_repository_test.dart`
- `mypage/test/src/presentation/blocs/mypage_bloc_test.dart`
- `mypage/test/src/presentation/pages/mypage_page_test.dart`
- `mypage/lib/mypage.dart`
- `mypage/lib/src/di/injector.dart`
- `mypage/lib/src/di/injector.module.dart`
- `mypage/lib/src/di/di.dart`
- `mypage/lib/src/route/mypage_route.dart`
- `mypage/lib/src/route/mypage_route.g.dart`
- `mypage/lib/src/route/route.dart`
- `mypage/lib/src/data/repository/mypage_repository.dart`
- `mypage/lib/src/data/repository/mixins/mixins.dart`
- `mypage/lib/src/data/repository/repository.dart`
- `mypage/lib/src/data/data.dart`
- `mypage/lib/src/domain/repository/i_mypage_repository.dart`
- `mypage/lib/src/domain/repository/repository.dart`
- `mypage/lib/src/domain/entity/entity.dart`
- `mypage/lib/src/domain/failure/failure.dart`
- `mypage/lib/src/domain/failure/mypage_failure.dart`
- `mypage/lib/src/domain/failure/mypage_failure_messages.dart`
- `mypage/lib/src/domain/domain.dart`
- `mypage/lib/src/domain/usecase/usecase.dart`
- `mypage/lib/src/domain/exception/exception.dart`
- `mypage/lib/src/domain/exception/mypage_exception.dart`
- `mypage/lib/src/presentation/page/mypage_page.dart`
- `mypage/lib/src/presentation/page/page.dart`
- `mypage/lib/src/presentation/presentation.dart`
- `mypage/lib/src/presentation/bloc/mypage/mypage_bloc.dart`
- `mypage/lib/src/presentation/bloc/mypage/mypage_event.dart`
- `mypage/lib/src/presentation/bloc/mypage/mypage_state.dart`
- `mypage/lib/src/presentation/bloc/bloc.dart`
- `mypage/.dart_tool/build/entrypoint/build.dart`
- `app_router/lib/app_router.dart`
- `app_router/lib/src/di/injector.dart`
- `app_router/lib/src/di/injector.module.dart`
- `app_router/lib/src/di/di.dart`
- `app_router/lib/src/route/app_route_guard.dart`
- `app_router/lib/src/route/app_route.dart`
- `app_router/lib/src/route/route.dart`
- `app_router/lib/src/route/app_routes.dart`
- `app_router/lib/src/route/app_router.dart`
- `app_router/lib/src/presentation/page/page.dart`
- `app_router/lib/src/presentation/page/app_router_page.dart`
- `app_router/lib/src/presentation/presentation.dart`
- `app_router/lib/src/presentation/bloc/router_event.dart`
- `app_router/lib/src/presentation/bloc/router_state.dart`
- `app_router/lib/src/presentation/bloc/router_bloc.dart`
- `app_router/lib/src/presentation/bloc/bloc.dart`
- `app_router/.dart_tool/build/entrypoint/build.dart`
- `community/test/mocks/mocks.dart`
- `community/test/src/data/repository/community_repository_test.dart`
- `community/test/src/domain/usecase/community_test.dart`
- `community/test/src/presentation/blocs/community_bloc_test.dart`
- `community/test/src/presentation/pages/community_page_test.dart`
- `community/test/src/community_test.dart`
- `community/lib/community.dart`
- `community/lib/src/di/injector.dart`
- `community/lib/src/di/injector.module.dart`
- `community/lib/src/di/di.dart`
- `community/lib/src/route/route.dart`
- `community/lib/src/route/community_route.g.dart`
- `community/lib/src/route/community_route.dart`
- `community/lib/src/data/repository/mixins/mixins.dart`
- `community/lib/src/data/repository/post_repository.dart`
- `community/lib/src/data/repository/community_repository.dart`
- `community/lib/src/data/repository/repository.dart`
- `community/lib/src/data/repository/comment_repository.dart`
- `community/lib/src/data/cache/comment_cache_repository.dart`
- `community/lib/src/data/cache/cache.dart`
- `community/lib/src/data/cache/comment_network_repository.dart`
- `community/lib/src/data/cache/post_list_cache_query.dart`
- `community/lib/src/data/cache/post_network_repository.dart`
- `community/lib/src/data/cache/post_cache_repository.dart`
- `community/lib/src/data/data.dart`
- `community/lib/src/data/local/community_database.g.dart`
- `community/lib/src/data/local/tables/comments_table.dart`
- `community/lib/src/data/local/tables/tables.dart`
- `community/lib/src/data/local/tables/posts_table.dart`
- `community/lib/src/data/local/local.dart`
- `community/lib/src/data/local/dao/comment_dao.dart`
- `community/lib/src/data/local/dao/dao.dart`
- `community/lib/src/data/local/dao/post_dao.g.dart`
- `community/lib/src/data/local/dao/comment_dao.g.dart`
- `community/lib/src/data/local/dao/post_dao.dart`
- `community/lib/src/data/local/community_database.dart`
- `community/lib/src/domain/repository/i_community_repository.dart`
- `community/lib/src/domain/repository/repository.dart`
- `community/lib/src/domain/entity/post.dart`
- `community/lib/src/domain/entity/post_list_result.dart`
- `community/lib/src/domain/entity/comment_list_result.dart`
- `community/lib/src/domain/entity/comment.dart`
- `community/lib/src/domain/entity/entity.dart`
- `community/lib/src/domain/failure/failure.dart`
- `community/lib/src/domain/failure/community_failure_messages.dart`
- `community/lib/src/domain/domain.dart`
- `community/lib/src/domain/usecase/get_post_detail_usecase.dart`
- `community/lib/src/domain/usecase/toggle_post_like_usecase.dart`
- `community/lib/src/domain/usecase/get_comments_usecase.dart`
- `community/lib/src/domain/usecase/get_posts_usecase.dart`
- `community/lib/src/domain/usecase/usecase.dart`
- `community/lib/src/domain/exception/exception.dart`
- `community/lib/src/domain/exception/community_exception.dart`
- `community/lib/src/presentation/page/page.dart`
- `community/lib/src/presentation/page/post_detail_page.dart`
- `community/lib/src/presentation/page/community_page.dart`
- `community/lib/src/presentation/page/post_create_page.dart`
- `community/lib/src/presentation/presentation.dart`
- `community/lib/src/presentation/widgets/widgets.dart`
- `community/lib/src/presentation/widgets/fleather_embed_builder.dart`
- `community/lib/src/presentation/widgets/post_card.dart`
- `community/lib/src/presentation/widgets/category_chip_bar.dart`
- `community/lib/src/presentation/widgets/fleather_image_toolbar.dart`
- `community/lib/src/presentation/bloc/bloc.dart`
- `community/lib/src/presentation/bloc/post_list/post_list_bloc.dart`
- `community/lib/src/presentation/bloc/post_list/post_list_state.dart`
- `community/lib/src/presentation/bloc/post_list/post_list_event.dart`
- `community/lib/src/presentation/bloc/community/community_event.dart`
- `community/lib/src/presentation/bloc/community/community_state.dart`
- `community/lib/src/presentation/bloc/community/community_bloc.dart`
- `community/.dart_tool/build/entrypoint/build.dart`
- `store/test/mocks/mocks.dart`
- `store/test/src/store_test.dart`
- `store/test/src/data/repository/store_repository_test.dart`
- `store/test/src/presentation/blocs/store_bloc_test.dart`
- `store/test/src/presentation/pages/store_page_test.dart`
- `store/lib/store.dart`
- `store/lib/src/di/injector.dart`
- `store/lib/src/di/injector.module.dart`
- `store/lib/src/di/di.dart`
- `store/lib/src/route/route.dart`
- `store/lib/src/route/store_route.dart`
- `store/lib/src/route/store_route.g.dart`
- `store/lib/src/data/repository/mixins/mixins.dart`
- `store/lib/src/data/repository/repository.dart`
- `store/lib/src/data/repository/store_repository.dart`
- `store/lib/src/data/data.dart`
- `store/lib/src/domain/repository/repository.dart`
- `store/lib/src/domain/repository/i_store_repository.dart`
- `store/lib/src/domain/entity/entity.dart`
- `store/lib/src/domain/failure/failure.dart`
- `store/lib/src/domain/failure/store_failure_messages.dart`
- `store/lib/src/domain/domain.dart`
- `store/lib/src/domain/usecase/usecase.dart`
- `store/lib/src/domain/exception/exception.dart`
- `store/lib/src/domain/exception/store_exception.dart`
- `store/lib/src/presentation/page/page.dart`
- `store/lib/src/presentation/page/store_page.dart`
- `store/lib/src/presentation/presentation.dart`
- `store/lib/src/presentation/bloc/bloc.dart`
- `store/lib/src/presentation/bloc/store/store_bloc.dart`
- `store/lib/src/presentation/bloc/store/store_event.dart`
- `store/lib/src/presentation/bloc/store/store_state.dart`
- `store/.dart_tool/build/entrypoint/build.dart`

### Project A Only (8)

Path: `../good-teacher/feature/application`

- `home/lib/src/data/repository/mixins/home_openapi_mixin.dart`
- `mypage/test/src/domain/usecase/mypage_test.dart`
- `mypage/lib/src/data/repository/mixins/mypage_openapi_mixin.dart`
- `mypage/lib/src/domain/usecase/mypage.dart`
- `community/lib/src/data/repository/mixins/community_openapi_mixin.dart`
- `store/test/src/domain/usecase/store_test.dart`
- `store/lib/src/data/repository/mixins/store_openapi_mixin.dart`
- `store/lib/src/domain/usecase/store.dart`

### Project B Only (55)

Path: `../blueprint/feature/application`

- `home/test/src/domain/usecase/get_home_feed_usecase_test.dart`
- `home/test/src/domain/usecase/get_active_banners_usecase_test.dart`
- `home/test/src/presentation/bloc/home_feed_bloc_test.dart`
- `home/lib/src/data/repository/mixins/home_serverpod_mixin.dart`
- `home/.dart_tool/flutter_build/dart_plugin_registrant.dart`
- `mypage/test/src/domain/usecase/mypage_usecase_test.dart`
- `mypage/lib/src/data/repository/mixins/mypage_serverpod_mixin.dart`
- `mypage/lib/src/data/cache/user_profile_cache_query.dart`
- `mypage/lib/src/data/cache/cache.dart`
- `mypage/lib/src/data/cache/user_profile_cache_repository.dart`
- `mypage/lib/src/data/cache/user_profile_network_repository.dart`
- `mypage/lib/src/data/local/tables/tables.dart`
- `mypage/lib/src/data/local/tables/user_profiles_table.dart`
- `mypage/lib/src/data/local/local.dart`
- `mypage/lib/src/data/local/mypage_database.g.dart`
- `mypage/lib/src/data/local/dao/user_profile_dao.dart`
- `mypage/lib/src/data/local/dao/dao.dart`
- `mypage/lib/src/data/local/dao/user_profile_dao.g.dart`
- `mypage/lib/src/data/local/mypage_database.dart`
- `mypage/lib/src/domain/entity/user_profile.dart`
- `mypage/lib/src/domain/usecase/refresh_user_profile_usecase.dart`
- `mypage/lib/src/domain/usecase/get_current_user_profile_usecase.dart`
- `mypage/lib/src/domain/usecase/update_user_profile_usecase.dart`
- `mypage/lib/src/domain/usecase/get_user_profile_stream_usecase.dart`
- `mypage/.dart_tool/flutter_build/dart_plugin_registrant.dart`
- `community/test/src/domain/usecase/toggle_post_like_usecase_test.dart`
- `community/test/src/domain/usecase/get_comments_usecase_test.dart`
- `community/test/src/domain/usecase/get_posts_usecase_test.dart`
- `community/test/src/domain/usecase/get_post_detail_usecase_test.dart`
- `community/test/src/presentation/widget/post_card_test.dart`
- `community/test/src/presentation/bloc/post_list_bloc_test.dart`
- `community/lib/src/test_helpers/test_helpers.dart`
- `community/lib/src/test_helpers/post_faker.dart`
- `community/lib/src/data/repository/mixins/community_serverpod_mixin.dart`
- `community/.dart_tool/flutter_build/dart_plugin_registrant.dart`
- `store/test/src/domain/usecase/store_usecase_test.dart`
- `store/lib/src/data/repository/mixins/store_serverpod_mixin.dart`
- `store/lib/src/data/cache/product_network_repository.dart`
- `store/lib/src/data/cache/cache.dart`
- `store/lib/src/data/cache/product_cache_repository.dart`
- `store/lib/src/data/cache/product_cache_query.dart`
- `store/lib/src/data/local/tables/products_table.dart`
- `store/lib/src/data/local/tables/tables.dart`
- `store/lib/src/data/local/local.dart`
- `store/lib/src/data/local/dao/product_dao.g.dart`
- `store/lib/src/data/local/dao/product_dao.dart`
- `store/lib/src/data/local/dao/dao.dart`
- `store/lib/src/data/local/store_database.dart`
- `store/lib/src/data/local/store_database.g.dart`
- `store/lib/src/domain/entity/product.dart`
- `store/lib/src/domain/usecase/get_products_usecase.dart`
- `store/lib/src/domain/usecase/get_product_detail_usecase.dart`
- `store/lib/src/domain/usecase/get_products_stream_usecase.dart`
- `store/lib/src/domain/usecase/refresh_products_usecase.dart`
- `store/.dart_tool/flutter_build/dart_plugin_registrant.dart`

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

- **Add to Project B**: 8 files missing
  - Consider: home/lib/src/data/repository/mixins/home_openapi_mixin.dart, mypage/test/src/domain/usecase/mypage_test.dart, mypage/lib/src/data/repository/mixins/mypage_openapi_mixin.dart...

- **Add to Project A**: 55 files missing
  - Consider: home/test/src/domain/usecase/get_home_feed_usecase_test.dart, home/test/src/domain/usecase/get_active_banners_usecase_test.dart, home/test/src/presentation/bloc/home_feed_bloc_test.dart...

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
