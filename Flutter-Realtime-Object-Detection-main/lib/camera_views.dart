//import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'scan_controller.dart';

class ScanPage extends StatelessWidget {
  final ScanController _scanController = Get.put(ScanController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Picker and TFLite')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(() => Text('Detection Result: ${_scanController.results}')),
            ElevatedButton(
              onPressed: _scanController.pickVideo,
              child: Text('Pick Video'),
            ),
          ],
        ),
      ),
    );
  }
}
