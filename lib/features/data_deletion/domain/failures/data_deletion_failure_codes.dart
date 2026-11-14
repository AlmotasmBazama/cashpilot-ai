abstract final class DataDeletionFailureCodes {
  static const confirmationRequired = 'data_deletion_confirmation_required';
  static const reauthenticationFailed = 'data_deletion_reauth_failed';
  static const identityChanged = 'data_deletion_identity_changed';
  static const operationInProgress = 'data_deletion_operation_in_progress';
  static const operationStateCorrupt = 'data_deletion_state_corrupt';
  static const secureAuthorizationUnavailable =
      'data_deletion_secure_authorization_unavailable';
  static const legacyOwnerResolutionRequired =
      'data_deletion_legacy_owner_resolution_required';
  static const cloudDeletionFailed = 'data_deletion_cloud_failed';
  static const cloudGatewayRequestInvalid =
      'data_deletion_cloud_gateway_request_invalid';
  static const cloudGatewayConfigurationFailed =
      'data_deletion_cloud_gateway_configuration_failed';
  static const cloudGatewayAuthorizationFailed =
      'data_deletion_cloud_gateway_authorization_failed';
  static const cloudGatewayAuthenticationRequired =
      'data_deletion_cloud_gateway_authentication_required';
  static const cloudGatewayAppCheckUnavailable =
      'data_deletion_cloud_gateway_app_check_unavailable';
  static const cloudGatewayDeletionProofInvalid =
      'data_deletion_cloud_gateway_deletion_proof_invalid';
  static const cloudGatewayPermissionDenied =
      'data_deletion_cloud_gateway_permission_denied';
  static const cloudGatewayOperationConflict =
      'data_deletion_cloud_gateway_operation_conflict';
  static const cloudGatewayReauthenticationRequired =
      'data_deletion_cloud_gateway_reauthentication_required';
  static const cloudGatewayRateLimited =
      'data_deletion_cloud_gateway_rate_limited';
  static const cloudGatewayProviderUnavailable =
      'data_deletion_cloud_gateway_provider_unavailable';
  static const cloudGatewayTimeout = 'data_deletion_cloud_gateway_timeout';
  static const cloudGatewayDeletePartial =
      'data_deletion_cloud_gateway_delete_partial';
  static const cloudGatewayVerificationFailed =
      'data_deletion_cloud_gateway_verification_failed';
  static const cloudGatewayNetworkFailed =
      'data_deletion_cloud_gateway_network_failed';
  static const cloudGatewayInvalidResponse =
      'data_deletion_cloud_gateway_invalid_response';
  static const cloudGatewayDeletionNotReady =
      'data_deletion_cloud_gateway_deletion_not_ready';
  static const cloudGatewayUnknownTemporaryFailure =
      'data_deletion_cloud_gateway_unknown_temporary_failure';
  static const localDeletionFailed = 'data_deletion_local_failed';
  static const receiptFileDeletionFailed = 'data_deletion_receipt_files_failed';
  static const preferencesDeletionFailed = 'data_deletion_preferences_failed';
  static const authDeletionFailed = 'data_deletion_auth_failed';
  static const authDeletionFinalizationFailed =
      'data_deletion_auth_finalization_failed';
}
