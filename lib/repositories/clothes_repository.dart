import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clothes.dart';

class ClothesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Clothes>> fetchClothes() async {
    final querySnapshot = await _firestore.collection('clothes').get();
    return querySnapshot.docs.map((doc) => Clothes.fromFirestore(doc)).toList();
  }
}
