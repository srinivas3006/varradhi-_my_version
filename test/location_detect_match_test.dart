import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:vaaradhi/core/utils/location_detector.dart';
import 'package:vaaradhi/models/location_model.dart';
import 'package:vaaradhi/providers/location_provider.dart';

LocationSearchResult _r(LocationLevel type, String name,
        {String state = '', String district = '', String mandal = ''}) =>
    LocationSearchResult(
      type: type,
      id: '$name-$district-$mandal',
      nameEn: name,
      state: state,
      district: district,
      subdistrict: mandal,
    );

/// What `/api/v1/locations/search/` returns for these names (Oct 2026).
final _kesaram = [
  _r(LocationLevel.village, 'Jai Kesaram',
      state: 'Telangana', district: 'Yadadri Bhuvanagiri', mandal: 'Choutuppal'),
  _r(LocationLevel.village, 'Kesaram',
      state: 'Andhra Pradesh', district: 'Alluri Sitharama Raju',
      mandal: 'Chinturu'),
  _r(LocationLevel.village, 'Kesaram',
      state: 'Telangana', district: 'Vikarabad', mandal: 'Mominpet'),
  _r(LocationLevel.village, 'Kesaram',
      state: 'Telangana', district: 'Suryapet', mandal: 'Jajireddygudem'),
  _r(LocationLevel.village, 'Kesaram',
      state: 'Telangana', district: 'Nizamabad', mandal: 'Dharpally'),
];
final _mandal = _r(LocationLevel.subdistrict, 'Jajireddygudem',
    state: 'Telangana', district: 'Suryapet', mandal: 'Jajireddygudem');
final _state = _r(LocationLevel.state, 'Telangana');

void main() {
  group('geocoder candidates are merged', () {
    test('names come from every candidate, suffixes and junk removed', () {
      final place = LocationDetector.placeFromMarks([
        const geo.Placemark(
            name: '7J4M+QX',
            administrativeArea: 'Telangana',
            locality: 'Chittaloor'),
        const geo.Placemark(
            name: 'Kesaram',
            subLocality: 'Kesaram',
            locality: 'Jajireddygudem Mandal',
            subAdministrativeArea: 'Suryapet District',
            administrativeArea: 'Telangana',
            thoroughfare: 'NH 65'),
      ]);
      expect(place.state, 'Telangana');
      expect(place.district, 'Suryapet');
      expect(place.names,
          ['Kesaram', 'Chittaloor', 'Jajireddygudem', 'Suryapet']);
    });
  });

  group('matches are ranked by the detected context', () {
    test("the reader's own Kesaram wins over the other four", () {
      const place = DetectedPlace(
        state: 'Telangana',
        district: 'Suryapet',
        subdistrict: 'Jajireddygudem',
        village: 'Kesaram',
        names: ['Kesaram', 'Jajireddygudem'],
      );
      final ranked = LocationProvider.rankDetectedMatches(
          place, [..._kesaram, _mandal, _state]);
      expect(ranked.first.nameEn, 'Kesaram');
      expect(ranked.first.district, 'Suryapet');
      expect(ranked[1].nameEn, 'Jajireddygudem');
      expect(ranked.where((r) => r.state == 'Andhra Pradesh'), isEmpty);
    });

    test('a misread village name still lands in the right mandal', () {
      // The geocoder named a place the database does not have.
      const place = DetectedPlace(
        state: 'Telangana',
        district: 'Suryapet',
        subdistrict: 'Jajireddygudem',
        village: 'Chittaloor',
        names: ['Chittaloor', 'Jajireddygudem'],
      );
      final ranked =
          LocationProvider.rankDetectedMatches(place, [_mandal, _state]);
      expect(ranked.first.nameEn, 'Jajireddygudem');
    });

    test('without a district, a same-named village elsewhere is not offered',
        () {
      const place = DetectedPlace(
        state: 'Telangana',
        district: '',
        subdistrict: '',
        village: 'Elsewhere',
        names: ['Elsewhere'],
      );
      final ranked = LocationProvider.rankDetectedMatches(
          place, [..._kesaram.skip(2), _state]);
      expect(ranked.single.type, LocationLevel.state);
    });

    test('a state that contradicts the detection is never offered', () {
      const place = DetectedPlace(
        state: 'Andhra Pradesh',
        district: '',
        subdistrict: '',
        village: '',
        names: [],
      );
      expect(LocationProvider.rankDetectedMatches(place, [_state]), isEmpty);
    });
  });
}
