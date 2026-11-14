import '../../domain/entities/auth_user.dart';
import '../dtos/auth_user_dto.dart';

extension AuthUserDtoMapper on AuthUserDto {
  AuthUser toDomain() {
    return AuthUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      emailVerified: emailVerified,
      isAnonymous: isAnonymous,
      authSessionGeneration: authSessionGeneration,
      tenantId: tenantId,
      currency: currency,
      language: language,
      country: country,
      timezone: timezone,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastLogin: lastLogin,
    );
  }
}
