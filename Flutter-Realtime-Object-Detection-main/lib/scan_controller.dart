import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';

class ScanController extends GetxController {
  final ImagePicker _picker = ImagePicker();
  var results = ''.obs;
  bool isProcessingFrame = false;

  @override
  void onInit() {
    super.onInit();
    initTFlite();
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  Future<void> initTFlite() async {
    try {
      await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
        isAsset: true,
        numThreads: 1,
        useGpuDelegate: false,
      );
      print("TFLite model loaded successfully");
    } catch (e) {
      print("Failed to load TFLite model: $e");
      Get.dialog(
        AlertDialog(
          title: const Text('Model Error'),
          content: Text('Error loading TFLite model: $e'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      processPickedVideo(video.path);
    } else {
      print("No video selected");
    }
  }

  Future<void> processPickedVideo(String videoPath) async {
    if (!isProcessingFrame) {
      isProcessingFrame = true;
      try {
        VideoPlayerController controller = VideoPlayerController.file(File(videoPath));
        await controller.initialize();

        final durationMs = controller.value.duration;
        const frameIntervalMs = 200; // Extract a frame every second

        if (durationMs.inMilliseconds > 0) {
          int currentTimeMs = 0;
          while (currentTimeMs < durationMs.inMilliseconds) {
            Uint8List? frameBytes = await VideoThumbnail.thumbnailData(
              video: videoPath,
              imageFormat: ImageFormat.JPEG,
              timeMs: currentTimeMs,
              quality: 75,
            );

            if (frameBytes != null) {
              img.Image? frameImage = img.decodeImage(frameBytes);
              if (frameImage != null) {
                Uint8List preprocessedImage = await preprocessImage(frameImage, 224);
                var recognitions = await Tflite.runModelOnBinary(
                  binary: preprocessedImage,
                  numResults: 1,
                  threshold: 0.4,
                  asynch: true,
                );

                if (recognitions != null) {
                  print("Detection results: $recognitions");
                  results.value = recognitions.map((result) => result['label']).join(", ");
                  update(); // Notify the UI about the change
                } else {
                  print("No recognitions");
                }
              }
            }

            currentTimeMs += frameIntervalMs;
          }
        } else {
          print("Invalid video duration: ${durationMs.inMilliseconds}");
        }
      } catch (e) {
        print("Error during object detection: $e");
      } finally {
        isProcessingFrame = false;
      }
    }
  }

  Future<Uint8List> preprocessImage(img.Image image, int inputSize) async {
    img.Image resizedImage = img.copyResize(image, width: inputSize, height: inputSize);
    Float32List float32List = imageToFloat32List(resizedImage, inputSize);
    Float32List expandedList = addBatchDimension(float32List, inputSize);
    return expandedList.buffer.asUint8List();
  }

  Float32List imageToFloat32List(img.Image image, int inputSize) {
    var convertedBytes = Float32List(inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (img.getRed(pixel) / 255.0) - 0.5;
        buffer[pixelIndex++] = (img.getGreen(pixel) / 255.0) - 0.5;
        buffer[pixelIndex++] = (img.getBlue(pixel) / 255.0) - 0.5;
      }
    }
    return convertedBytes;
  }
   Float32List addBatchDimension(Float32List float32List, int inputSize) {
    // Assuming the image size is inputSize x inputSize x 3
    int batchSize = 1;
    int numElements = batchSize * inputSize * inputSize * 3;
    var batchFloat32List = Float32List(numElements);
    int offset = 0;
    for (var i = 0; i < float32List.length; i++) {
      batchFloat32List[offset++] = float32List[i];
    }
    print("image expanded");
    return batchFloat32List;
  }
}
