import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(MyApp());
}

class Ticker {
  List<dynamic> tickerData;
  Ticker(this.tickerData);

  int get channelID => tickerData[0];

  // Ask
  double get askPrice => double.parse(tickerData[1]['a'][0]);
  int get askWholeLotVolume => int.parse(tickerData[1]['a'][1]);
  double get askLotVolume => double.parse(tickerData[1]['a'][2]);

  // Bid
  double get bidPrice => double.parse(tickerData[1]['b'][0]);
  int get bidWholeLotVolume => int.parse(tickerData[1]['b'][1]);
  double get bidLotVolume => double.parse(tickerData[1]['b'][2]);

  // Close
  double get closePrice => double.parse(tickerData[1]['c'][0]);
  double get closeLotVolume => double.parse(tickerData[1]['c'][1]);

  // Volume
  double get volumeToday => double.parse(tickerData[1]['v'][0]);
  double get volumeLast24Hours => double.parse(tickerData[1]['v'][1]);

  // Volume weighted average price
  double get volumeWeightedAveragePriceToday =>
      double.parse(tickerData[1]['p'][0]);
  double get volumeWeightedAveragePriceLast24Hours =>
      double.parse(tickerData[1]['p'][1]);

  // Number of Trades
  int get tradesToday => int.parse(tickerData[1]['t'][0]);
  int get tradesLast24Hours => int.parse(tickerData[1]['t'][1]);

  // Low
  double get lowToday => double.parse(tickerData[1]['l'][0]);
  double get lowLast24Hours => double.parse(tickerData[1]['l'][1]);

  // High
  double get highToday => double.parse(tickerData[1]['h'][0]);
  double get highLast24Hours => double.parse(tickerData[1]['h'][1]);

  // Open
  double get openPriceToday => double.parse(tickerData[1]['o'][0]);
  double get openPriceLast24Hours => double.parse(tickerData[1]['o'][1]);

  double get change => 0;

  String get ticker => tickerData[4];
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primaryColor: Color.fromRGBO(236, 81, 27, 1),
      ),
      home: Monero(
          title: 'XMR/USD',
          channel: IOWebSocketChannel.connect('wss://beta-ws.kraken.com')),
    );
  }
}

class Monero extends StatefulWidget {
  Monero({Key key, this.title, this.channel}) : super(key: key);

  final String title;
  final WebSocketChannel channel;

  @override
  _MoneroState createState() => _MoneroState();
}

class _MoneroState extends State<Monero> {
  // String _addr = '';
  String _addr;
  double _coins;
  Ticker _ticker;
  bool _data = false;

  void initState() {
    super.initState();
    widget.channel.sink.add(
        '{"event":"subscribe","subscription":{"name": "ticker"},"pair":["XMR/USD"]}');
    widget.channel.stream.listen((message) {
      if (message == '{"event":"heartbeat"}') {
        dataOn(50);
      } else {
        final decoded = jsonDecode(message);
        parseMessage(decoded);
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      double coins = prefs.getDouble('coins');
      String addr = prefs.getString('addr');
      setState(() {
        _coins = coins;
        _addr = addr;
      });
    });
  }

  void dataOn(int ms) {
    setState(() {
      _data = true;
    });
    Timer(Duration(milliseconds: ms), dataOff);
  }

  void dataOff() {
    setState(() {
      _data = false;
    });
  }

  void parseMessage(data) {
    if (data is List<dynamic> && data[2] == 'ticker') {
      parseTicker(data);
    }
  }

  void parseTicker(data) {
    setState(() {
      _ticker = Ticker(data);
    });
    dataOn(750);
  }

  @override
  Widget build(BuildContext context) {
    if (_ticker != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _data ? Text('🟢') : Text('⚪️'),
              GestureDetector(
                onDoubleTap: () {
                  String message;
                  if (_coins == null) {
                    message = 'Long press for settings.';
                  } else {
                    message =
                        NumberFormat.currency(locale: 'en-US', symbol: 'USD ')
                            .format(_ticker.closePrice * _coins);
                  }
                  final snackBar = SnackBar(content: Text(message));
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
                onLongPress: () {
                  Navigator.of(context).push(_createRoute());
                },
                child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Image(
                        image: AssetImage(
                            'images/monero-symbol-on-white-800.png'))),
              ),
              Text(
                "Ask ${_ticker.askPrice} / Bid ${_ticker.bidPrice}\n",
                style: Theme.of(context).textTheme.headline5,
              ),
              Text(
                "24h Low ${_ticker.lowToday} / High ${_ticker.highToday}",
                style: Theme.of(context).textTheme.headline6,
              ),
              Text(
                "1w Low ${_ticker.lowLast24Hours} / High ${_ticker.highLast24Hours}",
                style: Theme.of(context).textTheme.headline6,
              ),
              Text(
                "\n${NumberFormat.currency(locale: 'en-US', symbol: 'XMR ').format(_coins)}",
                style: Theme.of(context).textTheme.headline5,
              ),
              Text(
                "\n${NumberFormat.currency(locale: 'en-US', symbol: 'USD ').format(_ticker.closePrice)}",
                style: Theme.of(context).textTheme.headline4,
              ),
              _coins != null
                  ? Text(
                      NumberFormat.currency(locale: 'en-US', symbol: 'USD ')
                          .format(_ticker.closePrice * _coins),
                      style: Theme.of(context).textTheme.headline6,
                    )
                  : Container(),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _addr != null
                    ? QrImage(
                        data: _addr,
                        version: QrVersions.auto,
                        size: 130.0,
                        foregroundColor: Color.fromRGBO(236, 81, 27, 1),
                      )
                    : Container(),
              ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
          body: Center(
        child: CircularProgressIndicator(),
      ));
    }
  }
}

Route _createRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => SettingsPage(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var begin = Offset(0.0, 1.0);
      var end = Offset.zero;
      var curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}

class SettingsPage extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SettingsForm(),
      ),
    );
  }
}

class SettingsForm extends StatefulWidget {
  @override
  SettingsFormState createState() => SettingsFormState();
}

class SettingsFormState extends State<SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  final _coinsController = TextEditingController();
  final _addrController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      double coins = prefs.getDouble('coins');
      _coinsController.text = coins?.toString() ?? '';
      String addr = prefs.getString('addr');
      _addrController.text = addr;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Form(
            key: _formKey,
            child: Column(children: [
              new TextFormField(
                controller: _coinsController,
                decoration: new InputDecoration(labelText: 'How many coins?'),
                keyboardType: TextInputType.number,
                validator: numberValidator,
              ),
              new TextFormField(
                controller: _addrController,
                decoration: new InputDecoration(labelText: 'Got an address?'),
                validator: addrValidator,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                    child: Text('SAVE'),
                    onPressed: () {
                      if (_formKey.currentState.validate()) {
                        SharedPreferences.getInstance().then((prefs) {
                          if (_coinsController.text.isEmpty){
                            prefs.remove('coins');
                          } else {
                            prefs.setDouble(
                                  'coins', double.parse(_coinsController.text));
                          }
                          prefs.setString('addr', _addrController.text);
                        });
                      }
                    }),
              )
            ])),
      ),
    );
  }
}

String numberValidator(String value) {
  if (value == null || value == '') {
    return null;
  }
  final n = num.tryParse(value);
  if (n == null) {
    return '"$value" is not a valid number';
  }
  return null;
}

String addrValidator(String value) {
  if (value == null || value == '') {
    return null;
  }
  // final n = num.tryParse(value);
  // if (n == null) {
  //   return '"$value" is not a valid number';
  // }
  return null;
}
