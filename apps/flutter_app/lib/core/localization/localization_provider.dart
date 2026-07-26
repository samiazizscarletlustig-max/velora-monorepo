import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage {
  english,
  french,
  spanish,
}

final languageProvider = StateProvider<AppLanguage>((ref) {
  return AppLanguage.english; // default
});

final l10nProvider = Provider<Map<String, String>>((ref) {
  final language = ref.watch(languageProvider);

  switch (language) {
    case AppLanguage.french:
      return _frenchL10n;
    case AppLanguage.spanish:
      return _spanishL10n;
    case AppLanguage.english:
    default:
      return _englishL10n;
  }
});

const Map<String, String> _englishL10n = {
  // Login Screen
  'login_success': 'Logged in successfully!',
  'welcome_back': 'Welcome Back',
  'enter_details': 'Enter your details to access your dashboard',
  'email': 'Email',
  'invalid_email': 'Please enter a valid email address',
  'password': 'Password',
  'invalid_password': 'Password must be at least 6 characters',
  'login': 'Log In',
  'continue_google': 'Continue with Google',
  'no_account': "Don't have an account?",
  'sign_up': 'Sign Up',

  // Register Screen
  'register_success': 'Account created successfully!',
  'create_account': 'Create Account',
  'join_velora': 'Join Velora today',
  'full_name': 'Full Name',
  'invalid_name': 'Please enter your name',
  'have_account': 'Already have an account?',

  // Onboarding Screen
  'store_url_q': "What's your store URL?",
  'store_url_sub': "We'll analyze your products, pricing, and SEO automatically",
  'store_url_hint': 'myshopify.com or domain',
  'continue_btn': 'Continue',
  'competitor_q': "Who's your main competitor?",
  'competitor_sub': "Our AI agents will monitor their catalog and prices 24/7",
  'competitor_hint': 'competitor-shop.com',
  'analyze_btn': 'Analyze & Generate Insights',
  'back_btn': 'Back',
  'analyzing_msg': 'Analyzing store data and competitor metrics...',

  // Settings Screen
  'settings': 'Settings',
  'profile': 'Profile',
  'appearance': 'Appearance',
  'system': 'System',
  'light': 'Light',
  'dark': 'Dark',
  'language': 'Language',
  'lang_en': 'English',
  'lang_fr': 'French',
  'lang_es': 'Spanish',
  'notifications': 'Notifications',
  'email_alerts': 'Email Alerts',
  'email_alerts_sub': 'Get daily or weekly insights sent to your inbox',
  'push_notifications': 'Push Notifications',
  'push_notifications_sub': 'Get real-time alerts on price undercuts',
  'danger_zone': 'Danger Zone',
  'delete_workspace': 'Delete Workspace',
  'delete_workspace_sub': 'Permanently delete all analytics, strategies, and workspace data',
  'delete_confirm_title': 'Are you absolutely sure?',
  'delete_confirm_msg': 'This action cannot be undone. You will lose all historic performance data, connected stores, and generated AI recommendations.',
  'cancel': 'Cancel',
  'workspace_deleted': 'Workspace successfully deleted',
  'delete_btn': 'Delete',
  'edit': 'Edit',
  'logout': 'Log Out',
};

const Map<String, String> _frenchL10n = {
  // Login Screen
  'login_success': 'Connexion réussie !',
  'welcome_back': 'Bon Retour',
  'enter_details': 'Entrez vos coordonnées pour accéder au tableau de bord',
  'email': 'E-mail',
  'invalid_email': 'Veuillez entrer une adresse e-mail valide',
  'password': 'Mot de passe',
  'invalid_password': 'Le mot de passe doit comporter au moins 6 caractères',
  'login': 'Se connecter',
  'continue_google': 'Continuer avec Google',
  'no_account': "Vous n'avez pas de compte ?",
  'sign_up': "S'inscrire",

  // Register Screen
  'register_success': 'Compte créé avec succès !',
  'create_account': 'Créer un compte',
  'join_velora': "Rejoignez Velora dès aujourd'hui",
  'full_name': 'Nom complet',
  'invalid_name': 'Veuillez entrer votre nom',
  'have_account': 'Vous avez déjà un compte ?',

  // Onboarding Screen
  'store_url_q': "Quelle est l'URL de votre boutique ?",
  'store_url_sub': 'Nous analyserons automatiquement vos produits, vos prix et votre référencement',
  'store_url_hint': 'myshopify.com ou domaine',
  'continue_btn': 'Continuer',
  'competitor_q': 'Qui est votre principal concurrent ?',
  'competitor_sub': 'Nos agents d\'IA surveilleront leur catalogue et leurs prix 24h/24',
  'competitor_hint': 'concurrent-boutique.com',
  'analyze_btn': 'Analyser & Générer des perspectives',
  'back_btn': 'Retour',
  'analyzing_msg': 'Analyse des données de la boutique et des métriques des concurrents...',

  // Settings Screen
  'settings': 'Paramètres',
  'profile': 'Profil',
  'appearance': 'Apparence',
  'system': 'Système',
  'light': 'Clair',
  'dark': 'Sombre',
  'language': 'Langue',
  'lang_en': 'Anglais',
  'lang_fr': 'Français',
  'lang_es': 'Espagnol',
  'notifications': 'Notifications',
  'email_alerts': 'Alertes e-mail',
  'email_alerts_sub': 'Recevez des rapports quotidiens ou hebdomadaires dans votre boîte de réception',
  'push_notifications': 'Notifications push',
  'push_notifications_sub': 'Recevez des alertes en temps réel sur les baisses de prix',
  'danger_zone': 'Zone de danger',
  'delete_workspace': "Supprimer l'espace de travail",
  'delete_workspace_sub': 'Supprimer définitivement toutes les données d\'analyse, de stratégie et d\'espace de travail',
  'delete_confirm_title': 'Êtes-vous absolument sûr ?',
  'delete_confirm_msg': 'Cette action est irréversible. Vous perdrez toutes les données de performance historiques, les boutiques connectées et les recommandations d\'IA générées.',
  'cancel': 'Annuler',
  'workspace_deleted': 'Espace de travail supprimé avec succès',
  'delete_btn': 'Supprimer',
  'edit': 'Modifier',
  'logout': 'Se déconnecter',
};

const Map<String, String> _spanishL10n = {
  // Login Screen
  'login_success': '¡Inicio de sesión exitoso!',
  'welcome_back': 'Bienvenido de Nuevo',
  'enter_details': 'Ingresa tus datos para acceder a tu panel',
  'email': 'Correo electrónico',
  'invalid_email': 'Por favor, introduce una dirección de correo válida',
  'password': 'Contraseña',
  'invalid_password': 'La contraseña debe tener al menos 6 caracteres',
  'login': 'Iniciar sesión',
  'continue_google': 'Continuar con Google',
  'no_account': '¿No tienes una cuenta?',
  'sign_up': 'Registrarse',

  // Register Screen
  'register_success': '¡Cuenta creada con éxito!',
  'create_account': 'Crear cuenta',
  'join_velora': 'Únete a Velora hoy',
  'full_name': 'Nombre completo',
  'invalid_name': 'Por favor, introduce tu nombre',
  'have_account': '¿Ya tienes una cuenta?',

  // Onboarding Screen
  'store_url_q': '¿Cuál es la URL de tu tienda?',
  'store_url_sub': 'Analizaremos tus productos, precios y SEO automáticamente',
  'store_url_hint': 'myshopify.com o dominio',
  'continue_btn': 'Continuar',
  'competitor_q': '¿Quién es tu principal competidor?',
  'competitor_sub': 'Nuestros agentes de IA vigilarán su catálogo y precios las 24 horas, los 7 días de la semana',
  'competitor_hint': 'competidor-tienda.com',
  'analyze_btn': 'Analizar y generar información',
  'back_btn': 'Atrás',
  'analyzing_msg': 'Analizando datos de la tienda y métricas de competidores...',

  // Settings Screen
  'settings': 'Configuración',
  'profile': 'Perfil',
  'appearance': 'Apariencia',
  'system': 'Sistema',
  'light': 'Claro',
  'dark': 'Oscuro',
  'language': 'Idioma',
  'lang_en': 'Inglés',
  'lang_fr': 'Francés',
  'lang_es': 'Español',
  'notifications': 'Notificaciones',
  'email_alerts': 'Alertas por correo electrónico',
  'email_alerts_sub': 'Recibe informes diarios o semanales en tu bandeja de entrada',
  'push_notifications': 'Notificaciones push',
  'push_notifications_sub': 'Recibe alertas en tiempo real sobre bajas de precios',
  'danger_zone': 'Zona de peligro',
  'delete_workspace': 'Eliminar espacio de trabajo',
  'delete_workspace_sub': 'Eliminar permanentemente todos los análisis, estrategias y datos del espacio de trabajo',
  'delete_confirm_title': '¿Estás absolutamente seguro?',
  'delete_confirm_msg': 'Esta acción no se puede deshacer. Perderás todos los datos de rendimiento histórico, tiendas conectadas y recomendaciones de IA generadas.',
  'cancel': 'Cancelar',
  'workspace_deleted': 'Espacio de trabajo eliminado con éxito',
  'delete_btn': 'Eliminar',
  'edit': 'Editar',
  'logout': 'Cerrar sesión',
};
