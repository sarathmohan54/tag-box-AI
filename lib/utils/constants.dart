class ApiConstants {
  // For Android emulator, use 10.0.2.2 instead of localhost
  // For physical device, use your computer's IP address
  // For iOS simulator, use localhost
  // 
  // NOTE: To find your computer's IP address:
  // - On Windows: Run 'ipconfig' in CMD and look for IPv4 Address
  // - On Mac/Linux: Run 'ifconfig' or 'ip addr' in terminal and look for inet address
  //
  // Make sure your mobile device and computer are on the same WiFi network
  static const String baseUrl = 'http://192.168.1.3:8000';
  static const String loginEndpoint = '$baseUrl/api/login';
  static const String registerEndpoint = '$baseUrl/api/register';
} 