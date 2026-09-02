import 'package:dio/dio.dart';

import '../../constants/app_constants.dart';

/// Supplies the currently selected branch id.
typedef BranchIdReader = String? Function();

/// Attaches the active branch to every request.
///
/// The backend currently takes `branchId` as an explicit per-endpoint
/// parameter (`SecurityUtils.requireBranchAccess(branchId)`), so repositories
/// still pass it deliberately. This header is sent alongside so that branch
/// scoping can become a single interceptor concern if the backend adopts it.
class BranchContextInterceptor extends Interceptor {
  BranchContextInterceptor(this._readBranchId);

  final BranchIdReader _readBranchId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final branchId = _readBranchId();
    if (branchId != null && branchId.isNotEmpty) {
      options.headers[AppConstants.branchIdHeader] = branchId;
    }
    handler.next(options);
  }
}
