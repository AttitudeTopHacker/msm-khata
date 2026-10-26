import 'dart:io';

class ApiConfig {
  // Supabase Credentials
  static const String supabaseUrl = 'https://dzjzinbogydbnatkibuw.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6anppbmJvZ3lkYm5hdGtpYnV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMjIwMDAsImV4cCI6MjEwODU5ODAwMH0.I8DylpQtpCHpKFOUFXgfzALl9T9xA3nKhX6IYOBfbtU';

  // FastAPI Backend URL
  // On Android emulator, localhost is 10.0.2.2; on Linux/Windows Desktop it is localhost:8000
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }
}
