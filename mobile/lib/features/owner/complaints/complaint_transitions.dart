/// UI-only mirror of server's services/complaint-status.ts ALLOWED_TRANSITIONS
/// — drives which status buttons are offered. The server re-validates
/// regardless.
const Map<String, List<String>> complaintAllowedTransitions = {
  'OPEN': ['IN_PROGRESS', 'ESCALATED', 'CLOSED'],
  'IN_PROGRESS': ['RESOLVED', 'ESCALATED', 'OPEN'],
  'ESCALATED': ['IN_PROGRESS', 'RESOLVED'],
  'RESOLVED': ['CLOSED', 'REOPENED'],
  'REOPENED': ['IN_PROGRESS', 'ESCALATED'],
  'CLOSED': ['REOPENED'],
};
