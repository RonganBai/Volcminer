import 'package:flutter/material.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';

class BarcodeScannerPage extends StatelessWidget {
  const BarcodeScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(LegacyZhTexts.barcodeScannerWebTitle)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            LegacyZhTexts.barcodeScannerWebUnsupported,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
