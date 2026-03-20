import 'package:cloud_firestore/cloud_firestore.dart';

// 簡易的な服のデータモデルクラス
class Clothes {
  final String id;
  final String imageUrl;
  final String itemName;
  final String brandName;
  final num baseShoulderWidthPx;

  Clothes({
    required this.id,
    this.imageUrl = "",
    this.itemName = "",
    this.brandName = "",
    this.baseShoulderWidthPx = 0,
  });

  factory Clothes.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Clothes(
      id: doc.id,
      imageUrl: data?['imageUrl'] ?? "",
      itemName: data?['itemName'] ?? "",
      brandName: data?['brandName'] ?? "",
      baseShoulderWidthPx: data?['baseShoulderWidthPx'] ?? 0,
    );
  }
}
