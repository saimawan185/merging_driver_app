import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioPlayerService {
  static late AudioPlayer _audioPlayer;

  static Future<void> initAudio() async {
    _audioPlayer = AudioPlayer(playerId: "playerId");
  }

  static Future<void> playSound(bool isPlay) async {
    try {
      if (isPlay) {
        if (_audioPlayer.state != PlayerState.playing) {
          if (Platform.isAndroid) {
            final path =
                await rootBundle.load("assets/audio/notification_sound.wav");
            await _audioPlayer.setSourceBytes(path.buffer.asUint8List());
            await _audioPlayer.setReleaseMode(ReleaseMode.loop);
            _audioPlayer.play(BytesSource(path.buffer.asUint8List()),
                ctx: AudioContext(
                    android: AudioContextAndroid(
                        contentType: AndroidContentType.music,
                        isSpeakerphoneOn: true,
                        stayAwake: false,
                        usageType: AndroidUsageType.notification,
                        audioFocus: AndroidAudioFocus.gainTransient),
                    iOS: AudioContextIOS(
                        category: AVAudioSessionCategory.playback)));
          } else {
            await _audioPlayer.setSourceAsset("audio/notification_sound.wav");
            await _audioPlayer.setReleaseMode(ReleaseMode.loop);
            await _audioPlayer
                .play(AssetSource('audio/notification_sound.wav'));
          }
        }
      } else {
        if (_audioPlayer.state != PlayerState.stopped) {
          await _audioPlayer.stop();
        }
      }
    } catch (e) {
      print("Error in playSound: $e");
    }
  }
}
