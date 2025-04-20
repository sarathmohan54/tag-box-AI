# TagBox

A modern Flutter application for collecting, organizing, and viewing social media content from various platforms in one place.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)

## 📱 Features

- **Cross-Platform Support**: Built with Flutter for both iOS and Android
- **Social Media Integration**: View content from YouTube, Instagram, Facebook and more
- **Content Organization**: Filter and categorize content by platform, date, and custom categories
- **Offline Mode**: Cache content for offline viewing
- **Sharing**: Share interesting content with others
- **User Profiles**: Manage your content library with user accounts
- **Responsive UI**: Beautiful interface that adapts to different screen sizes

## 🚀 Technology Stack

### Frontend
- **Flutter**: UI framework for cross-platform development
- **Dart**: Programming language optimized for client apps
- **Cached Network Image**: Efficient image loading and caching
- **WebView**: Embedded web content from social media platforms
- **Share Plus**: Social sharing functionality
- **Connectivity Plus**: Network connectivity management

### State Management
- **setState**: Simple state management for UI components
- **Debouncing**: Optimized search and filtering

### Backend Integration
- **HTTP**: RESTful API communication
- **JSON Parsing**: Data serialization and deserialization
- **Authentication**: Token-based user authentication

### Storage
- **SharedPreferences**: Local data persistence

### Performance Optimizations
- **RepaintBoundary**: UI rendering optimization
- **Memory Management**: Image size optimizations
- **Lazy Loading**: On-demand content loading

## ⚙️ Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Android Studio / Xcode
- Git

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/tagbox.git
cd tagbox
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## 📂 Project Structure

```
lib/
  ├── common/            # Shared UI components
  ├── models/            # Data models
  ├── pages/             # Application screens
  ├── services/          # API and business logic services
  ├── utils/             # Utility functions
  ├── widgets/           # Reusable UI components
  ├── main.dart          # Application entry point
  ├── home_page.dart     # Main screen
  └── ...
```

## 🔧 Configuration

- **API Endpoints**: Configured in `utils/constants.dart`
- **Theme Settings**: Customized in `common/theme.dart`

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgements

- [Flutter](https://flutter.dev/)
- [WebView Flutter](https://pub.dev/packages/webview_flutter)
- [Cached Network Image](https://pub.dev/packages/cached_network_image)
- [Share Plus](https://pub.dev/packages/share_plus)
