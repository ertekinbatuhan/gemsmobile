import 'dart:async';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';

import 'widgets/action_button.dart';

class CallScreenWidget extends StatefulWidget {
  final SIPUAHelper? _helper;
  final Call? _call;


  CallScreenWidget(this._helper, this._call, {Key? key}) : super(key: key);
  @override
  _MyCallScreenWidget createState() => _MyCallScreenWidget();
}

class _MyCallScreenWidget extends State<CallScreenWidget>
    implements SipUaHelperListener {
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer();
  double? _localVideoHeight;
  double? _localVideoWidth;
  EdgeInsetsGeometry? _localVideoMargin;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool isButtonPressed = false ;
  late SharedPreferences _preferences;

 String? getSharedAuthUser ;


  void loadSharedData()  async {
    _preferences =  await  SharedPreferences.getInstance()  ;
     getSharedAuthUser = _preferences.getString('auth_user') ;
    if(int.parse( remoteIdentity!) >= 9000 || int.parse(getSharedAuthUser!) >= 9000) {
      _pttClose() ;


    }
  }

  bool _showNumPad = false;
  String _timeLabel = '00:00';
  late Timer _timer;
  bool _audioMuted = false;
  bool _pttMuted = false ;
  bool _videoMuted = false;
  bool _speakerOn = false;
  bool _hold = false;
  String? _holdOriginator;
  CallStateEnum _state = CallStateEnum.NONE;
  SIPUAHelper? get helper => widget._helper;


  bool get voiceOnly =>
      (_localStream == null || _localStream!.getVideoTracks().isEmpty) &&
      (_remoteStream == null || _remoteStream!.getVideoTracks().isEmpty);

  String? get remoteIdentity => call!.remote_identity;


  bool isButtonColor = false;
  Color buttonColor = Color(0xFFe4002b); // Başlangıç rengi
  String get direction => call!.direction;
  Call? get call => widget._call;

  @override
  initState() {
    super.initState();
    _initRenderers();
    helper!.addSipUaHelperListener(this);
    _startTimer();
    loadSharedData() ;

  }

  @override
  deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _disposeRenderers();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      Duration duration = Duration(seconds: timer.tick);
      if (mounted) {
        setState(() {
          _timeLabel = [duration.inMinutes, duration.inSeconds]
              .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
              .join(':');
        });
      } else {
        _timer.cancel();
      }
    });
  }

  void _initRenderers() async {
    if (_localRenderer != null) {
      await _localRenderer!.initialize();
    }
    if (_remoteRenderer != null) {
      await _remoteRenderer!.initialize();
    }
  }

  void _disposeRenderers() {
    if (_localRenderer != null) {
      _localRenderer!.dispose();
      _localRenderer = null;
    }
    if (_remoteRenderer != null) {
      _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    if (callState.state == CallStateEnum.HOLD ||
        callState.state == CallStateEnum.UNHOLD) {
      _hold = callState.state == CallStateEnum.HOLD;
      _holdOriginator = callState.originator;
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.MUTED) {
      if (callState.audio!) _audioMuted = true;
      if (callState.video!) _videoMuted = true;
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.UNMUTED) {
      if (callState.audio!) _audioMuted = false;
      if (callState.video!) _videoMuted = false;
      setState(() {});
      return;
    }

    if (callState.state != CallStateEnum.STREAM) {
      _state = callState.state;
    }

    switch (callState.state) {
      case CallStateEnum.STREAM:
        _handelStreams(callState);
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _backToDialPad();
        break;
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.NONE:
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.REFER:
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void registrationStateChanged(RegistrationState state) {}

  void _cleanUp() {
    if (_localStream == null) return;
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream!.dispose();
    _localStream = null;
  }

  void _backToDialPad() {
    _timer.cancel();
    Timer(Duration(seconds: 2), () {
      Navigator.of(context).pop();
    });
    _cleanUp();
  }

  void _handelStreams(CallState event) async {
    MediaStream? stream = event.stream;
    if (event.originator == 'local') {
      if (_localRenderer != null) {
        _localRenderer!.srcObject = stream;
      }
      if (!kIsWeb && !WebRTC.platformIsDesktop) {
        event.stream?.getAudioTracks().first.enableSpeakerphone(false);
      }
      _localStream = stream;
    }
    if (event.originator == 'remote') {
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      _remoteStream = stream;
    }

    setState(() {
      _resizeLocalVideo();
    });
  }

  void _resizeLocalVideo() {
    _localVideoMargin = _remoteStream != null
        ? EdgeInsets.only(top: 15, right: 15)
        : EdgeInsets.all(0);
    _localVideoWidth = _remoteStream != null
        ? MediaQuery.of(context).size.width / 4
        : MediaQuery.of(context).size.width;
    _localVideoHeight = _remoteStream != null
        ? MediaQuery.of(context).size.height / 4
        : MediaQuery.of(context).size.height;
  }

  void _handleHangup() {
    call!.hangup({'status_code': 603});
    _timer.cancel();
  }

  void _handleAccept() async {
    bool remoteHasVideo = call!.remote_has_video;
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': remoteHasVideo
    };
    MediaStream mediaStream;

    if (kIsWeb && remoteHasVideo) {
      mediaStream =
          await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      mediaConstraints['video'] = false;
      MediaStream userStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      mediaStream.addTrack(userStream.getAudioTracks()[0], addToNative: true);
    } else {
      mediaConstraints['video'] = remoteHasVideo;
      mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    }

    call!.answer(helper!.buildCallOptions(!remoteHasVideo),
        mediaStream: mediaStream);
  }

  void _switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  void _muteAudio() {
    if (_audioMuted) {
      call!.unmute(true, false);
    } else {
      call!.mute(true, false);
    }
  }

  void _muteVideo() {
    if (_videoMuted) {
      call!.unmute(false, true);
    } else {
      call!.mute(false, true);
    }
  }

  void _handleHold() {
    if (_hold) {
      call!.unhold();
    } else {
      call!.hold();
    }
  }

  late String _transferTarget;
  void _handleTransfer() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter target to transfer.'),
          content: TextField(
            onChanged: (String text) {
              setState(() {
                _transferTarget = text;
              });
            },
            decoration: InputDecoration(
              hintText: 'URI or Username',
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                call!.refer(_transferTarget);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleDtmf(String tone) {
    print('Dtmf tone => $tone');
    call!.sendDTMF(tone);
  }

  void _pttOpen() {

    isButtonColor = true ;
    buttonColor = Colors.green ;
    //   _muteAudio();
    call!.unmute(true, false);
  }

  void _pttClose() {

    isButtonColor = false ;
    buttonColor = Color(0xFFe4002b) ;
    call!.mute(true,false);

  }

  void _handleKeyPad() {
    setState(() {
      _showNumPad = !_showNumPad;
    });
  }

  void _toggleSpeaker() {
    if (_localStream != null) {
      _speakerOn = !_speakerOn;
      if (!kIsWeb) {
        _localStream!.getAudioTracks()[0].enableSpeakerphone(_speakerOn);
      }
    }
  }

  List<Widget> _buildNumPad() {
    var labels = [
      [
        {'1': ''},
        {'2': 'abc'},
        {'3': 'def'}
      ],
      [
        {'4': 'ghi'},
        {'5': 'jkl'},
        {'6': 'mno'}
      ],
      [
        {'7': 'pqrs'},
        {'8': 'tuv'},
        {'9': 'wxyz'}
      ],
      [
        {'*': ''},
        {'0': '+'},
        {'#': ''}
      ],
    ];

    return labels
        .map((row) => Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map((label) => ActionButton(
                          title: label.keys.first,
                          subTitle: label.values.first,
                          onPressed: () => _handleDtmf(label.keys.first),
                          number: true,
                        ))
                    .toList())))
        .toList();
  }

  Widget _buildActionButtons() {
    var hangupBtn = ActionButton(
      title: "hangup",
      onPressed: () => _handleHangup(),
      icon: Icons.call_end,
      fillColor: Color(0xFFe4002b),
      //Color(0xE4002B),
    );

    var hangupBtnInactive = ActionButton(
      title: "hangup",
      onPressed: () {},
      icon: Icons.call_end,
      fillColor: Color(0xFFe4002b),
    );

    var basicActions = <Widget>[];
    var advanceActions = <Widget>[];


    switch (_state) {
      case CallStateEnum.NONE:
      case CallStateEnum.CONNECTING:
        if (direction == 'INCOMING') {
          basicActions.add(ActionButton(
            title: "Accept",
            fillColor: Colors.green,
            icon: Icons.phone,
            onPressed: () => _handleAccept(),
          ));
          basicActions.add(hangupBtn);
        } else {
          basicActions.add(hangupBtn);
        }
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        {


          if((int.parse(remoteIdentity!) >= 9000 ||
              int.parse(getSharedAuthUser!) >= 9000)) {

            advanceActions.add(GestureDetector(
              onLongPress: () {
                if (int.parse(remoteIdentity!) >= 9000 ||
                    int.parse(getSharedAuthUser!) >= 9000) {
                  _pttOpen();
                }
              },
              onLongPressEnd: (_) {
                if (int.parse(remoteIdentity!) >= 9000 ||
                    int.parse(getSharedAuthUser!) >= 9000) {
                  _pttClose();
                }
              },
              child: Visibility(
                visible: true,
                child: ActionButton(
                    title: "ptt",
                    icon: Icons.mic_none,
                    checked: _pttMuted,

                    fillColor: int.parse(remoteIdentity!) >= 9000 ||
                        int.parse(getSharedAuthUser!) >= 9000
                        ? buttonColor
                        : Color(0xFF5a5acaf)
                ),
              ),
            ));
          }


            if (voiceOnly) {
              advanceActions.add(SizedBox(
                child: ActionButton(
                  title: "keypad",
                  icon: Icons.dialpad,
                  onPressed: () {
                    _handleKeyPad();
                  },
                  fillColor: Color(0xFFe4002b),
                ),
              ));
            } else {
              advanceActions.add(ActionButton(
                title: "switch camera",
                icon: Icons.switch_video,
                onPressed: () => _switchCamera(),
                fillColor: Color(0xFFe4002b),
              ));
            }




          if(int.parse(remoteIdentity!) >= 9000 || int.parse(getSharedAuthUser!) >= 9000 ) {

            advanceActions.add(
              Visibility(
                visible: false,
                child: ActionButton(

                  title: _audioMuted ? 'unmute' : 'mute',
                  icon: _audioMuted ? Icons.mic_off : Icons.mic,
                  checked: _audioMuted,
                  onPressed: () => _muteAudio(),
                  fillColor: Color(0xFFe4002b),
                ),
              )
            );

          }
          else {

            advanceActions.add(
              Visibility(
                visible: true,
                child: ActionButton(
                  title: _audioMuted ? 'unmute' : 'mute',
                  icon: _audioMuted ? Icons.mic_off : Icons.mic,
                  checked: _audioMuted,
                  onPressed: () => _muteAudio(),
                  fillColor: Color(0xFFe4002b),

                ),
              )
            );

          }
        /*  advanceActions.add(Visibility(
            child: ActionButton(

              title: _audioMuted ? 'unmute' : 'mute',
              icon: _audioMuted ? Icons.mic_off : Icons.mic,
              checked: _audioMuted,
              onPressed: () => _muteAudio(),
              fillColor: Color(0xFFe4002b),

            ),
          ));

         */

          if (voiceOnly) {
            advanceActions.add(ActionButton(
              title: _speakerOn ? 'speaker off' : 'speaker on',
              icon: _speakerOn ? Icons.volume_off : Icons.volume_up,
              checked: _speakerOn,
              onPressed: () => _toggleSpeaker(),
              fillColor: Color(0xFFe4002b),
            ));
          } else {
            advanceActions.add(ActionButton(
              title: _videoMuted ? "camera on" : 'camera off',
              icon: _videoMuted ? Icons.videocam : Icons.videocam_off,
              checked: _videoMuted,
              fillColor: Color(0xFFe4002b),
              onPressed: () => _muteVideo(),
            ));
          }

          basicActions.add(ActionButton(
            title: _hold ? 'unhold' : 'hold',
            icon: _hold ? Icons.play_arrow : Icons.pause,
            checked: _hold,
            onPressed: () => _handleHold(),
            fillColor: Color(0xFFe4002b),
          ));

          basicActions.add(hangupBtn);

          if (_showNumPad) {
            basicActions.add(ActionButton(
              title: "back",
              icon: Icons.keyboard_arrow_down,
              onPressed: () => _handleKeyPad(),
              fillColor: Color(0xFFe4002b),
            ));
          } else {
            basicActions.add(ActionButton(
              title: "transfer",
              icon: Icons.phone_forwarded,
              onPressed: () => _handleTransfer(),
              fillColor: Color(0xFFe4002b),
            ));
          }

        }
        break;
      case CallStateEnum.FAILED:
      case CallStateEnum.ENDED:
        basicActions.add(hangupBtnInactive);
        break;
      case CallStateEnum.PROGRESS:
        basicActions.add(hangupBtn);
        break;
      default:
        print('Other state => $_state');
        break;
    }

    var actionWidgets = <Widget>[];

    if (_showNumPad) {
      actionWidgets.addAll(_buildNumPad());
    } else {
      if (advanceActions.isNotEmpty) {
        actionWidgets.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: advanceActions));
      }
    }

    actionWidgets.add(Padding(
        padding: const EdgeInsets.all(1),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly  ,
            children: basicActions)));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: actionWidgets);
  }

  Widget _buildContent() {
    var stackWidgets = <Widget>[];

    if (!voiceOnly && _remoteStream != null) {
      stackWidgets.add(Center(
        child: RTCVideoView(_remoteRenderer!),
      ));
    }

    if (!voiceOnly && _localStream != null) {
      stackWidgets.add(Container(
        child: AnimatedContainer(
          child: RTCVideoView(_localRenderer!),
          height: _localVideoHeight,
          width: _localVideoWidth,
          alignment: Alignment.topRight,
          duration: Duration(milliseconds: 300),
          margin: _localVideoMargin,
        ),
        alignment: Alignment.topRight,
      ));
    }

    stackWidgets.addAll([
      Positioned(
        top: voiceOnly ? 48 : 6,
        left: 0,
        right: 0,
        child: Center(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      (voiceOnly ? 'VOICE CALL' : 'VIDEO CALL') +
                          (_hold
                              ? ' PAUSED BY ${_holdOriginator!.toUpperCase()}'
                              : ''),
                      style: TextStyle(fontSize: 24, color: Colors.black54),
                    ))),
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '$remoteIdentity',
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ))),
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(_timeLabel,
                        style: TextStyle(fontSize: 14, color: Colors.black54))))
          ],
        )),
      ),
    ]);

    return Stack(
      children: stackWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('[$direction] ${EnumHelper.getName(_state)}')),
        body: Container(
          child: _buildContent(),

        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
            padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 24.0),
            child: Container(width: 320, child: _buildActionButtons())));
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }
}
