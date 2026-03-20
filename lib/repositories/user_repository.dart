import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserShoulderWidth(
    String uid,
    double baseShoulderWidthPx,
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'baseShoulderWidthPx': baseShoulderWidthPx,
    }, SetOptions(merge: true));
  }
}
