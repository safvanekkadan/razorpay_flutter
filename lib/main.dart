// import 'package:flutter/material.dart';
// import 'package:pay/pay.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//     @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//       colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final  _paymentItems = [
//   const PaymentItem(
//     label: 'Total',
//     amount: '99.99',
//     status: PaymentItemStatus.final_price,
//   )
// ];
//   @override
//   Widget build(BuildContext context) {
//       return Scaffold(
//       appBar: AppBar(
//       backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//        title: Text(widget.title),
//       ),
//       body: Center(
//        child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//           children:[

// ApplePayButton(
//   paymentConfiguration: PaymentConfiguration.fromJsonString(
//       defaultApplePayConfigString),
//   paymentItems: _paymentItems,
//   style: ApplePayButtonStyle.black,
//   type: ApplePayButtonType.buy,
//   margin: const EdgeInsets.only(top: 15.0),
//   onPaymentResult: onApplePayResult,
//   loadingIndicator: const Center(
//     child: CircularProgressIndicator(),
//   ),
// ),

// GooglePayButton(
//   paymentConfiguration: PaymentConfiguration.fromJsonString(
//       defaultGooglePayConfigString),
//   paymentItems: _paymentItems,
//   type: GooglePayButtonType.pay,
//   margin: const EdgeInsets.only(top: 15.0),
//   onPaymentResult: onGooglePayResult,
//   loadingIndicator: const Center(
//     child: CircularProgressIndicator(),
//   ),
// ),

//           ],
//         ),
//       ),
//        );
//   }
//   void onApplePayResult(paymentResult) {
//   // Send the resulting Apple Pay token to your server / PSP
// }

// void onGooglePayResult(paymentResult) {
//   // Send the resulting Google Pay token to your server / PSP
// }
// }
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'razor_credentials.dart' as razorCredentials;

void main() {
  HttpOverrides.global = MyHttpOverrides();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Razorpay Flutter',
      theme: ThemeData(
        fontFamily: 'Montserrat',
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _razorpay = Razorpay();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    });
    super.initState();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Do something when payment succeeds
    print(response);
    verifySignature(
      signature: response.signature,
      paymentId: response.paymentId,
      orderId: response.orderId,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print(response);
    // Do something when payment fails
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? ''),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print(response);
    // Do something when an external wallet is selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.walletName ?? ''),
      ),
    );
  }

// create order
  void createOrder() async {
    String username = razorCredentials.keyId;
    String password = razorCredentials.keySecret;
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    Map<String, dynamic> body = {
      "amount": 100,
      "currency": "INR",
      "receipt": "rcptid_11"
    };
    var res = await http.post(
      Uri.https(
          "api.razorpay.com", "v1/orders"), //https://api.razorpay.com/v1/orders
      headers: <String, String>{
        "Content-Type": "application/json",
        'authorization': basicAuth,
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      openGateway(jsonDecode(res.body)['id']);
    }
    print(res.body);
  }

  openGateway(String orderId) {
    var options = {
      'key': razorCredentials.keyId,
      'amount': 100, //in the smallest currency sub-unit.
      'name': 'Acme Corp.',
      'order_id': orderId, // Generate order_id using Orders API
      'description': 'Fine T-Shirt',
      'timeout': 60 * 5, // in seconds // 5 minutes
      'prefill': {
        'contact': '9123456789',
        'email': 'ary@example.com',
      }
    };
    _razorpay.open(options);
  }

  verifySignature({
    String? signature,
    String? paymentId,
    String? orderId,
  }) async {
    Map<String, dynamic> body = {
      'razorpay_signature': signature,
      'razorpay_payment_id': paymentId,
      'razorpay_order_id': orderId,
    };

    var parts = [];
    body.forEach((key, value) {
      parts.add('${Uri.encodeQueryComponent(key)}='
          '${Uri.encodeQueryComponent(value)}');
    });
    var formData = parts.join('&');
    var res = await http.post(
      Uri.https(
        "10.0.2.2", // my ip address , localhost
        "razorpay_signature_verify.php",
      ),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded", // urlencoded
      },
      body: formData,
    );

    print(res.body);
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.body),
        ),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear(); // Removes all listeners

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Razorpay Flutter"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () {
                createOrder();
              },
              child: const Text(
                "Pay Rs.100",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 36.0,
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
