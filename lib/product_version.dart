/// Product history presentation only. Technical package/build identities remain
/// unchanged in diagnostics and immutable artifacts.
const productVersion = '0.9.51';
const historicalMobileVersions = <String, String>{
  '1.0.0+1': '0.8.0',
  '1.0.1+2': '0.8.1',
  '1.0.1+3': '0.8.2',
  '1.0.2+3': '0.8.3',
  '1.1.0+4': '0.8.4',
  '1.1.1+5': '0.8.5',
  '1.1.1+14': '0.8.6',
  '1.1.2+15': '0.8.7',
  '1.1.2+16': '0.8.8',
  '1.1.2+17': '0.8.9',
  '1.1.2+18': '0.8.10',
};

String displayMobileVersion(String technicalIdentity) =>
    historicalMobileVersions[technicalIdentity] ?? technicalIdentity;
