import '../../domain/repositories/supplies_repository.dart';
import '../datasources/supplies_remote_data_source.dart';

class SuppliesRepositoryImpl implements SuppliesRepository {
  SuppliesRepositoryImpl(this.remote);
  final SuppliesRemoteDataSource remote;
  @override
  Future<SupplyData> get(String path) => remote.get(path);
  @override
  Future<List<SupplyData>> list(String path) => remote.list(path);
  @override
  Future<SupplyData> mutate(
    String path,
    SupplyData body, {
    String method = 'POST',
  }) => remote.mutate(path, body, method: method);
  @override
  Future<List<SupplyData>> suppliers() => list('/suppliers');
  @override
  Future<List<SupplyData>> products(String supplier) =>
      list('/suppliers/$supplier/products');
  @override
  Future<List<SupplyData>> orders(String house) =>
      list('/houses/$house/supply-orders');
  @override
  Future<SupplyData> order(String house, String id) =>
      get('/houses/$house/supply-orders/$id');
  @override
  Future<SupplyData> create(String house, SupplyData body) =>
      mutate('/houses/$house/supply-orders', body);
  @override
  Future<SupplyData> action(
    String house,
    String id,
    String action,
    SupplyData body,
  ) => mutate('/houses/$house/supply-orders/$id/$action', body);
  @override
  Future<SupplyData> debts(String house) =>
      get('/houses/$house/me/debts');
}
