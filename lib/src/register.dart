import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gemsmobile/src/callscreen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';

class RegisterWidget extends StatefulWidget {
  final SIPUAHelper? _helper;
  RegisterWidget(this._helper, {Key? key}) : super(key: key);
  @override
  _MyRegisterWidget createState() => _MyRegisterWidget();
}

class _MyRegisterWidget extends State<RegisterWidget>
    implements SipUaHelperListener {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _wsUriController = TextEditingController();
  final TextEditingController _sipUriController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _authorizationUserController =
      TextEditingController();
  final Map<String, String> _wsExtraHeaders = {
    // 'Origin': ' https://tryit.jssip.net',
    // 'Host': 'tryit.jssip.net:10443'
  };
  late SharedPreferences _preferences;
  late RegistrationState _registerState;

  SIPUAHelper? get helper => widget._helper;

  String? ipAdress ;


  @override
  initState() {
    super.initState();
    _registerState = helper!.registerState;
    helper!.addSipUaHelperListener(this);
    _loadSettings();
  }

  @override
  deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _saveSettings();
  }

  void _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _wsUriController.text =      // "ws://192.168.22.5:5056"
          _preferences.getString('ws_uri') ?? '192.168.22.5';
      _sipUriController.text =
          _preferences.getString('sip_uri') ?? '';
      _displayNameController.text =
          _preferences.getString('display_name') ?? 'Leonardo GEMS Mobile';
      _passwordController.text = _preferences.getString('password') ?? '';
      _authorizationUserController.text =
          _preferences.getString('auth_user') ?? '';
    });
  }

  void _saveSettings() {
    _preferences.setString('ws_uri', _wsUriController.text);
    _preferences.setString('sip_uri', _sipUriController.text);
    _preferences.setString('display_name', _displayNameController.text);
    _preferences.setString('password', _passwordController.text);
    _preferences.setString('auth_user', _authorizationUserController.text);
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    setState(() {
      _registerState = state;
      if(EnumHelper.getName(_registerState.state) == "Registered"){
        Navigator.pop(context);

      }

    });
  }

  void _alert(BuildContext context, String alertFieldName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$alertFieldName is empty'),
          content: Text('Please enter $alertFieldName!'),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSave(BuildContext context) {
    if (_wsUriController.text == '') {
      _alert(context, "WebSocket URL");
    } else if (_sipUriController.text == '') {
      _alert(context, "SIP URI");
    }

    UaSettings settings = UaSettings();

    settings.webSocketUrl =  "ws://"  +  _wsUriController.text  ;   //  ":5066" ;
    settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
    settings.webSocketSettings.allowBadCertificate = true;
    //settings.webSocketSettings.userAgent = 'Dart/2.8 (dart:io) for OpenSIPS.';
    settings.uri =   _authorizationUserController.text  + "@"  + _wsUriController.text;
    settings.authorizationUser = _authorizationUserController.text;
    settings.password = _passwordController.text;
    settings.displayName = _displayNameController.text;
    settings.userAgent = 'Leonardo GEMS Client v1.0.0';
    settings.dtmfMode = DtmfMode.RFC2833;

    helper!.start(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("GEMS Account"),
          backgroundColor: Color(0xFFe4002b),
        ),
        body: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(48.0, 18.0, 48.0, 18.0),
                        child: Center(
                            child: Text(
                          'Register Status: ${EnumHelper.getName(_registerState.state)}',
                          style: const TextStyle(fontSize: 18, color: Colors.black54),
                        )),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(48.0, 18.0, 48.0, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('SIP SERVER IP:'),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _wsUriController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                /*
                SIP URI KISMI
                Column(
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('SIP URI:'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _sipUriController ,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,

                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                 */
                  Column(
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('User Name:'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _authorizationUserController  ,
                          keyboardType: TextInputType.text,
                          onChanged: (text) {
                           _displayNameController.text = text  ;
                          },
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(10.0),
                            border: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                            hintText: _authorizationUserController.text.isEmpty
                                ? '[Empty]'
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Password:'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _passwordController,
                          keyboardType: TextInputType.text,
                          obscureText: true,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(10.0),
                            border: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                            hintText: _passwordController.text.isEmpty
                                ? '[Empty]'
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Display Name:'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _displayNameController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                         // readOnly: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(0.0, 50.0, 0.0, 0.0),
                      child: Container(
                        height: 48.0,
                        width: 250.0,
                        child: MaterialButton(
                          color: Color(0xFFe4002b),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          textColor: Colors.white,
                          onPressed: () => _handleSave(context),
                          child: const Text(
                            'Register',
                            style:
                                TextStyle(fontSize: 16.0, color: Colors.white),
                          ),
                        ),
                      ))
                ])));
  }

  @override
  void callStateChanged(Call call, CallState state) {
    //NO OP
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }

}
