// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  const email = 'christiankethaguacito@sksu.edu.ph';
  
  print('Looking for user: $email');
  
  final query = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email)
      .get();
  
  print('Found ${query.docs.length} user(s)');
  
  for (var doc in query.docs) {
    print('User ID: ${doc.id}');
    print('Current role: ${doc.data()['role']}');
    
    await doc.reference.update({'role': 'admin'});
    print('✅ Updated to admin!');
  }
  
  if (query.docs.isEmpty) {
    print('❌ No user found with that email');
  }
}
