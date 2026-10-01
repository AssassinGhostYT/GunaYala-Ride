# GunaYala Ride

App movil de Flutter para Guna Yala, Panama. **No es un taxi: se vende el cupo, no el trayecto.**
Un chofer publica un viaje y un pasajero pide cupo. El pago es directo entre los dos
(efectivo o Yapp al chofer). **La app no cobra ni procesa pagos.**

- Material 3, cian caribe
- `package: gunayala_ride`, Android `com.gunayala.ride`
- Firebase: Auth (custom token), Firestore, Storage, Messaging, Functions (Node 20)

## Las 7 reglas de negocio (inalterables)

Estas reglas estan en tres capas: Dart puro (`lib/rules/guards.dart`, testeado),
reglas de Firestore (`firestore.rules`) y Cloud Functions (`functions/src/index.ts`).
La capa de seguridad es la que manda.

1. **Sin insignia no publicas.** La insignia de chofer sale solo con revision humana
   (`reviewDriverVerification`). En Panama no hay API publica de licencias ni de
   cedulas, asi que el status **no** se puede escribir desde el movil.
2. **Cupos ofrecidos (`seatsTotal`) <= asientos fisicos (`vehicle.seats`).** Los cupos
   vendidos (`seatsReserved`, `riderIds`) los mueve el servidor
   (`onSeatAccepted` / `onSeatReleased`), el chofer no los toca.
3. **Chat solo entre los del viaje y solo en abordaje o en camino.** Al terminar, muere.
4. **Cancelar cupo devuelve el asiento** (`onSeatReleased`).
5. **Sin confirmacion del pasajero no hay resena** (`riderConfirmed` + `onRideFinished`).
6. **Reporte grave** (amenaza, manejo peligroso, arma, acoso) **apaga la insignia**
   (`onSafetyReport`). No banea la cuenta.
7. **Llamada con el numero real** (dialer, sin VoIP) y **compartir = texto + link de
   Maps**. Nunca tracking vivo publico.

## Registro y acceso

- Registro con **correo y contrasena**: nombre, apellido, edad, celular y pais.
  Panama (+507) es el pais principal y viene por defecto; se puede elegir otro.
- En Firebase Auth hay que habilitar el proveedor **Correo/Contraseña**.
- El codigo de WhatsApp (`sendOtp` / `verifyOtp`) queda disponible para
  verificar el celular despues; no es la puerta de entrada.

## Logo

`tool/logo.py` dibuja el icono (marca tipo InDrive: carro blanco sobre fondo
cian, faro coral) y lo baja a los cinco mipmap de Android mas los assets.
Cambias el script y vuelves a correrlo, no hace falta diseno externo.

## Como corre el robot (GitHub Actions)

`.github/workflows/build.yml` corre en cada push:

- `flutter analyze`, `flutter test`
- **APK debug** -> artifact `gunayala-ride-debug-apk` (y App Distribution si hay credenciales)
- **AAB de release** -> artifact `gunayala-ride-release-aab`, solo en `main` y solo si
  hay keystore. Sin keystore sale firmado con la llave de debug y Play lo rechaza.
- Las Functions se compilan con `tsc` para comprobar que el TypeScript esta bien.

## Secrets que hay que configurar en GitHub

| Secret | Para que sirve |
| --- | --- |
| `GOOGLE_SERVICES_JSON` | El `google-services.json` real (contenido del archivo, entre comillas). Sin esto el APK compila pero Firebase no responde. |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 gunayala-release.jks` |
| `ANDROID_KEY_ALIAS` | Alias de la llave |
| `ANDROID_KEY_PASSWORD` | Password de la llave |
| `ANDROID_STORE_PASSWORD` | Password del keystore |
| `MAPS_API_KEY` | Clave de Google Maps restringida por paquete + SHA-1 |
| `FIREBASE_APP_ID`, `FIREBASE_CLI_TOKEN` | Opcional: instala el APK debug en telefonos de prueba |

## Keystore de release

El `.jks` **nunca** va al repo. Para crearlo:

```bash
keytool -genkeypair -v -keystore ~/gunayala-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias gunayala
```

Respalvalo fuera del compu. Si lo pierdes, Google no te deja volver a firmar el app.
Para compilar local, crea `android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=gunayala
storeFile=/ruta/absoluta/gunayala-release.jks
MAPS_API_KEY=AIza...
```

Sin ese archivo, release cae a la firma de debug para que el build no se caiga.

## Functions

```bash
cd functions && npm install
firebase functions:secrets:set OTP_PEPPER WHATSAPP_TOKEN WHATSAPP_PHONE_ID
firebase deploy --only functions
```

## Estructura de datos

`users/{uid}`, `users/{uid}/verification/{driver|rider}`, `users/{uid}/blocked/{otro}`,
`users/{uid}/devices/{hash}`, `vehicles/{id}`, `rides/{id}` + `requests/`, `chat/`,
`live/`, `reviews/{id}`, `reports/{id}` (el reportado nunca los lee).

## Pendientes que no son codigo

- `google-services.json` real y clave de Maps restringida
- Cuenta de WhatsApp Business (numero, plantilla, secrets)
- Alguien que revise los documentos de los choferes (para poder poner `staff`)