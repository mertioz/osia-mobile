import 'services/websocket_service.dart' as ws;

const int permissionContractSchemaVersion = 1;

bool _hasExactKeys(Map<Object?, Object?> value, Set<String> keys) =>
    value.length == keys.length && value.keys.every(keys.contains);

bool _safeContractToken(Object? value) =>
    value is String && RegExp(r'^[a-z][a-z0-9_.]{0,95}$').hasMatch(value);

class PermissionCategoryContract {
  const PermissionCategoryContract({
    required this.id,
    required this.labelKey,
    required this.descriptionKey,
    required this.delegationRule,
    required this.mobileRequestAllowed,
  });

  final String id;
  final String labelKey;
  final String descriptionKey;
  final String delegationRule;
  final bool mobileRequestAllowed;
}

class PermissionContract {
  const PermissionContract({required this.categories});

  final List<PermissionCategoryContract> categories;

  static PermissionContract? tryParse(Object? raw) {
    const topKeys = <String>{
      'schema_version',
      'custom_access',
      'full_access_activation',
      'mobile_changes',
      'categories',
    };
    if (raw is! Map ||
        !_hasExactKeys(raw, topKeys) ||
        raw['schema_version'] != permissionContractSchemaVersion ||
        raw['custom_access'] != 'derived' ||
        raw['full_access_activation'] != 'local_pc_ceremony' ||
        raw['mobile_changes'] != 'canonical_requests') {
      return null;
    }
    final rawCategories = raw['categories'];
    if (rawCategories is! List ||
        rawCategories.isEmpty ||
        rawCategories.length > 32) {
      return null;
    }
    const categoryKeys = <String>{
      'id',
      'label_key',
      'description_key',
      'delegation_rule',
      'mobile_request_allowed',
    };
    const delegationRules = <String>{
      'ordinary_actions_only',
      'ordinary_actions_with_pc_limits',
      'explicit_scoped_or_ordinary_actions',
    };
    final categories = <PermissionCategoryContract>[];
    final identifiers = <String>{};
    for (final item in rawCategories) {
      if (item is! Map || !_hasExactKeys(item, categoryKeys)) return null;
      final id = item['id'];
      final labelKey = item['label_key'];
      final descriptionKey = item['description_key'];
      final delegationRule = item['delegation_rule'];
      if (!_safeContractToken(id) ||
          !_safeContractToken(labelKey) ||
          !_safeContractToken(descriptionKey) ||
          labelKey != 'permissions.category.$id' ||
          descriptionKey != 'permissions.switch.$id' ||
          delegationRule is! String ||
          !delegationRules.contains(delegationRule) ||
          item['mobile_request_allowed'] is! bool ||
          !identifiers.add(id as String)) {
        return null;
      }
      categories.add(
        PermissionCategoryContract(
          id: id,
          labelKey: labelKey as String,
          descriptionKey: descriptionKey as String,
          delegationRule: delegationRule,
          mobileRequestAllowed: item['mobile_request_allowed'] as bool,
        ),
      );
    }
    return PermissionContract(
      categories: List<PermissionCategoryContract>.unmodifiable(categories),
    );
  }

  bool matchesSnapshot(ws.PermissionSnapshot? snapshot) {
    if (snapshot == null) return false;
    final identifiers = categories.map((item) => item.id).toSet();
    return identifiers.length == categories.length &&
        identifiers.length == snapshot.categories.length &&
        snapshot.categories.keys.every(identifiers.contains);
  }
}
