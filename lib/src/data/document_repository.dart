import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'stored_document.dart';

/// Result of an upload attempt — a plain enum-plus-payload instead of
/// throwing, since "found a likely duplicate" and "too large to store" are
/// both expected outcomes the UI needs to show the user, not errors.
sealed class DocumentUploadResult {
  const DocumentUploadResult();
}

class DocumentUploadSuccess extends DocumentUploadResult {
  const DocumentUploadSuccess(this.id);
  final String id;
}

class DocumentUploadTooLarge extends DocumentUploadResult {
  const DocumentUploadTooLarge(this.fileSizeBytes);
  final int fileSizeBytes;
}

class DocumentUploadDuplicate extends DocumentUploadResult {
  const DocumentUploadDuplicate(this.existing);
  final StoredDocument existing;
}

/// Stores and retrieves original scanned/uploaded documents (bills,
/// receipts, and — once Insurance ships — policy documents), independent
/// of whatever OCR/extraction happens to them. See [StoredDocument] for why
/// bytes live inline on the Firestore doc rather than in Cloud Storage.
class DocumentRepository {
  DocumentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Raw file size cap. Firestore documents top out at 1 MiB total;
  /// base64 adds ~33% overhead, and a comfortable margin is left for the
  /// doc's other fields (name, metadata) — 650 KB raw keeps the encoded
  /// payload safely under that limit for the overwhelming majority of
  /// phone-camera receipts and single-page bill PDFs.
  static const maxFileBytes = 650 * 1024;

  CollectionReference<Map<String, dynamic>> _documents(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('documents');

  Stream<List<StoredDocument>> watchDocuments(String groupId) {
    return _documents(groupId).orderBy('uploadedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => StoredDocument.fromDoc(d.id, d.data())).toList(),
    );
  }

  String hashBytes(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<StoredDocument?> _findDuplicate({
    required String groupId,
    required String fileHash,
  }) async {
    final snap = await _documents(
      groupId,
    ).where('fileHash', isEqualTo: fileHash).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return StoredDocument.fromDoc(snap.docs.first.id, snap.docs.first.data());
  }

  /// Stores [bytes] as a new document. Returns [DocumentUploadTooLarge]
  /// without writing anything if it exceeds [maxFileBytes], or — unless
  /// [allowDuplicate] is set — [DocumentUploadDuplicate] with the existing
  /// match if the exact same file was already stored, so the caller can
  /// ask the user before saving a second copy.
  Future<DocumentUploadResult> uploadDocument({
    required String groupId,
    required Uint8List bytes,
    required String name,
    required String mimeType,
    required String category,
    required String uploadedByUid,
    required String uploadedByName,
    DateTime? documentDate,
    String? provider,
    double? amount,
    String? associatedBillId,
    String? associatedInsurancePolicyId,
    DocumentOcrStatus ocrStatus = DocumentOcrStatus.notApplicable,
    bool allowDuplicate = false,
  }) async {
    if (bytes.lengthInBytes > maxFileBytes) {
      return DocumentUploadTooLarge(bytes.lengthInBytes);
    }
    final hash = hashBytes(bytes);
    if (!allowDuplicate) {
      final existing = await _findDuplicate(groupId: groupId, fileHash: hash);
      if (existing != null) return DocumentUploadDuplicate(existing);
    }

    final now = DateTime.now();
    final effectiveDate = documentDate ?? now;
    final doc = StoredDocument(
      id: '',
      name: name,
      category: category,
      mimeType: mimeType,
      fileSizeBytes: bytes.lengthInBytes,
      fileHash: hash,
      base64Data: base64Encode(bytes),
      uploadedAt: now,
      year: effectiveDate.year,
      month: effectiveDate.month,
      uploadedByUid: uploadedByUid,
      uploadedByName: uploadedByName,
      ocrStatus: ocrStatus,
      documentDate: documentDate,
      provider: provider,
      amount: amount,
      associatedBillId: associatedBillId,
      associatedInsurancePolicyId: associatedInsurancePolicyId,
    );
    final ref = await _documents(groupId).add(doc.toDoc());
    return DocumentUploadSuccess(ref.id);
  }

  Future<void> deleteDocument({required String groupId, required String documentId}) {
    return _documents(groupId).doc(documentId).delete();
  }

  Future<void> updateDocumentDate({
    required String groupId,
    required String documentId,
    required DateTime documentDate,
  }) {
    return _documents(groupId).doc(documentId).update({
      'documentDate': Timestamp.fromDate(documentDate),
      'year': documentDate.year,
      'month': documentDate.month,
    });
  }
}
