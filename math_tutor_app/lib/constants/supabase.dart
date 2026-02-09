const String SUPABASE_URL = 'https://bviaqbyjgvrqsxvbesgq.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2aWFxYnlqZ3ZycXN4dmJlc2dxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzOTAyNTYsImV4cCI6MjA4NDk2NjI1Nn0.sI5gMPenCp6CxSP87PQZEolmlaE172Hzfn8XI3otRak';

/// Allowed school email domains for registration
const List<String> ALLOWED_SCHOOL_DOMAINS = [
  'phm.k12.in.us',      // Penn-Harris-Madison Schools
  'k12.in.us',          // Indiana K-12 schools
  'edu',                // General education domain
  'student.edu',        // Student email domains
  // Add more school domains as needed
];

/// Function to validate if an email is from an allowed school domain
bool isValidSchoolEmail(String email) {
  email = email.toLowerCase().trim();
  
  for (final domain in ALLOWED_SCHOOL_DOMAINS) {
    if (email.endsWith('@$domain')) {
      return true;
    }
  }
  
  return false;
}
