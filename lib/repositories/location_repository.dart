import '../services/api_service.dart';
import '../models/location_model.dart';

class LocationRepository {
  LocationRepository();

  Future<List<LocationNode>> states({int pageSize = 50}) async {
    final raw = await ApiService.instance.getStates();
    return raw.map((e) => LocationNode.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<LocationNode>> districts({
    String? stateSlug,
    String? stateId,
    int pageSize = 100,
  }) async {
    final raw = await ApiService.instance.getDistricts(stateSlug ?? '');
    return raw.map((e) => LocationNode.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<LocationNode>> subdistricts({
    String? districtId,
    String? stateSlug,
    String? districtSlug,
    int pageSize = 100,
  }) async {
    final raw = await ApiService.instance.getSubdistricts(districtSlug ?? '', state: stateSlug);
    return raw.map((e) => LocationNode.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<LocationNode>> villages({
    String? subdistrictId,
    String? pincode,
    int pageSize = 100,
    String? stateSlug,
    String? districtSlug,
    String? subdistrictSlug,
  }) async {
    final raw = await ApiService.instance.getVillages(subdistrictSlug ?? '', state: stateSlug, district: districtSlug);
    return raw.map((e) => LocationNode.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<LocationSearchResult>> search(String query, {int limit = 20}) async {
    final raw = await ApiService.instance.searchLocations(query);
    return raw.map((e) => LocationSearchResult.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<LocationProfile> profile({required bool isAuthenticated}) async {
    final raw = await ApiService.instance.getLocationProfile();
    if (raw == null) return const LocationProfile();
    return LocationProfile.fromJson(raw);
  }

  Future<LocationProfile> setProfile({
    required bool isAuthenticated,
    required Map<String, dynamic> body,
  }) async {
    await ApiService.instance.updateLocationProfile(body);
    return profile(isAuthenticated: isAuthenticated);
  }
}
