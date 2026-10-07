import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/app_data.dart';
import '../utils/network_request.dart';

final List<Salon> _memorySalons = List<Salon>.unmodifiable(salons);
final List<Product> _memoryProducts = List<Product>.unmodifiable(products);

abstract class CatalogService {
  Future<CatalogData> loadCatalog();
}

class SupabaseCatalogService implements CatalogService {
  SupabaseCatalogService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<CatalogData> loadCatalog() async {
    final List<List<dynamic>> rows =
        await Future.wait<List<dynamic>>(<Future<List<dynamic>>>[
          _fetchTable(supabaseSalonsTable),
          _fetchTable('$supabaseProductsTable?select=*&is_active=eq.true'),
          _fetchTable(
            'salon_packages?select=*&is_active=eq.true&order=created_at.asc',
          ),
          _fetchTable(
            'salon_services?select=*&is_active=eq.true&order=created_at.asc',
          ),
        ]);
    final List<dynamic> salonRows = rows[0];
    final List<dynamic> productRows = rows[1];
    final List<dynamic> packageRows = rows[2];
    final List<dynamic> serviceRows = rows[3];
    final Map<String, List<ServicePackage>> packagesBySalonId = packageRows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .map(ServicePackage.fromSupabase)
        .where((ServicePackage item) => (item.salonId ?? '').isNotEmpty)
        .fold<Map<String, List<ServicePackage>>>(
          <String, List<ServicePackage>>{},
          (Map<String, List<ServicePackage>> map, ServicePackage item) {
            map.putIfAbsent(item.salonId!, () => <ServicePackage>[]).add(item);
            return map;
          },
        );
    final Map<String, List<ServiceItem>> servicesBySalonId = serviceRows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .map(ServiceItem.fromSupabase)
        .where((ServiceItem item) => (item.salonId ?? '').isNotEmpty)
        .fold<Map<String, List<ServiceItem>>>(<String, List<ServiceItem>>{}, (
          Map<String, List<ServiceItem>> map,
          ServiceItem item,
        ) {
          map.putIfAbsent(item.salonId!, () => <ServiceItem>[]).add(item);
          return map;
        });

    final List<Salon> remoteSalons = salonRows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: false)
        .asMap()
        .entries
        .map((MapEntry<int, Map<String, dynamic>> entry) {
          final Salon salon = Salon.fromSupabase(
            entry.value,
            fallbackImagePath: currentDefaultSalonImageUrl(),
          );
          final List<ServicePackage> salonPackagesForSalon =
              packagesBySalonId[salon.id] ?? const <ServicePackage>[];
          final List<ServiceItem> salonServicesForSalon =
              servicesBySalonId[salon.id] ?? const <ServiceItem>[];
          final List<String> serviceTags = salon.services.isNotEmpty
              ? salon.services
              : <String>[
                  ...salonPackagesForSalon.map(
                    (ServicePackage item) => item.name,
                  ),
                  ...salonServicesForSalon.map((ServiceItem item) => item.name),
                ].take(4).toList(growable: false);
          return Salon(
            id: salon.id,
            name: salon.name,
            imagePath: salon.imagePath,
            rating: salon.rating,
            reviews: salon.reviews,
            location: salon.location,
            distance: salon.distance,
            services: serviceTags,
            description: salon.description,
            phone: salon.phone,
            priceLabel: salon.priceLabel,
            homeServiceAvailable: salon.homeServiceAvailable,
            address: salon.address,
            latitude: salon.latitude,
            longitude: salon.longitude,
            packages: salonPackagesForSalon,
            serviceItems: salonServicesForSalon,
          );
        })
        .toList(growable: false);

    final List<Product> remoteProducts = productRows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (MapEntry<int, Map<String, dynamic>> entry) => Product.fromSupabase(
            entry.value,
            fallbackImagePath: currentDefaultProductImageUrl(),
          ),
        )
        .toList(growable: false);

    return CatalogData(salons: remoteSalons, products: remoteProducts);
  }

  Future<List<dynamic>> _fetchTable(String table) async {
    final String path = table.contains('?') ? table : '$table?select=*';
    final Uri uri = Uri.parse('$supabaseUrl/rest/v1/$path');
    final http.Response response = await performFreshlineHttpRequest(
      () => _client.get(
        uri,
        headers: <String, String>{
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
        },
      ),
      fallback: 'Freshline could not load the catalog.',
    );

    if (response.statusCode == 404) {
      return const <dynamic>[];
    }

    final String? transientMessage = freshlineTransientHttpErrorMessage(
      response.statusCode,
    );
    if (transientMessage != null) {
      throw StateError(transientMessage);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <dynamic>[];
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      return decoded;
    }

    return const <dynamic>[];
  }

  void dispose() {
    _client.close();
  }
}

class MemoryCatalogService implements CatalogService {
  MemoryCatalogService({List<Salon>? salonItems, List<Product>? productItems})
    : salons = salonItems ?? _memorySalons,
      products = productItems ?? _memoryProducts;

  final List<Salon> salons;
  final List<Product> products;

  @override
  Future<CatalogData> loadCatalog() async {
    final List<Salon> enrichedSalons = salons
        .map((Salon salon) {
          final List<ServicePackage> activePackages = salon.packages
              .where((ServicePackage item) => item.isActive)
              .toList(growable: false);
          final List<ServiceItem> activeServices = salon.serviceItems
              .where((ServiceItem item) => item.isActive)
              .toList(growable: false);
          final List<String> serviceTags = salon.services.isNotEmpty
              ? salon.services
              : <String>[
                  ...activePackages.map((ServicePackage item) => item.name),
                  ...activeServices.map((ServiceItem item) => item.name),
                ].take(4).toList(growable: false);

          return Salon(
            id: salon.id,
            name: salon.name,
            imagePath: salon.imagePath,
            rating: salon.rating,
            reviews: salon.reviews,
            location: salon.location,
            distance: salon.distance,
            services: serviceTags,
            description: salon.description,
            phone: salon.phone,
            priceLabel: salon.priceLabel,
            homeServiceAvailable: salon.homeServiceAvailable,
            address: salon.address,
            latitude: salon.latitude,
            longitude: salon.longitude,
            packages: activePackages,
            serviceItems: activeServices,
          );
        })
        .toList(growable: false);
    return CatalogData(
      salons: enrichedSalons,
      products: products
          .where((Product product) => product.isActive)
          .toList(growable: false),
    );
  }
}
