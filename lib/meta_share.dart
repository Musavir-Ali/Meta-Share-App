import 'package:flutter/services.dart';

/// Where a picked photo is handed off.
enum ShareDestination {
  instagramStory('instagram_story'),
  instagramFeed('instagram_feed'),
  facebookStory('facebook_story'),
  facebookFeed('facebook_feed');

  const ShareDestination(this.wireName);

  final String wireName;

  bool get needsFacebookAppId =>
      this == ShareDestination.instagramStory ||
      this == ShareDestination.facebookStory;
}

/// Hands a local image to Instagram or Facebook using the platform share flows.
///
/// Instagram Stories: `com.instagram.share.ADD_TO_STORY` on Android, and the
/// `instagram-stories://share` pasteboard flow on iOS.
/// Instagram Feed: `ACTION_SEND` on Android, and a `.igo` document interaction
/// (`com.instagram.exclusivegram`) on iOS.
/// Facebook Stories: `com.facebook.stories.ADD_TO_STORY` on Android, and the
/// `facebook-stories://share` pasteboard flow on iOS.
/// Facebook Feed: `ACTION_SEND` to the Facebook app on Android. iOS has no
/// equivalent image intent, so the system share sheet is presented there.
class MetaShare {
  MetaShare._();

  static const MethodChannel _channel = MethodChannel(
    'com.share1.app/meta_share',
  );

  static Future<void> share({
    required ShareDestination destination,
    required String filePath,
    required String facebookAppId,
  }) {
    return _channel.invokeMethod<void>('share', <String, String>{
      'destination': destination.wireName,
      'filePath': filePath,
      'facebookAppId': facebookAppId,
    });
  }
}
