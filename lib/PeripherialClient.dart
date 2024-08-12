abstract class PeripherialClient
{
  Future<void> send(List<int> data);
  List<int> recieve();
}