/// Turns raw Supabase/auth exceptions into short, human messages.
String authErrorMessage(Object e) {
  final s = e.toString().toLowerCase();

  // Network / DNS / connectivity
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('no address associated') ||
      s.contains('retryablefetch') ||
      s.contains('clientexception') ||
      s.contains('connection') ||
      s.contains('network')) {
    return 'No internet connection. Check your network and try again.';
  }

  // Wrong credentials
  if (s.contains('invalid login credentials') ||
      s.contains('invalid_grant') ||
      (s.contains('400') && s.contains('password'))) {
    return 'Incorrect email or password.';
  }

  // Account state
  if (s.contains('email not confirmed')) {
    return 'Please confirm your email, then sign in.';
  }
  if (s.contains('user already registered') ||
      s.contains('already been registered')) {
    return 'An account with this email already exists. Try signing in.';
  }
  if (s.contains('password should be at least') ||
      s.contains('weak password')) {
    return 'Password is too short — use at least 6 characters.';
  }
  if (s.contains('unable to validate email') ||
      s.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }
  if (s.contains('rate limit') || s.contains('too many')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  return 'Something went wrong. Please try again.';
}
