import '../entities/scan_record.dart';

/// Abstract repository for scan history persistence.
abstract class ScanHistoryRepository {
  Future<void> saveScan(ScanRecord record);
  Future<List<ScanRecord>> getAllScans();
  Future<List<ScanRecord>> getRecentScans({int limit = 5});
  Future<void> deleteScan(String id);
  Future<void> clearAll();
}
