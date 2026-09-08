import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  static late AudioPlayer _audioPlayer;

  static Future<void> initAudio() async {
    _audioPlayer = AudioPlayer(playerId: "playerId");
    await _audioPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.music,
        isSpeakerphoneOn: true,
        stayAwake: false,
        usageType: AndroidUsageType.notification,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
      ),
    ));
  }

  static Future<void> playSound(bool isPlay) async {
    try {
      if (isPlay) {
        if (_audioPlayer.state != PlayerState.playing) {
          // Play directly from asset – no manual byte loading
          await _audioPlayer.play(AssetSource('audio/notification_sound.wav'));
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
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
