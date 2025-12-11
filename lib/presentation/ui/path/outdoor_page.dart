import 'package:flutter/material.dart';

class OutdoorPage extends StatelessWidget {
  const OutdoorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wb_sunny, size: 80, color: Colors.orange),
          const SizedBox(height: 20),
          const Text(
            "현재 실외 이동 중입니다",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "건물 입구에 도착하면\n자동으로 실내 지도로 전환됩니다.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          // (옵션) 테스트용: 강제 실내 전환 버튼
          // ElevatedButton(onPressed: () {}, child: Text("강제 실내 전환"))
        ],
      ),
    );
  }
}