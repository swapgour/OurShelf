import 'package:cloud_firestore/cloud_firestore.dart';

/// Broad buckets for the document library — distinct from grocery
/// [catalogueCategories]: these describe a *document*, not a product.
const documentCategories = <String>[
  'Utilities',
  'Insurance',
  'Finance',
  'Groceries',
  'Other',
];

enum DocumentOcrStatus { notApplicable, pending, success, failed }

DocumentOcrStatus _ocrStatusFromString(String? value) {
  switch (value) {
    case 'pending':
      return DocumentOcrStatus.pending;
    case 'success':
      return DocumentOcrStatus.success;
    case 'failed':
      return DocumentOcrStatus.failed;
    default:
      return DocumentOcrStatus.notApplicable;
  }
}

String _ocrStatusToString(DocumentOcrStatus status) => status.name;

/// A permanently retained original — a scanned/uploaded bill, receipt or
/// (eventually) insurance policy document. Storage and any OCR/extraction
/// are independent: a document is saved as soon as it's picked, before any
/// processing happens, so a failed or skipped extraction never loses it.
///
/// The raw bytes live inline on the Firestore document (base64) rather than
/// in Cloud Storage — this project avoids Firebase's paid Blaze plan
/// everywhere (push notifications and AI already run through a separate
/// free Cloudflare Worker instead of Cloud Functions for the same reason).
/// That keeps every document genuinely shared with the whole family for
/// free, at the cost of a hard per-file size ceiling — see
/// [DocumentRepository.maxFileBytes].
class StoredDocument {
  const StoredDocument({
    required this.id,
    required this.name,
    required this.category,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.fileHash,
    required this.base64Data,
    required this.uploadedAt,
    required this.year,
    required this.month,
    required this.uploadedByUid,
    required this.uploadedByName,
    required this.ocrStatus,
    this.documentDate,
    this.provider,
    this.amount,
    this.associatedBillId,
    this.associatedInsurancePolicyId,
  });

  final String id;
  final String name;
  final String category;
  final String mimeType;
  final int fileSizeBytes;
  final String fileHash;
  final String base64Data;
  final DateTime uploadedAt;
  final int year;
  final int month;
  final String uploadedByUid;
  final String uploadedByName;
  final DocumentOcrStatus ocrStatus;
  /// The bill/document's own date, if known — null when it couldn't be
  /// read and the user hasn't set it; [year]/[month] fall back to
  /// [uploadedAt] in that case so the document is still findable.
  final DateTime? documentDate;
  final String? provider;
  final double? amount;
  final String? associatedBillId;
  final String? associatedInsurancePolicyId;

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');

  factory StoredDocument.fromDoc(String id, Map<String, dynamic> map) {
    return StoredDocument(
      id: id,
      name: map['name'] as String? ?? 'Document',
      category: map['category'] as String? ?? 'Other',
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      fileHash: map['fileHash'] as String? ?? '',
      base64Data: map['base64Data'] as String? ?? '',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (map['month'] as num?)?.toInt() ?? DateTime.now().month,
      uploadedByUid: map['uploadedByUid'] as String? ?? '',
      uploadedByName: map['uploadedByName'] as String? ?? 'Someone',
      ocrStatus: _ocrStatusFromString(map['ocrStatus'] as String?),
      documentDate: (map['documentDate'] as Timestamp?)?.toDate(),
      provider: map['provider'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      associatedBillId: map['associatedBillId'] as String?,
      associatedInsurancePolicyId: map['associatedInsurancePolicyId'] as String?,
    );
  }

  Map<String, dynamic> toDoc() => {
    'name': name,
    'category': category,
    'mimeType': mimeType,
    'fileSizeBytes': fileSizeBytes,
    'fileHash': fileHash,
    'base64Data': base64Data,
    'uploadedAt': Timestamp.fromDate(uploadedAt),
    'year': year,
    'month': month,
    'uploadedByUid': uploadedByUid,
    'uploadedByName': uploadedByName,
    'ocrStatus': _ocrStatusToString(ocrStatus),
    if (documentDate != null) 'documentDate': Timestamp.fromDate(documentDate!),
    if (provider != null) 'provider': provider,
    if (amount != null) 'amount': amount,
    if (associatedBillId != null) 'associatedBillId': associatedBillId,
    if (associatedInsurancePolicyId != null)
      'associatedInsurancePolicyId': associatedInsurancePolicyId,
  };
}
