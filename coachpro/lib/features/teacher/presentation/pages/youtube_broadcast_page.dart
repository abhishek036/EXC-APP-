import 'package:flutter/material.dart';
import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../../../core/di/injection_container.dart';

class YoutubeBroadcastPage extends StatefulWidget {
  final String batchId;

  const YoutubeBroadcastPage({Key? key, required this.batchId}) : super(key: key);

  @override
  State<YoutubeBroadcastPage> createState() => _YoutubeBroadcastPageState();
}

class _YoutubeBroadcastPageState extends State<YoutubeBroadcastPage> {
  final _teacherRepo = sl<TeacherRepository>();
  late ApiVideoLiveStreamController _controller;

  bool _isInit = false;
  bool _isStreaming = false;
  bool _isLoading = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _broadcastId;
  String? _streamKey;
  String? _streamUrl;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
       _controller = ApiVideoLiveStreamController(
        initialAudioConfig: AudioConfig(bitrate: 128000),
        initialVideoConfig: VideoConfig.withDefaultBitrate(
          resolution: Resolution.RESOLUTION_720,
        ),
        onConnectionSuccess: () {
          if (mounted) {
            setState(() { _isStreaming = true; _isLoading = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('YouTube Live Stream Started! 🚀'), backgroundColor: AppColors.success),
            );
          }
        },
        onConnectionFailed: (error) {
           if (mounted) {
             setState(() { _isStreaming = false; _isLoading = false; });
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Streaming Failed: $error'), backgroundColor: AppColors.coralRed),
            );
           }
        },
        onDisconnection: () {
           if (mounted) {
             setState(() { _isStreaming = false; });
           }
        },
      );
      await _controller.startPreview();
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _controller.stopPreview();
    if (_isStreaming) _controller.stopStreaming();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _startLiveStream() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a stream title.',), backgroundColor: AppColors.coralRed));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Ask Node.js to spin up a YouTube Live Stream
      final result = await _teacherRepo.createYoutubeLiveStream(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        privacyStatus: 'unlisted', // Make it unlisted for students only
      );

      _broadcastId = result['broadcastId'];
      _streamKey = result['streamKey'];
      // Fallback RTMP if Node.js doesn't provide
      _streamUrl = result['streamUrl'] ?? 'rtmp://a.rtmp.youtube.com/live2';

      if (_streamKey == null) {
        throw Exception('Stream Key was not returned from YouTube API.');
      }

      // 2. Start pushing the camera feed to the URL
      await _controller.startStreaming(
        streamKey: _streamKey!,
        url: _streamUrl!,
      );

      // Now we could also automatically save `_broadcastId` to the Database
      // so the students can instantly see the live video on the Dashboard!
      
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.coralRed),
        );
      }
    }
  }

  Future<void> _stopLiveStream() async {
    await _controller.stopStreaming();
    setState(() => _isStreaming = false);
  }

  Future<void> _toggleCamera() async {
    await _controller.switchCamera();
  }

  Future<void> _toggleMicrophone() async {
    await _controller.toggleMute();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.moltenAmber)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview Full Screen
          Positioned.fill(
            child: ApiVideoCameraPreview(controller: _controller),
          ),
          
          // Header / Controls Overlay
          SafeArea(
            child: Column(
              children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     IconButton(
                       icon: const Icon(Icons.arrow_back, color: Colors.white),
                       onPressed: () => Navigator.pop(context),
                     ),
                     if (_isStreaming)
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.coralRed,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                              SizedBox(width: 6),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                   ],
                 ),

                 const Spacer(),

                 // Bottom Control Panel
                 Container(
                   decoration: const BoxDecoration(
                     color: AppColors.eliteLightBg,
                     borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                     border: Border(top: BorderSide(color: Colors.black, width: 3)),
                   ),
                   padding: const EdgeInsets.all(20),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        if (!_isStreaming) ...[
                          CustomTextField(
                            hint: 'Live Class Topic...',
                            prefixIcon: Icons.title,
                            controller: _titleController,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            hint: 'Description (Optional)',
                            prefixIcon: Icons.description,
                            controller: _descController,
                          ),
                          const SizedBox(height: 20),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: AppColors.elitePrimary),
                              icon: const Icon(Icons.cameraswitch, color: Colors.white),
                              onPressed: _toggleCamera,
                            ),
                            
                            if (!_isStreaming)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: CustomButton(
                                    text: _isLoading ? 'CONNECTING...' : 'GO LIVE',
                                    backgroundColor: AppColors.elitePrimary,
                                    foregroundColor: Colors.white,
                                    isLoading: _isLoading,
                                    onPressed: _isLoading ? () {} : _startLiveStream,
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: CustomButton(
                                    text: 'END STREAM',
                                    backgroundColor: AppColors.coralRed,
                                    foregroundColor: Colors.white,
                                    onPressed: _stopLiveStream,
                                  ),
                                ),
                              ),

                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: AppColors.elitePrimary),
                              icon: const Icon(Icons.mic, color: Colors.white),
                              onPressed: _toggleMicrophone,
                            ),
                          ],
                        ),
                     ],
                   ),
                 )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
