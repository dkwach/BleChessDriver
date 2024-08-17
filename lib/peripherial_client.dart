abstract class PeripherialClient {
  Future<void> send(List<int> data);
  Stream<List<int>> recieve();
}
