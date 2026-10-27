typedef SupplyData = Map<String, dynamic>;

abstract class SuppliesRepository {
  Future<List<SupplyData>> suppliers();
  Future<List<SupplyData>> products(String supplier);
  Future<List<SupplyData>> orders(String house);
  Future<SupplyData> order(String house, String id);
  Future<SupplyData> create(String house, SupplyData request);
  Future<SupplyData> action(
    String house,
    String id,
    String action,
    SupplyData request,
  );
  Future<SupplyData> debts(String house);
  Future<SupplyData> get(String path);
  Future<List<SupplyData>> list(String path);
  Future<SupplyData> mutate(
    String path,
    SupplyData request, {
    String method = 'POST',
  });
}
