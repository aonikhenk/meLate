# MeLate 💖💔

App de compañía para adultos mayores (iPhone y Android, Flutter + Firebase).

## Qué guarda
- **En el teléfono:** apodos y códigos de contactos (máx. 9 + el usuario = 10).
- **En Firebase:** un código anónimo, el token de notificaciones y latidos temporales (se borran al responder).
- **No guarda:** nombres reales, teléfonos, contraseñas ni datos de wifi.

## Configuración de Firebase
`android/app/google-services.json` no está en el repositorio. Descárgalo desde tu proyecto Firebase (app Android con paquete `com.navazu.melate`) y colócalo en `android/app/`.

## Pasos para compilar
1. Instalar Flutter: https://docs.flutter.dev/get-started/install
2. En esta carpeta: `flutter pub get` (para iPhone, además `flutter create . --platforms=ios`)
3. Crear proyecto en https://console.firebase.google.com:
   - Activar **Authentication → Anónimo**
   - Crear **Firestore** y pegar `firestore.rules`
   - Plan **Blaze** (pago por uso; a esta escala queda en la capa gratuita) para Cloud Functions
4. `dart pub global activate flutterfire_cli` y `flutterfire configure`
5. Subir la función: `npm i -g firebase-tools`, `firebase init functions` (usar la carpeta `functions/`), `firebase deploy --only functions`
6. iPhone: en Xcode activar *Push Notifications* y *Background Modes → Remote notifications*; subir la clave APNs a Firebase (Configuración → Cloud Messaging). Requiere cuenta Apple Developer.
7. Android: `flutter run` o `flutter build apk`.

## Uso
1. Cada teléfono muestra su **código** en ⚙️.
2. Se intercambian códigos y se agregan con un apodo.
3. Corazón 💖 o 💔 → latido a todos los contactos.
4. El receptor recibe aviso repetido (cada 30 s, 3 veces) y vibración continua con la app abierta, hasta responder con un corazón.
5. Al tomar el teléfono tras 5 min quieto (o abrir la app) se envía un latido automático, máximo 1 cada 2 horas.

## Limitaciones
- iPhone no permite leer el acelerómetro con la app cerrada; ahí el latido automático se envía al abrir la app.
- La vibración continua solo funciona con la app abierta; cerrada, se usan avisos repetidos.
