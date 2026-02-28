import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IncidentService {
  static Future<void> createIncidentAndRunAI(String rawText) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in");

    final docRef = await FirebaseFirestore.instance.collection('incidents').add({
      'rawText': rawText.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'status': 'new',
    });

    // IMPORTANT: your functions deployed to us-central1
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('aiEnrichIncident');

    await callable.call({'incidentId': docRef.id});
  }
}