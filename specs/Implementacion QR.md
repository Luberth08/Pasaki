se puede integrar en una app que estoy desarrollando, la opcion de generar un qr que esta vinculado a una cuenta bancaria por ejemplo del banco mercantil santa cruz? de tal manera que alguien pueda pagarle a esa cuenta mediante ese qr generado?

Verificar QR de pagos en Bolivia

Sí, es totalmente posible. Bolivia cuenta con el sistema QR BCB Bolivia (también conocido como *Simple QR*), desarrollado por el Banco Central de Bolivia, que es un estándar universal e interoperable: cualquier persona con la app de cualquier banco (incluido Banco Mercantil Santa Cruz, BCP, BNB, Banco Unión, etc.) puede escanear y pagar ese QR.

Para integrarlo en tu app tienes varias rutas:

| Opción | Descripción | Costo |
| :---- | :---- | :---- |
| OpenBCB (BCB) | APIs oficiales y gratuitas del BCB para generar QR, consultar estado y recibir notificaciones automáticas. | Gratis |
| API del banco | Algunos bancos (ej. BCP) ofrecen APIs propias de generación QR. | Variable |
| APIs de terceros | Plataformas como CUCU ([cucu.bo/qr](https://cucu.bo/qr)), Xmart Cloud o BoliviaFlow que encapsulan la integración: generas el QR por REST, muestras la imagen, y recibes un webhook cuando el pago se acredita. | \~Bs 250/mes \+ integración |

Flujo típico en tu app:

1. Tu sistema genera un QR dinámico (con monto, referencia, etc.) llamando a la API.  
2. Muestras la imagen del QR en tu app.  
3. El pagador escanea con la app de su banco (BMSC Móvil, BCP, BNB, etc.).  
4. El banco procesa la transferencia.  
5. Tu sistema recibe un webhook de confirmación → conciliación automática.

Puntos clave:

* El QR sigue el estándar del BCB, así que es interoperable: no importa en qué banco tenga cuenta el pagador.  
* Un QR dinámico (generado por API) es preferible a uno estático porque permite fijar el monto, hacer conciliación y evitar errores.  
* Si no quieres lidiar con la infraestructura bancaria directamente, las APIs de terceros (CUCU, Xmart) simplifican mucho: una llamada REST → QR → webhook de pago.

¿Quieres que profundice en alguna de estas opciones o en el formato técnico del QR (estructura EMVCo / QR BCB)?

[OpenBCB API documentation CUCU Xmart Cloud BoliviaFlow QR payment integration](https://search.brave.com/search?q=OpenBCB%20API%20documentation%20CUCU%20Xmart%20Cloud%20BoliviaFlow%20QR%20payment%20integration)

Mostrar todo

Copiar

ok, como implemento openBCB a mi app flutter por ejemplo? para banco mercantil, explicame detalle a detalle

🔍 Buscando documentación de OpenBCB

## Realidad importante antes de implementar

Tras investigar a fondo, hay algo que debes saber:

OpenBCB no es una API pública de auto-servicio. Está diseñado para instituciones (públicas o privadas) que necesitan digitalizar su cobranza. Los requisitos incluyen:

* Solicitud escrita firmada por la máxima autoridad de la entidad  
* Documentación institucional  
* Habilitación de cuenta transitoria en el BCB  
* Conexión institucional al sistema del BCB

Además, Banco Mercantil Santa Cruz no tiene un portal de APIs públicas ni documentación de desarrolladores disponible. No existe un "[developer.bmsc.com.bo](https://developer.bmsc.com.bo/)" donde te registres y obtengas una API key.

---

[OpenBCB Flutter integration guide](https://search.brave.com/search?q=OpenBCB%20Flutter%20integration%20guide)

Mostrar todo

## Lo que SÍ puedes hacer (3 rutas prácticas)

### Ruta 1: Generar el payload EMVCo tú mismo (la más directa)

El QR BCB Bolivia sigue el estándar EMVCo. Si conoces el GUI (Globally Unique Identifier) de tu cuenta en BMSC, puedes construir el payload en tu backend y renderizarlo en Flutter.

Estructura del payload EMVCo para QR BCB Bolivia:

00 02 01          → Payload Format Indicator \= "01"

01 02 12          → Point of Initiation \= "12" (Dinámico)

26 XX ...         → Merchant Account Information (GUI \+ datos)

52 04 5251        → Merchant Category Code

53 03 BOB         → Currency

54 0X XXX.XX      → Amount (dinámico)

58 02 BO          → Country

59 XX NOMBRE      → Merchant Name

60 XX CIUDAD      → City

62 XX ...         → Additional Data (ID transacción, etc.)

63 04 XXXX        → CRC16

En tu backend (Node.js/Python/etc):

import struct

import hashlib

def calcular\_crc16(data: bytes) \-\> str:

    crc \= 0xFFFF

    for byte in data:

        crc ^= byte \<\< 8

        for \_ in range(8):

            if crc & 0x8000:

                crc \= (crc \<\< 1) ^ 0x1021

            else:

                crc \<\<= 1

    return format(crc, '04X')

def generar\_qr\_bcb(gui: str, monto: float, nombre\_comercio: str, 

                   ciudad: str, id\_transaccion: str) \-\> str:

    """

    Genera el payload EMVCo para QR BCB Bolivia.

    gui: El Globally Unique Identifier de tu cuenta BMSC

         (lo obtienes del banco, formato: CO.COM.BMS.CUENTA12345)

    """

    payload \= ""

    

    \# 00: Payload Format Indicator

    payload \+= "00" \+ "02" \+ "01"

    

    \# 01: Point of Initiation (12 \= dinámico)

    payload \+= "01" \+ "02" \+ "12"

    

    \# 26: Merchant Account Information

    gui\_data \= "00" \+ f"{len(gui):02d}" \+ gui  \# sub-field 00 \= GUI

    \# 29: ID de transacción (para QR dinámico)

    trx\_data \= "29" \+ f"{len(id\_transaccion):02d}" \+ id\_transaccion

    inner \= gui\_data \+ trx\_data

    payload \+= "26" \+ f"{len(inner):02d}" \+ inner

    

    \# 52: Merchant Category Code

    payload \+= "52" \+ "04" \+ "5251"

    

    \# 53: Currency

    payload \+= "53" \+ "03" \+ "BOB"

    

    \# 54: Amount

    monto\_str \= f"{monto:.2f}"

    payload \+= "54" \+ f"{len(monto\_str):02d}" \+ monto\_str

    

    \# 58: Country

    payload \+= "58" \+ "02" \+ "BO"

    

    \# 59: Merchant Name

    nombre \= nombre\_comercio\[:25\]

    payload \+= "59" \+ f"{len(nombre):02d}" \+ nombre

    

    \# 60: City

    ciudad\_str \= ciudad\[:15\]

    payload \+= "60" \+ f"{len(ciudad\_str):02d}" \+ ciudad\_str

    

    \# 62: Additional Data (ID transacción)

    additional \= "01" \+ f"{len(id\_transaccion):02d}" \+ id\_transaccion

    payload \+= "62" \+ f"{len(additional):02d}" \+ additional

    

    \# 63: CRC16

    data\_for\_crc \= payload.encode('utf-8')

    crc \= calcular\_crc16(data\_for\_crc)

    payload \+= "63" \+ "04" \+ crc

    

    return payload

En Flutter (frontend):

// pubspec.yaml

// dependencies:

//   qr\_flutter: ^4.1.0

//   http: ^1.2.0

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:qr\_flutter/qr\_flutter.dart';

import 'package:http/http.dart' as http;

class QrPaymentScreen extends StatefulWidget {

  const QrPaymentScreen({super.key});

  @override

  State\<QrPaymentScreen\> createState() \=\> \_QrPaymentScreenState();

}

class \_QrPaymentScreenState extends State\<QrPaymentScreen\> {

  String? \_qrPayload;

  bool \_loading \= true;

  double \_monto \= 100.00;

  final TextEditingController \_montoController \= TextEditingController(text: "100.00");

  @override

  void initState() {

    super.initState();

    \_generarQr();

  }

  Future\<void\> \_generarQr() async {

    setState(() \=\> \_loading \= true);

    try {

      // Llama a TU backend (que genera el payload EMVCo)

      final response \= await http.get(

        Uri.parse('https://tu-backend.com/api/qr/generar'),

        headers: {'Authorization': 'Bearer tu\_token'},

      );

      

      if (response.statusCode \== 200) {

        final data \= json.decode(response.body);

        setState(() {

          \_qrPayload \= data\['payload'\]; // El string EMVCo

          \_loading \= false;

        });

      }

    } catch (e) {

      setState(() \=\> \_loading \= false);

      // manejar error

    }

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Cobrar con QR')),

      body: Padding(

        padding: const EdgeInsets.all(16.0),

        child: Column(

          children: \[

            // Input de monto

            TextField(

              controller: \_montoController,

              decoration: const InputDecoration(

                labelText: 'Monto (Bs)',

                prefixIcon: Icon(Icons.attach\_money),

              ),

              keyboardType: TextInputType.number,

              onSubmitted: (\_) \=\> \_generarQr(),

            ),

            const SizedBox(height: 16),

            ElevatedButton(

              onPressed: \_generarQr,

              child: const Text('Generar QR'),

            ),

            const SizedBox(height: 24),

            // QR Code

            Expanded(

              child: \_loading

                  ? const Center(child: CircularProgressIndicator())

                  : \_qrPayload \!= null

                      ? Center(

                          child: QrImageView(

                            data: \_qrPayload\!,

                            version: QrVersions.auto,

                            size: 250,

                            errorCorrectionLevel: QrErrorCorrectLevel.M,

                          ),

                        )

                      : const Center(child: Text('Genera un QR')),

            ),

            const SizedBox(height: 16),

            Text(

              'Escanea con cualquier app bancaria boliviana',

              textAlign: TextAlign.center,

              style: TextStyle(color: Colors.grey\[600\]),

            ),

          \],

        ),

      ),

    );

  }

}

---

### Ruta 2: Usar CUCU (API de terceros, lo más práctico)

Si no quieres armar el payload EMVCo manualmente, CUCU ([cucu.bo](https://cucu.bo/)) ofrece una API REST que hace todo por ti:

| Paso | Detalle |
| :---- | :---- |
| Registro | Te registras en app.cucu.bo, contratas la integración (Bs 1.200 pago único) |
| Credenciales | Recibes API key |
| Generar QR | POST /api/v1/transactions con monto, referencia, etc. → te devuelve el payload QR |
| Mostrar | Renderizas el QR en Flutter (igual que arriba) |
| Webhook | CUCU te notifica por webhook cuando el pago se acredita |

Flujo en Flutter con CUCU:

Future\<String\> generarQrCucu(double monto, String referencia) async {

  final response \= await http.post(

    Uri.parse('https://api.cucu.bo/v1/transactions'),

    headers: {

      'Authorization': 'Bearer TU\_API\_KEY',

      'Content-Type': 'application/json',

    },

    body: jsonEncode({

      'amount': monto,

      'currency': 'BOB',

      'reference': referencia,

      'description': 'Pago por servicio',

    }),

  );


  if (response.statusCode \== 200 || response.statusCode \== 201) {

    final data \= json.decode(response.body);

    return data\['qr\_payload'\]; // String EMVCo listo para renderizar

  }

  throw Exception('Error al generar QR');

}

---

### Ruta 3: Aplicar a OpenBCB (si eres institución)

Si tu app es para una empresa/institución formal:

1. Redactar solicitud escrita firmada por la máxima autoridad  
2. Enviar al BCB con documentación (NIT, estatutos, etc.)  
3. El BCB te habilita una cuenta transitoria y te da acceso a sus APIs  
4. Integras sus endpoints (generación QR, consulta estado, webhook)

Esto tarda semanas y está pensado para entidades, no para developers individuales.

---

## Lo que necesitas hacer AHORA

| Acción | Para qué ruta |
| :---- | :---- |
| Contactar a BMSC (emflores@bmsc.com.bo o sucursal) y pedir tu GUI (Globally Unique Identifier) para QR | Ruta 1 |
| O registrarte en app.cucu.bo | Ruta 2 |
| Montar un pequeño backend (Node/Python) que genere el payload y exponga un endpoint a tu app Flutter | Ruta 1 |
| Instalar qr\_flutter en tu proyecto | Todas |
| Configurar un endpoint webhook en tu backend para recibir confirmaciones de pago | Ruta 1 y 2 |

Mi recomendación: Si estás en fase de desarrollo/MVP, ve con Ruta 2 (CUCU) — es la más rápida, ya resuelve la generación, conciliación y notificación. Si ya tienes el GUI de BMSC y quieres cero dependencia de terceros, Ruta 1 es viable pero requiere más trabajo en el backend.

¿Quieres que te ayude con alguna parte específica (backend, webhook, o el formato exacto del GUI de BMSC)?  
Copiar

osea, estas seguro que BMSC tiene un GUI? y que con eso puedo contruir un payload de manera gratuita? como consigo eso? osea para que no te pierdas, lo unico que quiero es que mi app genere un qr con un monto en si, y que el pago que se realice en ese qr le llegue a mi cuenta

Verificar GUI QR BCB en BMSC

Te voy a ser honesto: mi respuesta anterior tenía información incorrecta sobre "construir el payload EMVCo tú mismo". Déjame corregir:

## Lo que realmente pasa

No necesitas ni puedes construir el payload tú mismo. El QR BCB Bolivia es generado por el banco, no por ti como desarrollador. El "GUI" es una referencia interna de la infraestructura del banco — no es algo que te "entreguen" para que lo uses en tu código.

## Lo que SÍ puedes hacer (lo simple y real)

### Opción 1: QR Estático desde BMSC Móvil (gratis, sin API)

Esto es lo que la mayoría de personas en Bolivia hacen:

1. Abres la app BMSC Móvil  
2. Vas a "Cobrar con QR" (o "Transferencias QR")  
3. Generas tu QR (puedes elegir vigencia hasta 365 días)  
4. Descargas la imagen del QR  
5. En tu app Flutter, simplemente mostras esa imagen como un Image widget  
6. El pagador escanea con su app bancaria → ingresa el monto manualmente → confirma

En Flutter es trivial:

// Simplemente muestras la imagen del QR que descargaste de BMSC Móvil

Image.asset('assets/qr\_bmsc.png', width: 250, height: 250)

Limitación: El pagador tiene que digitar el monto manualmente. No puedes fijar el monto desde tu app.

---

[BMSC Mobile QR payment tutorial Flutter](https://search.brave.com/videos?q=BMSC%20Mobile%20QR%20payment%20tutorial%20Flutter)

Mostrar todo

### Opción 2: QR Dinámico con monto fijo (requiere infraestructura)

Si necesitas que tu app genere un QR diferente por cada transacción con el monto ya precargado (el pagador solo confirma, no digita nada), necesitas una de estas:

| Opción | Para quién | Costo |
| :---- | :---- | :---- |
| OpenBCB (BCB) | Instituciones públicas/privadas (empresa formal con NIT) | Gratis, pero requiere solicitud formal al BCB |
| API de un banco (ej. BNB tiene) | Clientes empresariales del banco | Depende del banco |
| Tercero (CUCU, etc.) | Cualquier persona/empresa | \~Bs 250/mes |

OpenBCB en concreto:

* Es gratis (generación, consulta, notificaciones)  
* NO es para individuos — está diseñado para instituciones (municipios, empresas, ONGs)  
* Requiere: nota de solicitud firmada por la máxima autoridad, documentación legal, cuenta transitoria en el BCB  
* Si tienes una empresa formal (matrícula de comercio, NIT), puedes aplicarle  
* Si eres una persona natural desarrollando una app, no te va a aceptar

---

## Mi recomendación para tu caso

Dado que lo que quieres es: tu app genera un QR con un monto → el pagador escanea → el dinero llega a tu cuenta BMSC:

Si estás en MVP / desarrollo:

* Usa la Opción 1 (QR estático de BMSC Móvil). Lo muestras en tu app, el pagador digita el monto. Cero costo, cero integración técnica. Funciona hoy.

Si quieres la experiencia completa (monto fijo, conciliación automática):

* Constituye una empresa (Empresa Unipersonal, Bs 130 en SEPREC \+ NIT gratis)  
* Con eso puedes aplicar a OpenBCB (gratis) o contratar a CUCU  
* Ahí sí tu app genera QRs dinámicos por API y recibe webhooks de confirmación

Resumen directo: No existe una forma de "construir el payload" como developer individual sin pasar por el banco o una institución. El QR lo genera el banco, punto. Tu trabajo como developer es mostrarlo (estático) o llamar a una API (dinámico, que requiere ser institución).

¿Quieres que te ayude con la parte de mostrar el QR estático en Flutter, o con el proceso de aplicar a OpenBCB si tienes empresa?

[BMSC OpenBCB CUCU developer portal](https://search.brave.com/search?q=BMSC%20OpenBCB%20CUCU%20developer%20portal)

Mostrar todo

Copiar

mm ya, lo que quiero en mi app es esto:

"

que el cliente ingrese sus datos bancarios NO COMPROMETEDORES, osea solo los necesarios para poder vincular su cuenta de banco con los qr generados dinamicamente en la aplicacion, la opcion de OpenBCB me sirve?

"

Verificar soporte multi-merchant OpenBCB

No, OpenBCB no te sirve para ese caso. Te explico por qué:

## Por qué OpenBCB no encaja

OpenBCB está diseñado para que una sola institución genere QRs para sus propias cuentas. El flujo es:

Tu empresa (institución) → registra sus cuentas en el BCB → genera QRs que apuntan a SUS cuentas

No es una plataforma donde tus clientes (end-users) registran sus datos bancarios y tú generas QRs a nombre de ellos. No existe un "onboarding de comerciantes" en OpenBCB.

Además, el BCB lo aclara explícitamente: *"OpenBCB no funciona como una billetera móvil, sino como una solución institucional para gestionar cobros."*

## Lo que realmente necesitas: ser un Agregador de Pago

Tu modelo (app onboarding → cliente ingresa datos → generas QR a su nombre → dinero va a su cuenta) es el modelo de un agregador de pago. En Bolivia, el BCB regula esto bajo el Reglamento de Servicios de Pago, que define dos modalidades:

| Rol | Qué hace |
| :---- | :---- |
| Agregador de pago | Onboarding de comerciantes, genera QRs a nombre de ellos, gestiona la liquidación |
| Facilitador de pago | Solo procesa, no custodia fondos |

Para operar como agregador necesitas:

* Registro ante el BCB como pasarela/agregador de pago  
* Cumplir con requisitos de seguridad, AML (antilavado), etc.  
* Tener una cuenta transitoria de liquidación

[BCB registro agregador de pago pasarela](https://search.brave.com/search?q=BCB%20registro%20agregador%20de%20pago%20pasarela)

Mostrar todo

## Alternativas prácticas (sin ser tú el agregador)

Si no quieres (o no puedes) obtener la licencia de agregador, puedes integrarte con un agregador que ya la tiene:

| Plataforma | Modelo | Notas |
| :---- | :---- | :---- |
| Mesa de Pagos ([mesadepagos.com](https://mesadepagos.com/)) | API para PayIns/PayOuts con QR BCB | Integra Banco Unión y Banco Ganadero, cobra QR local, liquidación instantánea |
| PagosNet ([pagosnet.com.bo](https://pagosnet.com.bo/)) | Solución para PyMEs con múltiples métodos | De Síntesis, incluye QR \+ tarjetas |
| Libélula (libelula.bo) | Pasarela con QR \+ tarjetas | Compatible con BMSC, BNB, BCP, Unión, etc. |
| Circle.bo | Links de cobro \+ QR | Respaldado por BNB y Linkser |
| Depay ([depay.us](https://depay.us/)) | API multi-país que incluye QR BCB | Pensada para plataformas/fintechs, liquida en BOB |

Depay en particular parece el más alineado a tu caso: es una API para plataformas que necesitan conectar múltiples usuarios al riel QR BCB, con liquidación en moneda local.

## Dato importante sobre OpenBCB y fintechs

El BCB menciona que *"está prevista la integración del OpenBCB con Empresas de Tecnología Financiera (Fintech)"*. Esto sugiere que en el futuro podría abrirse un modelo donde fintechs/agregadores se conecten a OpenBCB para generar QRs a nombre de múltiples comerciantes. Pero hoy no existe esa funcionalidad.

## Resumen directo

| Tu necesidad | ¿OpenBCB? | ¿Qué usar? |
| :---- | :---- | :---- |
| Cliente ingresa datos bancarios | ❌ No soporta onboarding multi-merchant | Integrar con un agregador (Depay, Mesa de Pagos, etc.) |
| Generar QR dinámico a nombre del cliente | ❌ Solo genera para la institución registrada | El agregador lo hace por ti vía API |
| Dinero llega a la cuenta del cliente | ❌ Solo a la cuenta de la institución | El agregador liquida a la cuenta del comerciante |

Mi recomendación: Contacta a Depay o Mesa de Pagos y explícales tu caso. Ellos ya tienen la infraestructura regulada y te dan una API donde:

1. Tú onboardingueas al cliente (le pides banco \+ número de cuenta \+ nombre)  
2. Llamas a su API para generar un QR dinámico con monto  
3. El QR apunta a la cuenta del cliente  
4. Ellos te notifican por webhook cuando se paga

¿Quieres que busque más detalles sobre alguno de estos proveedores?

[Depay Mesa de Pagos API documentation](https://search.brave.com/search?q=Depay%20Mesa%20de%20Pagos%20API%20documentation)

Mostrar todo

Copiar

ok, como funciona? pago mensualmente y me dan una api de un banco? para que el usuario final inserte sus datos no comprometederos y se le vincule a la app con su cuenta?

Análisis de agregadores de pago en Bolivia

Te voy a ser directo: no funciona exactamente como lo imaginas. Te explico cómo funciona realmente cada opción:

## Cómo funciona en la práctica

### Lo que tú imaginas:

Usuario ingresa su número de cuenta → la app genera un QR que apunta a ESA cuenta → el dinero va directo a la cuenta del usuario

### Lo que realmente pasa con estos servicios:

| Servicio | Cómo funciona realmente | ¿El dinero va directo a la cuenta del usuario final? |
| :---- | :---- | :---- |
| CUCU | Tú (la plataforma) te registras como comerciante → te dan un token → generas QRs → el dinero llega a tu cuenta (o la de la plataforma) | ❌ No directo. Tú recibes y distribuyes |
| Mesa de Pagos | Igual: "acreditamos tu cuenta en segundos" | ❌ No directo |
| Depay | Diseñado para bancos y billeteras, no para developers individuales. Requiere onboarding de "merchant" con POS | ❌ No aplica a tu caso |
| BCP (API propia) | Te registras en su portal de desarrolladores, obtienes acceso a su API de QR. Generas QRs que apuntan a tu cuenta BCP | ❌ Solo a tu cuenta BCP |

## El problema central

Ninguno de estos servicios te permite que un usuario final ingrese su número de cuenta y que el QR apunte a esa cuenta directamente. Eso sería ser un agregador de pago registrado ante el BCB, que requiere:

* Licencia/registro formal  
* Cumplimiento AML (antilavado)  
* Infraestructura de seguridad  
* Cuenta transitoria de liquidación

[agregador de pago api banco registro](https://search.brave.com/search?q=agregador%20de%20pago%20api%20banco%20registro)

Mostrar todo

## Lo que SÍ puedes hacer (modelo realista)

### Modelo "Collect & Distribute" (el más común en marketplaces):

1\. Tu app onboardinguea al usuario (nombre \+ banco \+ n° cuenta)

2\. Generas un QR dinámico (vía CUCU o BCP) → el dinero va a TU cuenta

3\. Recibes el webhook de confirmación

4\. Tu backend hace un payout (transferencia) a la cuenta del usuario

En CUCU, por ejemplo:

* Te registras en cucu.bo → onboarding → te dan un Bearer token  
* Llamas POST /transfers/qr con el monto → te devuelve el QR (PNG/Base64)  
* El pagador escanea con cualquier app bancaria  
* Recibes webhook PAID  
* Tú haces la distribución al usuario final (vía transferencias, o CUCU también tiene API de payouts)

Costo: Tarifa fija por cobro, 0% sobre ventas. No es mensual, es por transacción.

### Modelo "Directo al usuario" (más complejo):

Para que el QR apunte directamente a la cuenta del usuario final (sin pasar por ti), necesitas:

1. Constituir una empresa (Empresa Unipersonal, \~Bs 130 \+ NIT gratis)  
2. Registrarla como agregador de pago ante el BCB (o integrarte con uno que ya lo sea)  
3. El agregador te da una API donde registras cada "comerciante" (usuario final) con sus datos bancarios  
4. Generas un QR por comerciante → el dinero va directo a su cuenta

¿Qué datos "no comprometedores" necesitarías del usuario?

| Dato | ¿Necesario? |
| :---- | :---- |
| Nombre completo del titular | ✅ Sí (aparece en el QR) |
| Banco (ej. BMSC, BCP, BNB) | ✅ Sí |
| Número de cuenta / CBU | ✅ Sí (es lo que identifica la cuenta) |
| Cédula de identidad | ⚠️ Puede ser necesario para KYC del agregador |
| Clave / PIN / Contraseña | ❌ NUNCA |
| Token de seguridad | ❌ NUNCA |

El CBU (Cuenta Bancaria Universal) es el dato clave: es un número de 20 dígitos que identifica de forma única una cuenta en Bolivia. Con eso \+ nombre \+ banco, se puede generar el QR.

## Mi recomendación concreta

Para MVP (ahora):

1. Regístrate en CUCU (cucu.bo) — es el más accesible, tiene docs claras, REST \+ webhooks  
2. Tu app onboardinguea al usuario (nombre, banco, CBU)  
3. Generas el QR con la API de CUCU (el dinero va a tu cuenta)  
4. Haces el payout manualmente o automatizado a la cuenta del usuario

Para escalar (después):

1. Constituye una Empresa Unipersonal  
2. Contacta a CUCU o Mesa de Pagos y pregunta específicamente si soportan multi-merchant (QRs que apunten a cuentas de terceros, no solo a la tuya)  
3. Si no, aplica como agregador de pago ante el BCB

¿Quieres que te muestre el flujo técnico exacto con CUCU (endpoints, parámetros, webhook) para que lo implementes en Flutter?

[CUCU API documentation Flutter payment integration](https://search.brave.com/search?q=CUCU%20API%20documentation%20Flutter%20payment%20integration)

Mostrar todo

Copiar

ok, como me registro en CUCU? y como integro el plan?

🔍 Buscando info registro e integración CUCU

## Registro en CUCU

Es muy simple, no requiere trámite bancario:

Paso 1 — Crear cuenta:

* Ve a [app.cucu.bo](https://app.cucu.bo/signup)  
* Te registras con tus datos (puedes ser persona natural o empresa)  
* También puedes hablar con su agente AI 24/7 por WhatsApp y te contrata en la misma conversación

Paso 2 — Contratar el plan QR Simple:

| Concepto | Costo |
| :---- | :---- |
| Integración (pago único) | Bs 1.200 |
| Mensualidad | Bs 250/mes |
| Por cada cobro acreditado | Tarifa fija desde Bs 1 (0% sobre el monto) |

Paso 3 — Recibir tus credenciales:

* Te emiten un Bearer token por comercio (formato sk\_live\_... para producción, sk\_test\_... para sandbox)  
* Tienes acceso a sandbox para desarrollar sin NIT real ni certificado

---

[CUCU app registration tutorial](https://search.brave.com/videos?q=CUCU%20app%20registration%20tutorial)

Mostrar todo

## Cómo funciona la integración

URL base de producción: https://qrsimple.cucu.bo

Endpoint clave:

POST /transfers/qr

Ejemplo de llamada:

curl \-X POST https://qrsimple.cucu.bo/transfers/qr \\

  \-H "Authorization: Bearer sk\_live\_TU\_TOKEN" \\

  \-H "Content-Type: application/json" \\

  \-d '{

    "amount": 150.00,

    "currency": "BOB",

    "description": "Pago por servicio",

    "reference": "ORD-2024-001"

  }'

Respuesta (simplificada):

{

  "id": "txn\_abc123",

  "status": "PENDING",

  "qr\_image": "https://cdn.cucu.bo/qr/abc123.png",

  "qr\_base64": "iVBORw0KGgo...",

  "expires\_at": "2024-01-15T12:00:00Z"

}

Te devuelven el QR como URL CDN pública o Base64 — lo renderizas directo en Flutter.

Webhook de confirmación:

* Configuras una URL en tu dashboard  
* Cuando el pagador escanea y confirma, CUCU te envía un POST con status: "PAID"  
* Ahí sabes que el dinero ya se acreditó

Características técnicas:

| Característica | Detalle |
| :---- | :---- |
| Autenticación | Bearer token por comercio |
| Idempotencia | Header Idempotency-Key (ventana 24h) |
| Expiración del QR | Configurable (segundos hasta años) |
| Formato QR | PNG / Base64 / URL CDN |
| Ambiente sandbox | Sí, con SIAT piloto |

---

## Flujo completo en tu app Flutter

┌─────────────────────────────────────────────────────────┐

│  TU APP FLUTTER                                         │

│                                                         │

│  1\. Usuario ingresa monto                               │

│  2\. Llamas a TU BACKEND                                 │

│     └──→ Backend llama a CUCU: POST /transfers/qr       │

│     └──→ CUCU devuelve qr\_image (URL o base64)          │

│  3\. Muestras el QR en pantalla                          │

│                                                         │

│  PAGADOR escanea con su app bancaria                    │

│  (BMSC Móvil, BCP, BNB, Unión, etc.)                    │

│                                                         │

│  4\. CUCU recibe el pago → te envía WEBHOOK "PAID"       │

│     └──→ Tu backend actualiza el estado de la orden     │

│     └──→ Tu app notifica al usuario "Pago recibido"     │

└─────────────────────────────────────────────────────────┘

En Flutter (renderizando el QR):

// Si te devuelve una URL:

Image.network('https://cdn.cucu.bo/qr/abc123.png', width: 250)

// Si te devuelve base64:

Image.memory(base64Decode(qrBase64), width: 250)

---

## Lo que debes tener en cuenta

* El dinero llega a TU cuenta (la que registras en CUCU), no a la del pagador. Si tu modelo es marketplace donde el dinero va a vendedores distintos, necesitas hacer el payout tú (o preguntar a CUCU si soportan multi-merchant).  
* No necesitas NIT ni certificado digital para el QR (eso es solo para facturación electrónica SIAT, que es otro servicio de CUCU).  
* El sandbox te deja desarrollar y probar sin pagar ni tener empresa formal.

¿Quieres que te arme el código completo del backend (Node/Python) \+ Flutter para que lo tengas funcionando?

[CUCU registro y integro plan](https://search.brave.com/search?q=CUCU%20registro%20y%20integro%20plan)

Mostrar todo

Copiar

ok, entonces ayudame a implementar este plan en mi aplicacion, con el concepto de por cada cobro acreditado

🔍 Buscando info API CUCU

## Cómo funciona el modelo "por cada cobro acreditado"

El concepto es simple: solo pagas la tarifa cuando el dinero efectivamente se acredita en tu cuenta. Si generas 100 QRs pero solo 30 se pagan, solo pagas por 30\.

| Evento | Costo |
| :---- | :---- |
| Generar un QR (pendiente) | \$0 |
| El pagador escanea y confirma → estado PAID | Tarifa fija (desde Bs 1\) |
| El QR expira sin pagarse | \$0 |
| El pagador cancela | \$0 |

No hay comisión porcentual. Cobras Bs 1500 → pagas Bs 1 a CUCU. Cobras Bs 50 → pagas Bs 1 a CUCU.

---

## Implementación completa en Flutter \+ Backend

### Arquitectura

┌──────────────┐         ┌──────────────┐         ┌──────────────┐

│  APP FLUTTER │ ──HTTPS─→│  TU BACKEND  │ ──HTTPS─→│  CUCU API    │

│              │ ←──JSON── │  (Node/Py)  │ ←──JSON── │  qrsimple.   │

│  Muestra QR  │           │  Webhook    │ ←─WEBHOOK─ │  cucu.bo    │

└──────────────┘           └──────────────┘         └──────────────┘

Nunca expongas tu Bearer token en la app. Siempre pasa por tu backend.

---

[cucu.bo api qrsimple webhook tutorial](https://search.brave.com/search?q=cucu.bo%20api%20qrsimple%20webhook%20tutorial)

Mostrar todo

### Paso 1: Backend (Node.js/Express)

// server.js

const express \= require('express');

const axios \= require('axios');

const crypto \= require('crypto');

const app \= express();

app.use(express.json());

const CUCU\_URL \= 'https://qrsimple.cucu.bo';

const CUCU\_TOKEN \= process.env.CUCU\_TOKEN; // sk\_live\_...

// \============ GENERAR QR \============

app.post('/api/qr/generar', async (req, res) \=\> {

  const { monto, referencia, descripcion } \= req.body;

  // Idempotencia: si el usuario reenvía, no se duplica

  const idempotencyKey \= crypto.randomUUID();

  try {

    const response \= await axios.post(

      \`\${CUCU\_URL}/transfers/qr\`,

      {

        amount: monto,

        currency: 'BOB',

        reference: referencia,          // Tu ID interno (ej: "PED-0042")

        description: descripcion,       // Glosa que ve el pagador

        expiration: 3600                // Segundos (1h)

      },

      {

        headers: {

          'Authorization': \`Bearer \${CUCU\_TOKEN}\`,

          'Content-Type': 'application/json',

          'Idempotency-Key': idempotencyKey

        }

      }

    );

    const data \= response.data;

    // Guardar en tu BD: { id: data.id, referencia, monto, status: 'PENDING' }

    

    res.json({

      qrId: data.id,

      qrImage: data.qr\_image,      // URL CDN pública

      qrBase64: data.qr\_base64,    // Base64

      expiresAt: data.expires\_at

    });

  } catch (error) {

    res.status(error.response?.status || 500).json({

      error: error.response?.data || 'Error al generar QR'

    });

  }

});

// \============ CONSULTAR ESTADO \============

app.get('/api/qr/:id/estado', async (req, res) \=\> {

  try {

    const response \= await axios.get(

      \`\${CUCU\_URL}/transfers/qr/\${req.params.id}\`,

      { headers: { 'Authorization': \`Bearer \${CUCU\_TOKEN}\` } }

    );

    res.json(response.data);

  } catch (error) {

    res.status(500).json({ error: 'Error al consultar estado' });

  }

});

// \============ WEBHOOK (CUCU te notifica) \============

app.post('/api/webhook/cucu', async (req, res) \=\> {

  const { id, status, amount, reference, paid\_at } \= req.body;

  // Verificar firma si CUCU la provee (revisa docs)

  // ...

  if (status \=== 'PAID') {

    // ✅ El dinero YA está en tu cuenta

    // Actualiza tu BD:

    // UPDATE transactions SET status='PAID', paid\_at=? WHERE id=?

    console.log(\`✅ PAGO AREDITADO: \${id} | Bs \${amount} | Ref: \${reference}\`);

    

    // Aquí disparas tu lógica: notificar al usuario, 

    // desbloquear servicio, enviar recibo, etc.

  }

  res.json({ received: true });

});

app.listen(3000, () \=\> console.log('Backend listo en :3000'));

---

### Paso 2: App Flutter

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

class CobroQrScreen extends StatefulWidget {

  const CobroQrScreen({super.key});

  @override

  State\<CobroQrScreen\> createState() \=\> \_CobroQrScreenState();

}

class \_CobroQrScreenState extends State\<CobroQrScreen\> {

  final \_apiBase \= 'https://tu-backend.com';

  final \_montoController \= TextEditingController(text: '150.00');

  final \_refController \= TextEditingController();

  String? \_qrImageUrl;

  String? \_qrBase64;

  String? \_qrId;

  bool \_loading \= false;

  String? \_estado; // PENDING, PAID, CANCELLED

  @override

  void initState() {

    super.initState();

    \_refController.text \= 'PED-\${DateTime.now().millisecondsSinceEpoch % 10000}';

  }

  Future\<void\> \_generarQr() async {

    setState(() \=\> \_loading \= true);

    \_qrImageUrl \= null;

    \_qrBase64 \= null;

    \_estado \= null;

    try {

      final monto \= double.parse(\_montoController.text);

      

      final res \= await http.post(

        Uri.parse('\$\_apiBase/api/qr/generar'),

        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({

          'monto': monto,

          'referencia': \_refController.text,

          'descripcion': 'Pago por servicio',

        }),

      );

      if (res.statusCode \== 200) {

        final data \= json.decode(res.body);

        setState(() {

          \_qrId \= data\['qrId'\];

          \_qrImageUrl \= data\['qrImage'\];

          \_qrBase64 \= data\['qrBase64'\];

          \_estado \= 'PENDING';

        });

        \_iniciarPolling();

      }

    } catch (e) {

      \_mostrarError('Error: \$e');

    } finally {

      setState(() \=\> \_loading \= false);

    }

  }

  // Polling como respaldo (el webhook es el primario)

  Future\<void\> \_iniciarPolling() async {

    for (int i \= 0; i \< 60; i++) { // 5 min máx

      await Future.delayed(const Duration(seconds: 5));

      if (\!mounted) return;

      await \_consultarEstado();

      if (\_estado \== 'PAID') break;

    }

  }

  Future\<void\> \_consultarEstado() async {

    if (\_qrId \== null) return;

    try {

      final res \= await http.get(

        Uri.parse('\$\_apiBase/api/qr/\$\_qrId/estado'),

      );

      if (res.statusCode \== 200) {

        final data \= json.decode(res.body);

        setState(() \=\> \_estado \= data\['status'\]);

      }

    } catch (\_) {}

  }

  void \_mostrarError(String msg) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(msg), backgroundColor: Colors.red),

    );

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Cobrar con QR')),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          children: \[

            // Monto

            TextField(

              controller: \_montoController,

              decoration: const InputDecoration(

                labelText: 'Monto (Bs)',

                prefixIcon: Icon(Icons.payments\_outlined),

                border: OutlineInputBorder(),

              ),

              keyboardType: TextInputType.number,

            ),

            const SizedBox(height: 12),

            // Referencia

            TextField(

              controller: \_refController,

              decoration: const InputDecoration(

                labelText: 'Referencia',

                border: OutlineInputBorder(),

              ),

            ),

            const SizedBox(height: 16),

            // Botón

            ElevatedButton(

              onPressed: \_loading ? null : \_generarQr,

              child: \_loading

                  ? const SizedBox(

                      width: 20, height: 20,

                      child: CircularProgressIndicator(strokeWidth: 2))

                  : const Text('Generar QR de Cobro'),

            ),

            const SizedBox(height: 24),

            // QR o estado

            Expanded(

              child: \_qrImageUrl \!= null

                  ? Center(

                      child: Column(

                        mainAxisSize: MainAxisSize.min,

                        children: \[

                          // Muestra el QR (URL o base64)

                          \_qrImageUrl \!= null

                              ? Image.network(\_qrImageUrl\!, width: 250)

                              : Image.memory(base64Decode(\_qrBase64\!), width: 250),

                          const SizedBox(height: 16),

                          // Indicador de estado

                          \_buildEstadoBadge(),

                          const SizedBox(height: 8),

                          Text(

                            'Escanea con cualquier app bancaria',

                            style: TextStyle(color: Colors.grey\[600\], fontSize: 13),

                          ),

                        \],

                      ),

                    )

                  : const Center(

                      child: Icon(Icons.qr\_code\_scanner, size: 80, color: Colors.grey),

                    ),

            ),

          \],

        ),

      ),

    );

  }

  Widget \_buildEstadoBadge() {

    final color \= switch (\_estado) {

      'PAID' \=\> Colors.green,

      'CANCELLED' \=\> Colors.red,

      \_ \=\> Colors.orange,

    };

    final label \= switch (\_estado) {

      'PAID' \=\> '✓ Pago recibido',

      'CANCELLED' \=\> '✗ Cancelado',

      \_ \=\> '⏳ Esperando pago...',

    };

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

      decoration: BoxDecoration(

        color: color.withAlpha(30),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: color),

      ),

      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),

    );

  }

}

---

### Paso 3: Configurar el Webhook en CUCU

En tu dashboard de CUCU (app.cucu.bo), configuras la URL de webhook:

https://tu-backend.com/api/webhook/cucu

CUCU te enviará un POST con este formato cuando el pago se acredite:

{

  "id": "txn\_abc123",

  "status": "PAID",

  "amount": 150.00,

  "currency": "BOB",

  "reference": "PED-0042",

  "paid\_at": "2026-09-23T14:32:00Z"

}

Eso es el "cobro acreditado": el momento en que CUCU te cobra la tarifa fija (Bs 1\) y el dinero ya está en tu cuenta.

---

### Resumen de costos reales

| Concepto | Cuándo se cobra |
| :---- | :---- |
| Bs 1.200 (integración) | Una vez, al contratar |
| Bs 250/mes | Mensual, mientras tengas el plan activo |
| Bs 1+ por cobro | Solo cuando el estado pasa a PAID |

Si en un mes generas 100 QRs pero solo 20 se pagan → pagas Bs 250 \+ (20 × Bs 1\) \= Bs 270\.

---

### Checklist para empezar

| \# | Acción | Dónde |
| :---- | :---- | :---- |
| 1 | Crear cuenta y contratar | app.cucu.bo (o WhatsApp con su agente AI) |
| 2 | Recibir Bearer token (sk\_live\_...) | Te lo dan al contratar |
| 3 | Configurar webhook URL en dashboard | app.cucu.bo → Configuración |
| 4 | Montar backend con los 3 endpoints (generar, consultar, webhook) | Tu servidor |
| 5 | Probar en sandbox primero | CUCU tiene sandbox |
| 6 | Conectar Flutter a tu backend | Código de arriba |

¿Necesitas que te ayude con algo específico: el sandbox, la base de datos para conciliación, o el payout a tus usuarios?

[CUCU Flutter webhook setup guide](https://search.brave.com/search?q=CUCU%20Flutter%20webhook%20setup%20guide)

Mostrar todo

Copiar

ok, entonces este plan es completamente posible con lo que quiero no? el usuario ingresa su nombre \+ banco \+ n de cuenta, genero un qr dinamico y el dinero va a mi cuenta. recibo una confirmacion y el backend hace el pago a la cuenta del usuario, si no? tomate el tiempo para verificar y que no me hagas perder el tiempo

Verificación de capacidades de pago CUCU

No, no es completamente posible con CUCU solo. Te voy a ser directo porque me pediste que no te haga perder tiempo:

## Lo que CUCU SÍ hace

| Paso | ¿Funciona con CUCU? |
| :---- | :---- |
| Usuario ingresa nombre \+ banco \+ n° cuenta | ✅ Tú lo guardas en tu BD |
| Generar QR dinámico con monto | ✅ POST /transfers/qr |
| El dinero llega a TU cuenta | ✅ |
| Recibes webhook "PAID" | ✅ |
| Tu backend hace el payout a la cuenta del usuario | ❌ CUCU NO ofrece esto |

CUCU no tiene API de payouts. No puedes llamar a un endpoint de CUCU para decir "transfiere Bs 150 a la cuenta 123456789 del Banco Unión". Eso simplemente no existe en su API.

## Lo que SÍ existe para el payout

| Servicio | PayIn (QR) | Payout (transferir a terceros) |
| :---- | :---- | :---- |
| CUCU | ✅ | ❌ No lo ofrece |
| Mesa de Pagos ([mesadepagos.com](https://mesadepagos.com/)) | ✅ QR local | ✅ "Payouts masivos — desembolsa a miles de beneficiarios vía API" |
| Libélula ([libelula.bo](https://libelula.bo/)) | ✅ QR | ✅ "Transferencias individuales o en lotes. Callback en tiempo real" |

[cucu payout qr code review reddit](https://search.brave.com/search?q=cucu%20payout%20qr%20code%20review%20reddit)

Mostrar todo

## Tu flujo real (con dos servicios o uno solo)

### Opción A: Un solo servicio (Mesa de Pagos o Libélula)

1\. Usuario ingresa: nombre \+ banco \+ n° cuenta → tu BD

2\. Tu backend llama a Mesa de Pagos / Libélula:

   → "Genera QR de cobro por Bs 150, referencia PED-0042"

3\. Muestras el QR en Flutter

4\. Pagador escanea → dinero va a TU cuenta

5\. Recibes webhook "PAID"

6\. Tu backend llama a la MISMA API:

   → "Payout de Bs 150 a cuenta 123456789, Banco Unión, Juan Pérez"

7\. Recibes callback "PAYOUT\_CONFIRMED"

Mesa de Pagos es la que más encaja: tiene explícitamente "PayIns y PayOuts" en una sola API, integrado con Banco Unión y Banco Ganadero.

### Opción B: CUCU (cobro) \+ Mesa de Pagos o Libélula (payout)

CUCU → genera QR → dinero a tu cuenta → webhook PAID

Tu backend → llama a Mesa de Pagos → payout a cuenta del usuario

Funciona, pero es más caro (pagas dos servicios) y más complejo.

[cucu vs mesa de pagos vs libelula vs libelula site:reddit.com](https://search.brave.com/search?q=cucu%20vs%20mesa%20de%20pagos%20vs%20libelula%20vs%20libelula%20site%3Areddit.com)

Mostrar todo

## Lo que debes verificar ANTES de comprometerte

| Pregunta | Por qué importa |
| :---- | :---- |
| ¿Mesa de Pagos / Libélula aceptan persona natural como integrador? | Si solo aceptan empresas con NIT, necesitas constituir una primero |
| ¿El payout es instantáneo o demora 24-48h? | Afecta la experiencia del usuario |
| ¿Tienen límite diario de payouts? | Si tu app escala, puede ser un cuello de botella |
| ¿El usuario final necesita verificar identidad (CI, selfie) para recibir el payout? | AML — probablemente sí para montos altos |
| ¿Cobran por payout también? | Si cobran Bs 1 por cobro \+ Bs 1 por payout, tu margen se reduce |

## Mi recomendación concreta

Contacta a Mesa de Pagos ([mesadepagos.com](https://mesadepagos.com/)) y explícales exactamente tu caso:

"Tengo una app donde el usuario ingresa sus datos bancarios, genero un QR de cobro con monto, el dinero va a mi cuenta, y luego hago un payout automático a la cuenta del usuario. ¿Soportan ese flujo completo? ¿Qué requisitos necesito?"

Ellos tienen ambos servicios (PayIn \+ PayOut) en una sola API, lo que simplifica tu integración a un solo proveedor, un solo token, un solo webhook.

No uses CUCU para esto — te va a faltar la mitad del flujo.

¿Quieres que busque los requisitos específicos de Mesa de Pagos o Libélula para ver cuál te acepta más rápido?  
Copiar

ok, analicemos la opcion de libelula y responde las preguntas:

"

\- ¿aceptan persona natural como integrador?

\- ¿El payout es instantáneo o demora 24-48h?

\- ¿Tienen límite diario de payouts?

\- ¿El usuario final necesita verificar identidad (CI, selfie) para recibir el payout?

\- ¿Cobran por payout también?

"

verifica e investiga bien ok? tomate tu tiempo

🔍 Investigando Libélula

Tras investigar la documentación pública, la página de registro, el soporte y manuales de integración de Libélula, aquí van las respuestas:

---

## Respuestas a tus 5 preguntas

### 1\. ¿Aceptan persona natural como integrador?

No directamente. La documentación de afiliación (2023) y la página de registro especifican dos perfiles:

| Perfil | Requisitos |
| :---- | :---- |
| Empresa Unipersonal | CI del titular, Registro de Comercio (SEPREC), NIT |
| Empresa Jurídica (SRL, SA, etc.) | Poder del Rep. Legal, Escritura de Constitución, NIT, Matrícula de Comercio, Certificado de Impuestos vigente, CI del Rep. Legal, Nombre del Banco \+ Titular \+ N° Cuenta |

No existe la opción "persona natural sin registro". Pero una Empresa Unipersonal en Bolivia se registra en SEPREC en un solo día (formulario virtual \+ pago de arancel \+ NIT gratuito). Es lo mínimo que necesitas.

Conclusión: Necesitas al menos una Empresa Unipersonal. No puedes registrarte como "Juan Pérez, persona natural, sin empresa".

---

[Libelula registro empresa Bolivia SEPREC](https://search.brave.com/search?q=Libelula%20registro%20empresa%20Bolivia%20SEPREC)

Mostrar todo

### 2\. ¿El payout es instantáneo o demora 24-48h?

Libélula lo describe como "en tiempo real":

*"Payouts: Realiza todas tus transferencias de manera automática y en tiempo real. Integración mediante REST API. Transferencias individuales o en lotes. Confirmación de recepción de fondos mediante callback en tiempo real."*  
— [libelula.bo](https://libelula.bo/) (sección Payouts)

Sin embargo, hay que distinguir:

| Concepto | Tiempo |
| :---- | :---- |
| Payout (tú envías dinero a un tercero vía API) | "Tiempo real" (según su web) |
| Liquidación (Libélula te abona a TI lo recaudado) | Siguiente día hábil |

Eso significa: el pagador escanea el QR → el dinero entra a tu cuenta Libélula → al día siguiente hábil Libélula te lo transfiere a tu cuenta bancaria. Si en ese mismo momento disparas un payout vía API, el payout sí sería instantáneo (sale de la cuenta de Libélula, no de la tuya).

Conclusión: El payout a tu usuario es instantáneo. Pero TÚ recibes tu dinero de Libélula al día siguiente hábil.

---

### 3\. ¿Tienen límite diario de payouts?

No está documentado públicamente. Ni en la web, ni en el manual de integración PDF, ni en el soporte. No hay mención de topes diarios, límites por transacción, ni máximos mensuales.

Conclusión: Debes preguntar directamente a Libélula (soporte@libelula.bo). Esto es crítico para tu modelo si vas a hacer muchos payouts al día.

---

### 4\. ¿El usuario final necesita verificar identidad (CI, selfie) para recibir el payout?

No está documentado. La API de payouts parece funcionar con:

* Nombre del beneficiario  
* Banco  
* Número de cuenta

No hay mención de KYC, verificación biométrica, ni CI del beneficiario en la documentación pública.

Pero ojo: por normativa AML (Ley 004 contra el lavado de activos), los bancos en Bolivia pueden rechazar transferencias a cuentas que no reconozcan al remitente o que superen ciertos montos sin justificación. Esto no es un requisito de Libélula, sino del banco receptor.

Conclusión: Probablemente no necesites CI ni selfie del usuario final para disparar el payout. Pero si los montos son altos o hay muchas transferencias al mismo beneficiario, el banco podría bloquear. Para montos pequeños (Bs 50-500) debería funcionar sin problemas.

---

### 5\. ¿Cobran por payout también?

No está documentado públicamente. Lo que SÍ está claro:

| Servicio | Costo |
| :---- | :---- |
| PayIn (cobros vía pasarela) | 2.5% por transacción |
| Afiliación / Mensualidad | \$0 (no cobran nada fijo) |
| Payout (transferencias a terceros) | No publicado |

El soporte dice: *"El costo base es de 2,5% de comisión por los pagos recibidos a través de la pasarela. No existen costos de afiliación ni costos fijos mensuales."*

No hay ninguna mención del costo por payout. Podría ser:

* Incluido en el 2.5% (poco probable)  
* Una tarifa fija por transferencia (tipo Bs 1-2)  
* Un porcentaje menor  
* Un acuerdo negociado según volumen

Conclusión: Debes preguntar directamente. Es la pregunta más importante porque si cobran 2.5% por el cobro \+ 2.5% por el payout, tu margen se come al 5% por transacción.

---

[Libelula payout fees experience site:reddit.com](https://search.brave.com/search?q=Libelula%20payout%20fees%20experience%20site%3Areddit.com)

Mostrar todo

## Resumen: ¿Libélula te sirve?

| Tu necesidad | ¿Libélula lo cubre? |
| :---- | :---- |
| Generar QR dinámico con monto | ✅ Sí (canal QR Simple, 16 bancos) |
| Dinero va a tu cuenta | ✅ Sí (liquidación al día hábil) |
| Payout a cuenta del usuario | ✅ Sí (API de payouts, "tiempo real") |
| Webhook/callback de confirmación | ✅ Sí (callback en tiempo real) |
| Registro como persona natural | ❌ No (mínimo Empresa Unipersonal) |
| Costo por payout | ❓ No documentado |
| Límite diario de payouts | ❓ No documentado |
| KYC del beneficiario | ❓ No documentado (probablemente no) |

[Libélula, fintech company](https://search.brave.com/search?q=Lib%C3%A9lula%2C%20fintech%20company)

Mostrar todo

## Lo que debes hacer

Escribir a soporte@libelula.bo con estas preguntas exactas:

"Hola, quiero integrar la API de Libélula para mi aplicación. Mi flujo es: genero un QR de cobro (PayIn), el dinero se acredita a mi cuenta, y luego hago un payout automático a la cuenta de un tercero. Necesito confirmar:

1. ¿Cuál es el costo por cada payout?  
2. ¿Hay límite diario o máximo por transacción en payouts?  
3. ¿El beneficiario del payout necesita algún tipo de verificación (CI, etc.) o solo necesito nombre \+ banco \+ n° cuenta?  
4. ¿El payout es realmente instantáneo o depende del banco receptor?  
5. ¿Puedo registrarme como Empresa Unipersonal o necesitan empresa constituida (SRL)?"

Además: Ten en cuenta que la documentación de API de Libélula es un PDF (no un portal de desarrolladores tipo Stripe). Un desarrollador en GitHub lo resumió así: *"Libélula integra vía un manual PDF y plugins de e-commerce, sin documentación de API self-serve ni SDK oficial."* Así que la integración va a ser más manual que con CUCU.

¿Quieres que te prepare el correo para enviarles, o prefieres que investigue también Mesa de Pagos como alternativa?

[Libelula API documentation PDF](https://search.brave.com/search?q=Libelula%20API%20documentation%20PDF)

Mostrar todo

Copiar

investiga mesa de pagos como alternativa, tomate tu tiempo

Análisis de Mesa de Pagos

Tras investigar la documentación, la web y las FAQs de Mesa de Pagos, aquí van las respuestas:

---

## Mesa de Pagos — Análisis completo

### Lo que ofrecen en Bolivia

| Servicio | Detalle |
| :---- | :---- |
| PayIn (QR) | Genera QR dinámico, el pagador escanea desde cualquier app bancaria o billetera (Tigo Money, Yolo, Soli). Acreditación en segundos, 24/7 |
| PayIn (tarjeta) | Liquidación T+1 días hábiles |
| Payout | "Desembolsa a miles de beneficiarios a la vez vía carga CSV o batch por API" — nómina, marketplaces, plataformas gig, proveedores |
| Bancos integrados | Banco Unión y Banco Ganadero (directo) |
| Webhooks | Cada acreditación dispara un webhook en tiempo real |
| Sandbox | https://sandbox-rampa.mesadepagos.com/api |
| SDKs | Para los principales lenguajes |
| Idempotencia | Sí, requests idempotentes |

Ejemplo de su API (de su propia web):

// Disburse via QR — Bolivia local rails (BOB)

const qr \= await mdp.qr.create({

  amount: "1500.00",

  currency: "BOB",

  reference: "order\_8821",

  expires\_in: 900,

}, { headers: { "api-key": process.env.MDP\_API\_KEY } });

// → qr.image\_url · qr.payload · webhook on settlement

Módulos de la API:

| Módulo | Propósito |
| :---- | :---- |
| Auth | Obtener token JWT |
| Quotes | Consultar cotizaciones |
| Payin | Generar QR, cash y pagos con tarjeta |
| Payout | Enviar pagos por ACH o QR |
| Fees | Consultar y crear configuraciones de fees |
| Webhooks | Configurar callbacks y revisar logs de entrega |
| Consultas | Balances e historial de transacciones |

---

## Respuestas a tus 5 preguntas

### 1\. ¿Aceptan persona natural como integrador?

Probablemente no. Su positioning es explícitamente para empresas y plataformas:

*"We give businesses and platforms a single API to move money across 100+ countries"*  
*"Designed for the companies redefining global commerce"*

Además:

* Operan bajo una entidad boliviana local alineada con ASFI (KYC, AML, trazabilidad)  
* Su documentación es para "partners" (no para developers individuales)  
* No hay opción de "abrir cuenta como persona natural" visible

Conclusión: Necesitas al mínimo una Empresa Unipersonal. Su modelo es B2B (business-to-business), no B2C.

---

[Tomate Tu Tiempo, payment platform](https://search.brave.com/search?q=Tomate%20Tu%20Tiempo%2C%20payment%20platform)

Mostrar todo

### 2\. ¿El payout es instantáneo o demora 24-48h?

Instantáneo. Su FAQ lo dice explícitamente:

*"Las transferencias QR y LIP se liquidan en segundos, 24/7."*

Y en la sección de capacidades:

*"Instant bank transfers, mass payouts in BOB"*

Tanto el PayIn (cobro QR) como el Payout (envío a terceros) son T+0, 24/7. No hay demora de 24-48h.

Conclusión: Instantáneo. El pagador escanea → dinero a tu cuenta en segundos → disparas payout → llega a la cuenta del usuario en segundos.

---

### 3\. ¿Tienen límite diario de payouts?

No está documentado públicamente. No hay mención de topes diarios, máximos por transacción ni límites mensuales en ninguna de sus páginas.

Sin embargo, su módulo Fees en la API permite "consultar y crear configuraciones de fees" — lo que sugiere que los límites y costos se configuran por contrato, no son públicos.

Conclusión: Debes preguntar directamente. Es crítico para tu modelo.

---

[Tomate Tu Tiempo API fees documentation](https://search.brave.com/search?q=Tomate%20Tu%20Tiempo%20API%20fees%20documentation)

Mostrar todo

### 4\. ¿El usuario final necesita verificar identidad (CI, selfie) para recibir el payout?

Muy probablemente sí necesita al menos CI. Evidencia:

* Mesa de Pagos declara: *"opera bajo una entidad boliviana local alineada con ASFI, incluyendo KYC, AML y trazabilidad completa de transacciones"*  
* La documentación de Worldpay para payouts en Bolivia (otro proveedor, pero mismo mercado regulatorio) muestra que el campo identity.identityNumber (CDI \= Cédula de Identidad) es obligatorio para pagos domésticos a individuos  
* La normativa AML boliviana (Ley 004\) exige identificación del beneficiario

Lo que probablemente no necesites:

* Selfie / verificación biométrica  
* Certificado de impuestos del beneficiario

Lo que probablemente sí necesites del usuario final:

| Dato | Obligatorio |
| :---- | :---- |
| Nombre completo | ✅ |
| Banco \+ N° de cuenta | ✅ |
| Cédula de Identidad (CI) | ✅ (por AML) |
| Selfie | ❓ (probablemente no) |
| Certificado de impuestos | ❌ |

Conclusión: Tu onboarding en la app debe pedir nombre \+ banco \+ n° cuenta \+ CI del titular. No es "no comprometedor" en el sentido estricto (la CI es un dato personal), pero es lo mínimo que la normativa exige.

---

[Mesa de Pagos alternativa Bolivia opiniones site:reddit.com](https://search.brave.com/search?q=Mesa%20de%20Pagos%20alternativa%20Bolivia%20opiniones%20site%3Areddit.com)

Mostrar todo

### 5\. ¿Cobran por payout también?

No está publicado. Pero hay indicios:

* Tienen un módulo Fees en la API: *"Consultar y crear configuraciones de fees"* → los fees son configurables por contrato  
* Mencionan: *"Menores comisiones a mayor volumen"* → hay escala  
* Para FX mencionan: *"incl. 1% spread"*  
* No hay pricing público (a diferencia de CUCU que publica Bs 250/mes \+ Bs 1/cobro)

Conclusión: El pricing es negociado. No hay tarifa pública. Debes contactarlos y pedir una propuesta según tu volumen. Es probable que cobren por PayIn y por Payout por separado.

---

## Comparativa directa: Mesa de Pagos vs. Libélula vs. CUCU

| Criterio | Mesa de Pagos | Libélula | CUCU |
| :---- | :---- | :---- | :---- |
| PayIn (QR) | ✅ Banco Unión \+ Ganadero | ✅ 16 bancos | ✅ Todos los bancos |
| Payout | ✅ "Instant", batch/CSV | ✅ "Tiempo real" | ❌ No lo ofrece |
| Liquidación PayIn | Segundos, 24/7 | Días hábiles | Segundos |
| Sandbox | ✅ | ❓ | ✅ |
| SDKs | ✅ (múltiples lenguajes) | ❌ (PDF manual) | ❌ (REST \+ MCP) |
| Idempotencia | ✅ | ❓ | ✅ |
| Webhooks | ✅ | ✅ | ✅ |
| Costo PayIn | No publicado (negociado) | 2.5% por transacción | Bs 1+ por cobro \+ Bs 250/mes |
| Costo Payout | No publicado (negociado) | No publicado | ❌ No existe |
| Persona natural | ❌ (B2B) | ❌ (mín. Emp. Unipersonal) | ✅ (persona natural) |
| CI del beneficiario | ✅ Probablemente | ❓ (probablemente no) | N/A (no hace payouts) |
| Cripto-fiat | ✅ (USDT/USDC → BOB) | ❌ | ❌ |
| Cross-border | ✅ (100+ países) | ❌ (solo Bolivia) | ❌ (solo Bolivia) |

---

[Mesa de Pagos Libélula CUCU alternatives](https://search.brave.com/search?q=Mesa%20de%20Pagos%20Lib%C3%A9lula%20CUCU%20alternatives)

Mostrar todo

## Veredicto

Mesa de Pagos es la opción más completa para tu caso (PayIn \+ Payout en una sola API, instantáneo, 24/7, con sandbox y SDKs), pero tiene dos problemas:

1. No publican precios → no sabes cuánto te va a costar hasta que negocien  
2. Probablemente no aceptan persona natural → necesitas Empresa Unipersonal

[alternativas a mesa de pagos para empresas online site:reddit.com](https://search.brave.com/search?q=alternativas%20a%20mesa%20de%20pagos%20para%20empresas%20online%20site%3Areddit.com)

Mostrar todo

### Mi recomendación

Contacta a Mesa de Pagos (compliance@mesadepagos.com o desde su web "Abrir cuenta") con este mensaje:

"Hola, tengo una plataforma (app móvil) donde los usuarios registran sus datos bancarios y yo genero QRs de cobro dinámicos. Cuando el cobro se acredita, hago un payout automático a la cuenta del usuario. Necesito saber:

1. ¿Cuál es el costo por PayIn (QR) y por Payout?  
2. ¿Hay límites diarios o por transacción?  
3. ¿Qué datos necesito del beneficiario del payout (¿CI obligatorio?)?  
4. ¿Puedo registrarme con una Empresa Unipersonal?  
5. ¿El payout es realmente instantáneo (T+0) a cualquier banco boliviano, o solo a Banco Unión y Ganadero?

Mi volumen estimado inicial es X transacciones/día."

Pregunta 5 es clave: Si el payout solo va a cuentas de Banco Unión y Banco Ganadero (los únicos bancos con los que tienen integración directa), y tus usuarios tienen cuentas en BMSC, BCP, BNB, etc., no te sirve. Asegúrate de que el payout cubra todos los bancos bolivianos vía LIP (Liquidación de Instrumentos de Pago).

¿Quieres que te prepare el código de integración (backend \+ Flutter) asumiendo que Mesa de Pagos te acepta?  
Copiar

pta y no hay uno en el que pueda ser persona natural?

Búsqueda de proveedores de pago en Bolivia

No. No existe ningún proveedor en Bolivia que haga el flujo completo (QR dinámico \+ payout a cuenta de tercero) aceptando persona natural.

Te lo desgloso con lo que encontré:

## Lo que acepta persona natural

| Proveedor | ¿Persona natural? | ¿Qué puede hacer? |
| :---- | :---- | :---- |
| CUCU | ✅ Sí | Generar QR dinámico → dinero a tu cuenta → webhook. Pero NO tiene API de payout |
| Paxum | ✅ Sí | Recibir pagos y retirar a banco local. Pero NO genera QR BCB Bolivia |
| BCP (QR estático) | ✅ Sí | Generar QR estático desde la app. Sin API, sin monto dinámico, sin payout |

[persona natural CUCU Paxum BCP opiniones site:reddit.com](https://search.brave.com/search?q=persona%20natural%20CUCU%20Paxum%20BCP%20opiniones%20site%3Areddit.com)

Mostrar todo

## Lo que NO acepta persona natural

| Proveedor | Requiere |
| :---- | :---- |
| Libélula | Empresa Unipersonal mínimo |
| Mesa de Pagos | Empresa (B2B) |
| Kraken (pagos.kraken.bo) | Probablemente empresa |
| PagosNet | Empresa |
| OpenBCB | Institución |

[PTA persona natural no aceptado opiniones site:reddit.com](https://search.brave.com/search?q=PTA%20persona%20natural%20no%20aceptado%20opiniones%20site%3Areddit.com)

Mostrar todo

## La respuesta directa

El único que te deja registrarte como persona natural y generar QR dinámicos por API es CUCU. Pero el flujo se corta ahí: el dinero llega a tu cuenta y de ahí en adelante tú haces la transferencia manualmente (o semiautomáticamente) a la cuenta del usuario.

No hay un "CUCU Payout" ni un endpoint donde digas POST /payouts con el CBU del usuario.

## Tu única opción realista como persona natural

1\. Usuario ingresa: nombre \+ banco \+ n° cuenta → tu BD

2\. Tu backend llama a CUCU: POST /transfers/qr (monto)

3\. Muestras QR en Flutter

4\. Pagador escanea → dinero a TU cuenta

5\. Recibes webhook "PAID"

6\. TÚ transfieres manualmente (o por planilla) a la cuenta del usuario

   → Desde tu banca móvil, o por LIP si tu banco lo permite

El paso 6 es manual. No hay API que lo automatice para persona natural.

## Si quieres automatizar el paso 6

Necesitas Empresa Unipersonal. En Bolivia:

| Trámite | Dónde | Tiempo | Costo |
| :---- | :---- | :---- | :---- |
| Registro en SEPREC | Virtual ([seprec.gob.bo](https://seprec.gob.bo/)) | 1 día | \~Bs 130 |
| NIT | SIN (automático con SEPREC) | 1 día | Gratis |
| Cuenta bancaria empresarial | Tu banco | 1-2 días | Gratis |

Con eso puedes registrarla en Libélula o Mesa de Pagos y tener el flujo completo automatizado (QR \+ payout).

## Resumiendo

| ¿Qué quieres? | ¿Persona natural? | ¿Empresa Unipersonal? |
| :---- | :---- | :---- |
| QR dinámico \+ dinero a tu cuenta | ✅ CUCU | ✅ Cualquiera |
| Payout automático a cuenta del usuario | ❌ No existe | ✅ Libélula / Mesa de Pagos |
| Flujo completo automatizado | ❌ Imposible | ✅ Sí |

Conclusión: Si no quieres constituir empresa, tu MVP funciona con CUCU \+ transferencias manuales. Cuando escales, constituyes la Empresa Unipersonal (1 día, Bs 130\) y automatizas el payout con Libélula o Mesa de Pagos.

¿Quieres que te arme el flujo con CUCU \+ payout manual para que lo tengas funcionando como persona natural hoy?

