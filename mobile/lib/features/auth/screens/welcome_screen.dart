import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/user_model.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentleColors.warmSand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.home_rounded, color: RentleColors.coral, size: 40),
              Text(
                'Rentle',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: RentleColors.trustBlue,
                ),
              ),
              Text(
                'PG Management, Simplified',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: RentleColors.charcoal.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Who are you?',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: RentleColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select your role to continue',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: RentleColors.charcoal.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    RoleCard(
                      icon: Icons.home_work_rounded,
                      iconColor: RentleColors.coral,
                      title: 'Property Owner',
                      subtitle: 'Manage your PG and tenants',
                      selected: _selectedRole == UserRoleValues.owner,
                      onTap: () {
                        setState(() => _selectedRole = UserRoleValues.owner);
                        context.push('/auth/owner');
                      },
                    ),
                    const SizedBox(height: 16),
                    RoleCard(
                      icon: Icons.manage_accounts_rounded,
                      iconColor: RentleColors.trustBlue,
                      title: 'Manager / Staff',
                      subtitle: 'Manage operations for a property',
                      selected: _selectedRole == UserRoleValues.manager,
                      onTap: () {
                        setState(() => _selectedRole = UserRoleValues.manager);
                        context.push(
                          '/auth/phone?role=${UserRoleValues.manager}',
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    RoleCard(
                      icon: Icons.person_rounded,
                      iconColor: RentleColors.teal,
                      title: 'Tenant',
                      subtitle: 'Pay rent and track your stay',
                      selected: _selectedRole == UserRoleValues.tenant,
                      onTap: () {
                        setState(() => _selectedRole = UserRoleValues.tenant);
                        context.push(
                          '/auth/phone?role=${UserRoleValues.tenant}',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
