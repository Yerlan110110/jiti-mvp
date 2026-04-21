class ApiConstants {
  static const String baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'http://192.168.42.16:3000/api'); // Local network IP
  static const String socketUrl = const String.fromEnvironment('SOCKET_URL', defaultValue: 'http://192.168.42.16:3000');
  
  // Auth
  static const String sendCode = '/auth/send-code';
  static const String verifyCode = '/auth/verify-code';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  
  // Orders
  static const String orders = '/orders';
  static const String availableOrders = '/orders/available';
  static const String myOrders = '/orders/my';
  static const String activeOrder = '/orders/active';
}

class AppColors {
  // Primary
  static const int primary = 0xFF6C5CE7;
  static const int primaryLight = 0xFFA29BFE;
  static const int primaryDark = 0xFF4834D4;
  
  // Accent
  static const int accent = 0xFF00CEC9;
  static const int accentLight = 0xFF81ECEC;
  
  // Status
  static const int success = 0xFF00B894;
  static const int warning = 0xFFFDAA5B;
  static const int error = 0xFFFF6B6B;
  
  // Neutrals
  static const int background = 0xFF0F0F23;
  static const int surface = 0xFF1A1A2E;
  static const int surfaceLight = 0xFF25253E;
  static const int textPrimary = 0xFFFFFFFF;
  static const int textSecondary = 0xFFB2B2CC;
  static const int textHint = 0xFF666680;
  static const int border = 0xFF2A2A45;
}

class AppStrings {
  static const String appName = 'Jiti';
  static const String login = 'Вход';
  static const String phone = 'Номер телефона';
  static const String sendCode = 'Отправить код';
  static const String enterCode = 'Введите код';
  static const String verify = 'Подтвердить';
  static const String registration = 'Регистрация';
  static const String name = 'Имя';
  static const String selectRole = 'Выберите роль';
  static const String client = 'Клиент';
  static const String driver = 'Водитель';
  static const String carBrand = 'Марка авто';
  static const String carModel = 'Модель';
  static const String carColor = 'Цвет';
  static const String carPlate = 'Госномер';
  static const String register = 'Зарегистрироваться';
  static const String createOrder = 'Создать заказ';
  static const String pointA = 'Точка A (Откуда)';
  static const String pointB = 'Точка B (Куда)';
  static const String price = 'Цена';
  static const String respond = 'Откликнуться';
  static const String selectDriver = 'Выбрать';
  static const String startTrip = 'Начать поездку';
  static const String completeTrip = 'Завершить поездку';
  static const String cancel = 'Отменить';
  static const String history = 'История';
  static const String online = 'Онлайн';
  static const String offline = 'Офлайн';
  static const String noOrders = 'Нет заказов';
  static const String responses = 'Отклики';
}
