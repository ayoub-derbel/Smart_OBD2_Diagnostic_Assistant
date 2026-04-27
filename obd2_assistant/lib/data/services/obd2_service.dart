abstract class Obd2Service {
  Future<List<String>> discoverSupportedPids();
  Future<Map<String, List<String>>> readAllDTCs();
  Future<String?> readVin();
  Future<List<Map<String, String>>> readFreezeFrames();
  Future<Map<String, String>> readMultiplePids(List<String> pids);
}
