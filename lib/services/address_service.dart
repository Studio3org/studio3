import '../models/address.dart';
import 'api_client.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class AddressService {
  AddressService._();
  static final AddressService instance = AddressService._();

  static const _cacheKey = 'addresses.me';

  final _api = ApiClient.instance;

  Future<List<Address>> getAddresses() async {
    final json = await _api.get('/api/user/me/addresses', auth: true);
    return _api.extractList(json).map(Address.fromJson).toList();
  }

  /// Cache-first address list — small, rarely-changing dataset, so a long
  /// TTL is safe. Mutations below invalidate this key on success.
  Future<List<Address>> getAddressesCached({bool forceRefresh = false}) {
    return CacheService.instance.fetchWithCache<List<Address>>(
      key: _cacheKey,
      ttl: const Duration(minutes: 30),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss(_cacheKey);
        }
        return _api.get('/api/user/me/addresses', auth: true);
      },
      parse: (json) => _api.extractList(json).map(Address.fromJson).toList(),
    );
  }

  Future<Address> createAddress(Address address) async {
    final json = await _api.post(
      '/api/user/me/addresses',
      body: address.toRequestBody(),
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate(_cacheKey);
    return Address.fromJson(data);
  }

  Future<Address> updateAddress(String id, Address address) async {
    final json = await _api.patch(
      '/api/user/me/addresses/$id',
      body: address.toRequestBody(),
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate(_cacheKey);
    return Address.fromJson(data);
  }

  Future<void> deleteAddress(String id) async {
    await _api.delete('/api/user/me/addresses/$id');
    await CacheService.instance.invalidate(_cacheKey);
  }

  Future<Address> setDefault(String id) async {
    final json = await _api.post(
      '/api/user/me/addresses/$id/default',
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    await CacheService.instance.invalidate(_cacheKey);
    return Address.fromJson(data);
  }
}
