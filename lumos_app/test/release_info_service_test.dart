import 'package:flutter_test/flutter_test.dart';
import 'package:lumos_app/services/release_info_service.dart';

void main() {
  test('compares date-style release tags', () {
    expect(
      ReleaseInfoService.isRemoteNewer(
        localVersion: 'v2026.02.27-0100-beta',
        remoteVersion: 'v2026.02.27-0152-beta',
      ),
      isTrue,
    );
  });

  test('compares semver tags', () {
    expect(
      ReleaseInfoService.isRemoteNewer(
        localVersion: 'v1.2.3',
        remoteVersion: 'v1.3.0',
      ),
      isTrue,
    );
  });

  test('matches version ranges with whitespace comparators', () {
    expect(
      ReleaseInfoService.isVersionInComparatorRange(
        version: '1.0.0',
        range: '>=1.0.0 <2.0.0',
      ),
      isTrue,
    );
  });

  test('matches version ranges with comma comparators', () {
    expect(
      ReleaseInfoService.isVersionInComparatorRange(
        version: 'v1.0.0+1',
        range: '>=1.0.0,<2.0.0',
      ),
      isTrue,
    );
  });

  test('rejects versions outside comparator range', () {
    expect(
      ReleaseInfoService.isVersionInComparatorRange(
        version: '2.0.0',
        range: '>=1.0.0,<2.0.0',
      ),
      isFalse,
    );
  });
}


