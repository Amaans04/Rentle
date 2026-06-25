import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rentle/models/user_model.dart';

class AuthNavigation {
  static void navigateAfterAuth(
    BuildContext context, {
    required String role,
    required bool isNewUser,
    String? pgId,
    bool hasInvite = false,
    String? inviteId,
  }) {
    if (hasInvite && inviteId != null) {
      context.go('/accept-invite?inviteId=$inviteId&role=$role');
      return;
    }

    switch (role) {
      case UserRoleValues.owner:
        if (isNewUser || pgId == null) {
          context.go('/owner/setup');
        } else {
          context.go('/owner/dashboard');
        }
      case UserRoleValues.manager:
        if (pgId != null) {
          context.go('/manager/dashboard');
        } else {
          context.go('/waiting?role=manager');
        }
      case UserRoleValues.tenant:
        if (pgId != null) {
          context.go('/tenant/dashboard');
        } else {
          context.go('/waiting?role=tenant');
        }
      default:
        context.go('/welcome');
    }
  }

  static void navigateByRole(BuildContext context, String? role) {
    switch (role) {
      case UserRoleValues.owner:
        context.go('/owner/dashboard');
      case UserRoleValues.manager:
        context.go('/manager/dashboard');
      case UserRoleValues.tenant:
        context.go('/tenant/dashboard');
      default:
        context.go('/welcome');
    }
  }
}
