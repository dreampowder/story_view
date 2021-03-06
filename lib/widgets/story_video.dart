import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

class VideoLoader {
  String url;

  File videoFile;

  Map<String, dynamic> requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if(kIsWeb){
      this.state = LoadState.success;
      onComplete();
      return;
    }
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
    }

    final fileStream = DefaultCacheManager()
        .getFileStream(this.url, headers: this.requestHeaders);

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          this.videoFile = fileResponse.file;
          onComplete();
        }
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController storyController;
  final VideoLoader videoLoader;

  StoryVideo(this.videoLoader, {this.storyController, Key key})
      : super(key: key ?? UniqueKey());

  static StoryVideo url(String url,
      {StoryController controller,
      Map<String, dynamic> requestHeaders,
      Key key}) {
    return StoryVideo(
      VideoLoader(url, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void> playerLoader;

  StreamSubscription _streamSubscription;

  VideoPlayerController playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        if(kIsWeb){
          print("Loading Video URL: widget.videoLoader.url");
          this.playerController = VideoPlayerController.network(widget.videoLoader.url)
            ..setVolume(widget.storyController.isAudioMuted ? 0 : 1.0);
        }else{
          this.playerController =
          VideoPlayerController.file(widget.videoLoader.videoFile)
            ..setVolume(widget.storyController.isAudioMuted ? 0 : 1.0);
        }


        playerController.initialize().then((v) {
          setState(() {});
          widget.storyController.play();
        });

        if (widget.storyController != null) {
          _streamSubscription =
              widget.storyController.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              playerController.pause();
            } else if(playbackState == PlaybackState.play){
              playerController.play();
            } else if(playbackState == PlaybackState.mute){
              playerController.setVolume(0);
            } else if(playbackState == PlaybackState.unmute){
              playerController.setVolume(1.0);
            }
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    switch(widget.videoLoader.state){
      case LoadState.loading:
        return Center(
          child: Container(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
        );
        break;
      case LoadState.success:
        if(playerController.value.isInitialized){
          return AspectRatio(
            aspectRatio: playerController.value.aspectRatio,
            child: VideoPlayer(playerController),
          );
        }else{
          return Center(
            child: Container(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          );
        }
        break;
      case LoadState.failure:
        return Center(
            child: Text(
              "Media failed to load.",
              style: TextStyle(
                color: Colors.white,
              ),
            ));
        break;
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void dispose() {
    playerController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
