import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import 'passenger_request_model.dart' show parseFlexibleDate;

/// A lost or found item posted by a tourist/local.
///
/// Replaces the scattered WhatsApp-group hunt for lost bags/cameras/purses:
/// one public board anyone can browse from anywhere, with a photo, details
/// and a direct call button. New posts push-notify every app user.
class LostFoundItem {
  final String id; // 'lf_<millis>'
  final String type; // 'lost' | 'found'
  final String title; // "Black DSLR camera bag"
  final String description;
  final String location; // village / spot
  final String date; // when it was lost/found (YYYY-MM-DD)
  final String contactName;
  final String phone;
  final String photoPath; // URL or local path
  final bool resolved; // true = reunited with owner
  final DateTime createdAt;

  LostFoundItem({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    required this.location,
    required this.date,
    required this.contactName,
    required this.phone,
    this.photoPath = '',
    this.resolved = false,
    required this.createdAt,
  });

  bool get isLost => type == 'lost';

  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'description': description,
        'location': location,
        'date': date,
        'contactName': contactName,
        'phone': phone,
        'photoPath': photoPath,
        'resolved': resolved,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LostFoundItem.fromMap(String id, Map<String, dynamic> map) =>
      LostFoundItem(
        id: id,
        type: map['type'] ?? 'lost',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        location: map['location'] ?? '',
        date: map['date'] ?? '',
        contactName: map['contactName'] ?? '',
        phone: map['phone'] ?? '',
        photoPath: map['photoPath'] ?? '',
        resolved: map['resolved'] ?? false,
        createdAt: parseFlexibleDate(map['createdAt']),
      );
}

class LostFoundProvider extends ChangeNotifier {
  List<LostFoundItem> _items = [];
  final FirebaseService _fb = FirebaseService();

  LostFoundProvider() {
    _init();
  }

  void _init() {
    if (FirebaseService.isInitialized) {
      _fb.streamLostFound().listen((fresh) {
        _items = LocalStorageService.demoSeedingDisabled
            ? fresh.where((i) => i.id.contains('_')).toList()
            : fresh;
        notifyListeners();
      });
    }
  }

  List<LostFoundItem> get items => _items;

  Future<void> post(LostFoundItem item) async {
    if (FirebaseService.isInitialized) {
      await _fb.addLostFound(item);
    } else {
      _items.insert(0, item);
      notifyListeners();
    }
  }

  Future<void> setResolved(LostFoundItem item, bool resolved) async {
    if (FirebaseService.isInitialized) {
      await _fb.setLostFoundResolved(item.id, resolved);
    } else {
      final i = _items.indexWhere((x) => x.id == item.id);
      if (i >= 0) {
        _items[i] = LostFoundItem(
          id: item.id, type: item.type, title: item.title,
          description: item.description, location: item.location,
          date: item.date, contactName: item.contactName, phone: item.phone,
          photoPath: item.photoPath, resolved: resolved,
          createdAt: item.createdAt,
        );
        notifyListeners();
      }
    }
  }

  Future<void> delete(String id) async {
    if (FirebaseService.isInitialized) {
      await _fb.deleteDoc('lost_found', id);
    } else {
      _items.removeWhere((i) => i.id == id);
      notifyListeners();
    }
  }
}
