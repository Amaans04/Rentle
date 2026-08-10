/// UI-only mirror of server's src/auth/permissions.ts ROLE_PERMISSIONS table
/// — used to hide/disable actions a role can't perform, purely for a better
/// UX. This is NOT a security boundary; the server re-checks every request
/// regardless of what this says.
enum Perm { propertyWrite, tenancyWrite, invoiceWrite, paymentWrite, complaintWrite, staffWrite, auditRead }

const Map<String, Set<Perm>> _rolePerms = {
  'OWNER': {
    Perm.propertyWrite,
    Perm.tenancyWrite,
    Perm.invoiceWrite,
    Perm.paymentWrite,
    Perm.complaintWrite,
    Perm.staffWrite,
    Perm.auditRead,
  },
  'MANAGER': {
    Perm.propertyWrite,
    Perm.tenancyWrite,
    Perm.invoiceWrite,
    Perm.paymentWrite,
    Perm.complaintWrite,
    Perm.staffWrite,
    Perm.auditRead,
  },
  'RECEPTIONIST': {Perm.tenancyWrite, Perm.complaintWrite},
  'ACCOUNTANT': {Perm.invoiceWrite, Perm.paymentWrite},
  'STAFF': {Perm.complaintWrite},
};

bool roleCan(String role, Perm perm) => _rolePerms[role]?.contains(perm) ?? false;
