import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentle/features/auth/screens/accept_invite_screen.dart';
import 'package:rentle/features/auth/screens/owner_auth_screen.dart';
import 'package:rentle/features/auth/screens/owner_setup_screen.dart';
import 'package:rentle/features/auth/screens/otp_screen.dart';
import 'package:rentle/features/auth/screens/phone_screen.dart';
import 'package:rentle/features/auth/screens/splash_screen.dart';
import 'package:rentle/features/auth/screens/waiting_screen.dart';
import 'package:rentle/features/auth/screens/welcome_screen.dart';
import 'package:rentle/features/manager/screens/manager_home_screen.dart';
import 'package:rentle/features/manager/screens/manager_more_screen.dart';
import 'package:rentle/features/manager/screens/manager_shell.dart';
import 'package:rentle/features/owner/screens/owner_add_tenant_screen.dart';
import 'package:rentle/features/owner/screens/owner_complaints_screen.dart';
import 'package:rentle/features/owner/screens/owner_dashboard_screen.dart';
import 'package:rentle/features/owner/screens/owner_notices_screen.dart';
import 'package:rentle/features/owner/screens/owner_pick_contact_screen.dart';
import 'package:rentle/features/owner/screens/owner_rent_records_screen.dart';
import 'package:rentle/features/owner/screens/owner_room_detail_screen.dart';
import 'package:rentle/features/owner/screens/owner_rooms_screen.dart';
import 'package:rentle/features/owner/screens/owner_shell.dart';
import 'package:rentle/features/owner/screens/owner_staff_screen.dart';
import 'package:rentle/features/owner/screens/owner_tenants_screen.dart';
import 'package:rentle/features/settings/screens/settings_screen.dart';
import 'package:rentle/features/tenant/screens/tenant_home_screen.dart';
import 'package:rentle/features/tenant/screens/tenant_more_screen.dart';
import 'package:rentle/features/tenant/screens/tenant_payments_screen.dart';
import 'package:rentle/features/tenant/screens/tenant_shell.dart';
import 'package:rentle/models/user_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/owner',
        builder: (context, state) => const OwnerAuthScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? UserRoleValues.tenant;
          return PhoneScreen(role: role);
        },
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final role = state.uri.queryParameters['role'] ?? UserRoleValues.tenant;
          return OtpScreen(phone: phone, role: role);
        },
      ),
      GoRoute(
        path: '/owner/setup',
        builder: (context, state) => const OwnerSetupScreen(),
      ),
      GoRoute(
        path: '/waiting',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? UserRoleValues.tenant;
          return WaitingScreen(role: role);
        },
      ),
      GoRoute(
        path: '/accept-invite',
        builder: (context, state) {
          final inviteId = state.uri.queryParameters['inviteId'] ?? '';
          final role = state.uri.queryParameters['role'] ?? UserRoleValues.tenant;
          return AcceptInviteScreen(inviteId: inviteId, role: role);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => OwnerShell(child: child),
        routes: [
          GoRoute(
            path: '/owner/dashboard',
            builder: (context, state) => const OwnerDashboardScreen(),
          ),
          GoRoute(
            path: '/owner/rooms',
            builder: (context, state) => const OwnerRoomsScreen(),
            routes: [
              GoRoute(
                path: ':roomId',
                builder: (context, state) => OwnerRoomDetailScreen(
                  roomId: state.pathParameters['roomId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/owner/tenants',
            builder: (context, state) => const OwnerTenantsScreen(),
          ),
          GoRoute(
            path: '/owner/more',
            builder: (context, state) => const OwnerMoreScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/owner/tenants/add',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return OwnerAddTenantScreen(
              initialName: extra['name'] as String?,
              initialPhone: extra['phone'] as String?,
              initialRoomId: extra['roomId'] as String?,
            );
          }
          return const OwnerAddTenantScreen();
        },
      ),
      GoRoute(
        path: '/owner/tenants/pick-contact',
        builder: (context, state) => const OwnerPickContactScreen(),
      ),
      GoRoute(
        path: '/owner/staff',
        builder: (context, state) => const OwnerStaffScreen(),
      ),
      GoRoute(
        path: '/owner/complaints',
        builder: (context, state) => const OwnerComplaintsScreen(),
      ),
      GoRoute(
        path: '/owner/notices',
        builder: (context, state) => const OwnerNoticesScreen(),
      ),
      GoRoute(
        path: '/owner/rent-records',
        builder: (context, state) => const OwnerRentRecordsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => TenantShell(child: child),
        routes: [
          GoRoute(
            path: '/tenant/dashboard',
            builder: (context, state) => const TenantHomeScreen(),
          ),
          GoRoute(
            path: '/tenant/payments',
            builder: (context, state) => const TenantPaymentsScreen(),
          ),
          GoRoute(
            path: '/tenant/more',
            builder: (context, state) => const TenantMoreScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ManagerShell(child: child),
        routes: [
          GoRoute(
            path: '/manager/dashboard',
            builder: (context, state) => const ManagerHomeScreen(),
          ),
          GoRoute(
            path: '/manager/complaints',
            builder: (context, state) => const ManagerComplaintsScreen(),
          ),
          GoRoute(
            path: '/manager/more',
            builder: (context, state) => const ManagerMoreScreen(),
          ),
        ],
      ),
    ],
  );
});
