import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

const int slashSchemaVersion = 1;
const int slashMaxWireBytes = 4096;
const int slashMaxModifiers = 4;
const int slashMaxFilterChars = 96;
const int slashMaxResults = 24;
const int slashMaxResultsPerCategory = 8;
const int slashMaxTitleChars = 120;
const int slashMaxProjectChars = 80;
const Set<String> slashReasoningLevels = {
  'auto',
  'off',
  'low',
  'medium',
  'high',
};
final RegExp slashAliasPattern = RegExp(r'^[a-z][a-z0-9-]{0,31}$');
final RegExp _partialAliasPattern = RegExp(r'^(?:[a-z][a-z0-9-]{0,31})?$');

Object? _deepFreezeSlashValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map(
        (key, nested) =>
            MapEntry(key.toString(), _deepFreezeSlashValue(nested)),
      ),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_deepFreezeSlashValue));
  }
  return value;
}

Map<String, dynamic> freezeSlashDirectiveMap(Map<String, dynamic> raw) {
  final canonical = SlashTurnDirectivesV1.fromJson(raw).toJson();
  return _deepFreezeSlashValue(canonical)! as Map<String, dynamic>;
}

Map<String, dynamic> parseSlashAvailabilityOverlay(Object? raw) {
  if (raw is! Map) return const {};
  try {
    final value = raw.cast<String, dynamic>();
    _exactKeys(value, {
      'schema_version',
      'current_web_available',
      'capability_families',
      'connectors',
    }, 'slash_commands');
    if (value['schema_version'] != slashSchemaVersion ||
        value['current_web_available'] is! bool) {
      return const {};
    }
    final rawFamilies = value['capability_families'] ?? const [];
    final rawConnectors = value['connectors'] ?? const [];
    if (rawFamilies is! List || rawConnectors is! List) return const {};
    final families = rawFamilies
        .take(slashMaxResults)
        .map((item) {
          final family = _boundedText(item, 'capability_family', 32);
          if (!RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(family)) {
            throw const SlashDirectiveException(
              'invalid_availability_overlay',
              'Invalid capability family.',
              'Famille de capacitÃ© invalide.',
            );
          }
          return family;
        })
        .toList(growable: false);
    final connectors = rawConnectors
        .take(slashMaxResults)
        .map((item) {
          final connector = _object(item, 'slash_commands.connectors[]');
          _exactKeys(connector, {
            'connector_id',
            'alias',
            'display_name',
            'family',
            'state',
            'usable',
          }, 'slash_commands.connectors[]');
          final alias = _boundedText(connector['alias'], 'alias', 32);
          final usable = connector['usable'];
          if (!slashAliasPattern.hasMatch(alias) || usable is! bool) {
            throw const SlashDirectiveException(
              'invalid_availability_overlay',
              'Invalid connector availability.',
              'DisponibilitÃ© de connecteur invalide.',
            );
          }
          return <String, dynamic>{
            'connector_id': _boundedText(
              connector['connector_id'],
              'connector_id',
              64,
            ),
            'alias': alias,
            'display_name': _boundedText(
              connector['display_name'],
              'display_name',
              80,
            ),
            'family': _boundedText(connector['family'], 'family', 32),
            'state': _boundedText(connector['state'], 'state', 32),
            'usable': usable,
          };
        })
        .toList(growable: false);
    return _deepFreezeSlashValue(<String, dynamic>{
          'schema_version': slashSchemaVersion,
          'current_web_available': value['current_web_available'],
          'capability_families': families,
          'connectors': connectors,
        })!
        as Map<String, dynamic>;
  } on Object {
    return const {};
  }
}

class SlashDirectiveException implements Exception {
  final String code;
  final String english;
  final String french;

  const SlashDirectiveException(this.code, this.english, this.french);

  String message(String locale) =>
      locale.toLowerCase().startsWith('fr') ? french : english;

  @override
  String toString() => '$code: $english';
}

void _exactKeys(Map<String, dynamic> value, Set<String> allowed, String field) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw SlashDirectiveException(
      'unknown_directive_metadata',
      'Unknown typed metadata in $field.',
      'Métadonnée typée inconnue dans $field.',
    );
  }
}

String _boundedText(
  Object? raw,
  String field,
  int maximum, {
  bool required = true,
}) {
  if (raw is! String) {
    throw SlashDirectiveException(
      'invalid_directives',
      '$field must be text.',
      '$field doit être du texte.',
    );
  }
  final value = raw.trim();
  if ((required && value.isEmpty) ||
      value.length > maximum ||
      value.runes.any((rune) => rune < 32)) {
    throw SlashDirectiveException(
      'invalid_directives',
      'Invalid $field.',
      '$field invalide.',
    );
  }
  return value;
}

Map<String, dynamic> _object(Object? raw, String field) {
  if (raw is! Map) {
    throw SlashDirectiveException(
      'invalid_directives',
      '$field must be an object.',
      '$field doit être un objet.',
    );
  }
  return raw.cast<String, dynamic>();
}

class SlashConnectorHint {
  final String connectorId;

  const SlashConnectorHint(this.connectorId);

  factory SlashConnectorHint.fromJson(Object? raw) {
    final json = _object(raw, 'connector_hints[]');
    _exactKeys(json, {'connector_id'}, 'connector_hints[]');
    return SlashConnectorHint(
      _boundedText(json['connector_id'], 'connector_id', 64),
    );
  }

  Map<String, dynamic> toJson() => {'connector_id': connectorId};
}

class SlashCapabilityRequirements {
  final bool currentWeb;

  const SlashCapabilityRequirements({this.currentWeb = false});

  factory SlashCapabilityRequirements.fromJson(Object? raw) {
    final json = _object(raw, 'capability_requirements');
    _exactKeys(json, {'current_web'}, 'capability_requirements');
    final currentWeb = json['current_web'] ?? false;
    if (currentWeb is! bool) {
      throw const SlashDirectiveException(
        'invalid_directives',
        'current_web must be boolean.',
        'current_web doit être booléen.',
      );
    }
    return SlashCapabilityRequirements(currentWeb: currentWeb);
  }

  Map<String, dynamic> toJson() => {'current_web': currentWeb};
}

class SlashConversationRef {
  final String conversationId;
  final String displayTitle;
  final String displayProject;

  const SlashConversationRef({
    required this.conversationId,
    this.displayTitle = '',
    this.displayProject = '',
  });

  factory SlashConversationRef.fromJson(Object? raw) {
    final json = _object(raw, 'conversation_refs[]');
    _exactKeys(json, {
      'conversation_id',
      'display_title',
      'display_project',
    }, 'conversation_refs[]');
    return SlashConversationRef(
      conversationId: _boundedText(
        json['conversation_id'],
        'conversation_id',
        128,
      ),
      displayTitle: _boundedText(
        json['display_title'] ?? '',
        'display_title',
        slashMaxTitleChars,
        required: false,
      ),
      displayProject: _boundedText(
        json['display_project'] ?? '',
        'display_project',
        slashMaxProjectChars,
        required: false,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'display_title': displayTitle,
    'display_project': displayProject,
  };
}

class SlashModelOverride {
  final String providerId;
  final String modelId;

  const SlashModelOverride({required this.providerId, required this.modelId});

  factory SlashModelOverride.fromJson(Object? raw) {
    final json = _object(raw, 'model_override');
    _exactKeys(json, {'provider_id', 'model_id'}, 'model_override');
    return SlashModelOverride(
      providerId: _boundedText(json['provider_id'], 'provider_id', 64),
      modelId: _boundedText(json['model_id'], 'model_id', 192),
    );
  }

  Map<String, dynamic> toJson() => {
    'provider_id': providerId,
    'model_id': modelId,
  };
}

class SlashTurnDirectivesV1 {
  final int schemaVersion;
  final List<SlashConnectorHint> connectorHints;
  final SlashCapabilityRequirements capabilityRequirements;
  final List<SlashConversationRef> conversationRefs;
  final SlashModelOverride? modelOverride;
  final String? reasoningOverride;

  const SlashTurnDirectivesV1({
    this.schemaVersion = slashSchemaVersion,
    this.connectorHints = const [],
    this.capabilityRequirements = const SlashCapabilityRequirements(),
    this.conversationRefs = const [],
    this.modelOverride,
    this.reasoningOverride,
  });

  factory SlashTurnDirectivesV1.fromJson(Object? raw) {
    final json = _object(raw, 'turn_directives');
    _exactKeys(json, {
      'schema_version',
      'connector_hints',
      'capability_requirements',
      'conversation_refs',
      'model_override',
      'reasoning_override',
    }, 'turn_directives');
    if (json['schema_version'] != slashSchemaVersion) {
      throw const SlashDirectiveException(
        'unsupported_directive_schema',
        'Unsupported slash directive schema.',
        'Schéma de directives slash non pris en charge.',
      );
    }
    final rawConnectors = json['connector_hints'] ?? const [];
    final rawConversations = json['conversation_refs'] ?? const [];
    if (rawConnectors is! List || rawConversations is! List) {
      throw const SlashDirectiveException(
        'invalid_directives',
        'Directive collections must be arrays.',
        'Les collections de directives doivent être des tableaux.',
      );
    }
    if (rawConnectors.length > 1 || rawConversations.length > 1) {
      throw const SlashDirectiveException(
        'directive_limit_exceeded',
        'Only one selector of each kind is allowed.',
        'Un seul sélecteur de chaque type est autorisé.',
      );
    }
    final reasoning = json['reasoning_override'];
    if (reasoning != null &&
        (reasoning is! String || !slashReasoningLevels.contains(reasoning))) {
      throw const SlashDirectiveException(
        'unsupported_reasoning',
        'Unsupported reasoning level.',
        'Niveau de raisonnement non pris en charge.',
      );
    }
    final result = SlashTurnDirectivesV1(
      connectorHints: List.unmodifiable(
        rawConnectors.map(SlashConnectorHint.fromJson),
      ),
      capabilityRequirements: SlashCapabilityRequirements.fromJson(
        json['capability_requirements'] ?? const <String, dynamic>{},
      ),
      conversationRefs: List.unmodifiable(
        rawConversations.map(SlashConversationRef.fromJson),
      ),
      modelOverride: json['model_override'] == null
          ? null
          : SlashModelOverride.fromJson(json['model_override']),
      reasoningOverride: reasoning as String?,
    );
    result.validateBounds();
    return result;
  }

  bool get isEmpty =>
      connectorHints.isEmpty &&
      conversationRefs.isEmpty &&
      !capabilityRequirements.currentWeb &&
      modelOverride == null &&
      reasoningOverride == null;

  int get modifierCount =>
      connectorHints.length +
      conversationRefs.length +
      (capabilityRequirements.currentWeb ? 1 : 0) +
      (modelOverride == null ? 0 : 1) +
      (reasoningOverride == null ? 0 : 1);

  Map<String, dynamic> toJson() => {
    'schema_version': slashSchemaVersion,
    'connector_hints': connectorHints.map((item) => item.toJson()).toList(),
    'capability_requirements': capabilityRequirements.toJson(),
    'conversation_refs': conversationRefs.map((item) => item.toJson()).toList(),
    if (modelOverride != null) 'model_override': modelOverride!.toJson(),
    if (reasoningOverride != null) 'reasoning_override': reasoningOverride,
  };

  String canonicalJson() {
    // Match the PC's sorted-key canonical identity for replay diagnostics.
    return jsonEncode({
      'capability_requirements': capabilityRequirements.toJson(),
      'connector_hints': connectorHints.map((item) => item.toJson()).toList(),
      'conversation_refs': conversationRefs
          .map(
            (item) => {
              'conversation_id': item.conversationId,
              'display_project': item.displayProject,
              'display_title': item.displayTitle,
            },
          )
          .toList(),
      if (modelOverride != null)
        'model_override': {
          'model_id': modelOverride!.modelId,
          'provider_id': modelOverride!.providerId,
        },
      if (reasoningOverride != null) 'reasoning_override': reasoningOverride,
      'schema_version': slashSchemaVersion,
    });
  }

  void validateBounds() {
    if (connectorHints.length > 1 ||
        conversationRefs.length > 1 ||
        modifierCount > slashMaxModifiers) {
      throw const SlashDirectiveException(
        'directive_limit_exceeded',
        'At most four slash modifiers are allowed.',
        'Quatre modificateurs slash au maximum sont autorisés.',
      );
    }
    if (utf8.encode(canonicalJson()).length > slashMaxWireBytes) {
      throw const SlashDirectiveException(
        'directives_too_large',
        'Slash directives are too large.',
        'Les directives slash sont trop volumineuses.',
      );
    }
  }

  void validateForSend({required String body, required bool hasAttachment}) {
    validateBounds();
    if (!isEmpty && body.trim().isEmpty && !hasAttachment) {
      throw const SlashDirectiveException(
        'directive_body_required',
        'Add a message or attachment before sending these modifiers.',
        'Ajoutez un message ou une pièce jointe avant d’envoyer ces modificateurs.',
      );
    }
  }

  SlashTurnDirectivesV1 copyWith({
    List<SlashConnectorHint>? connectorHints,
    SlashCapabilityRequirements? capabilityRequirements,
    List<SlashConversationRef>? conversationRefs,
    SlashModelOverride? modelOverride,
    bool clearModelOverride = false,
    String? reasoningOverride,
    bool clearReasoningOverride = false,
  }) {
    final result = SlashTurnDirectivesV1(
      connectorHints: List.unmodifiable(connectorHints ?? this.connectorHints),
      capabilityRequirements:
          capabilityRequirements ?? this.capabilityRequirements,
      conversationRefs: List.unmodifiable(
        conversationRefs ?? this.conversationRefs,
      ),
      modelOverride: clearModelOverride
          ? null
          : (modelOverride ?? this.modelOverride),
      reasoningOverride: clearReasoningOverride
          ? null
          : (reasoningOverride ?? this.reasoningOverride),
    );
    result.validateBounds();
    return result;
  }
}

String? slashPaletteQuery(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('/') || trimmed.startsWith('//')) return null;
  final remainder = trimmed.substring(1);
  final whitespace = remainder.indexOf(RegExp(r'\s'));
  final token = whitespace < 0 ? remainder : remainder.substring(0, whitespace);
  if (token.length > slashMaxFilterChars ||
      !_partialAliasPattern.hasMatch(token)) {
    return null;
  }
  return token;
}

String slashEscapedLiteralText(String text) {
  final leading = text.length - text.trimLeft().length;
  if (text.substring(leading).startsWith('//')) {
    return text.substring(0, leading) + text.substring(leading + 1);
  }
  return text;
}

String consumeSlashAlias(String text, String alias) {
  if (!slashAliasPattern.hasMatch(alias)) return text;
  final leading = text.length - text.trimLeft().length;
  final tail = text.substring(leading);
  if (!tail.startsWith('/') || tail.startsWith('//')) return text;
  final match = RegExp(r'^/([^\s]+)(?:\s+|$)').firstMatch(tail);
  if (match == null || match.group(1) != alias) return text;
  return text.substring(0, leading) + tail.substring(match.end).trimLeft();
}

String consumeSlashPalettePrefix(String text) {
  final query = slashPaletteQuery(text);
  if (query == null) return text;
  final leading = text.length - text.trimLeft().length;
  final tail = text.substring(leading);
  return text.substring(0, leading) +
      tail.substring(1 + query.length).trimLeft();
}

class SlashCatalogEntry {
  final String id;
  final String alias;
  final Map<String, String> name;
  final Map<String, String> description;
  final Map<String, String> argumentHint;
  final String kind;
  final String availabilityPredicate;
  final String iconSemantic;
  final String chipBehavior;
  final String handlerContract;

  const SlashCatalogEntry({
    required this.id,
    required this.alias,
    required this.name,
    required this.description,
    required this.argumentHint,
    required this.kind,
    required this.availabilityPredicate,
    required this.iconSemantic,
    required this.chipBehavior,
    required this.handlerContract,
  });

  factory SlashCatalogEntry.fromJson(Map<String, dynamic> json) {
    Map<String, String> localized(Object? raw) {
      if (raw is! Map) return const {};
      return Map.unmodifiable(
        raw.map((key, value) => MapEntry(key.toString(), value.toString())),
      );
    }

    final alias = (json['canonical_alias'] ?? '').toString();
    if (!slashAliasPattern.hasMatch(alias)) {
      throw const FormatException('Invalid slash alias');
    }
    return SlashCatalogEntry(
      id: (json['id'] ?? '').toString(),
      alias: alias,
      name: localized(json['name']),
      description: localized(json['description']),
      argumentHint: localized(json['argument_hint']),
      kind: (json['kind'] ?? '').toString(),
      availabilityPredicate: (json['availability_predicate'] ?? '').toString(),
      iconSemantic: (json['icon_semantic'] ?? '').toString(),
      chipBehavior: (json['chip_behavior'] ?? '').toString(),
      handlerContract: (json['handler_contract'] ?? '').toString(),
    );
  }

  String localizedName(String locale) =>
      name[locale.startsWith('fr') ? 'fr' : 'en'] ?? name['en'] ?? '';

  String localizedDescription(String locale) =>
      description[locale.startsWith('fr') ? 'fr' : 'en'] ??
      description['en'] ??
      '';
}

class SlashCommandCatalog {
  final List<SlashCatalogEntry> entries;

  const SlashCommandCatalog(this.entries);

  static Future<SlashCommandCatalog> load() async {
    final text = await rootBundle.loadString(
      'assets/slash_commands/catalog.v1.json',
    );
    final raw = jsonDecode(text);
    if (raw is! Map || raw['schema_version'] != slashSchemaVersion) {
      throw const FormatException('Invalid slash catalog schema');
    }
    final values = raw['entries'];
    if (values is! List) throw const FormatException('Invalid slash entries');
    final entries = values
        .whereType<Map>()
        .map(
          (value) => SlashCatalogEntry.fromJson(value.cast<String, dynamic>()),
        )
        .toList(growable: false);
    if (entries.map((item) => item.id).toSet().length != entries.length ||
        entries.map((item) => item.alias).toSet().length != entries.length) {
      throw const FormatException('Duplicate slash catalog identity');
    }
    return SlashCommandCatalog(List.unmodifiable(entries));
  }
}

class SlashConnectorChoice {
  final String connectorId;
  final String alias;
  final String displayName;
  final String family;
  final String state;
  final bool usable;

  const SlashConnectorChoice({
    required this.connectorId,
    required this.alias,
    required this.displayName,
    required this.family,
    required this.state,
    required this.usable,
  });
}

class SlashModelChoice {
  final String providerId;
  final String modelId;
  final String displayName;
  final List<String> reasoningOptions;
  final bool acceptsImages;

  const SlashModelChoice({
    required this.providerId,
    required this.modelId,
    required this.displayName,
    this.reasoningOptions = const [],
    this.acceptsImages = false,
  });
}

class SlashConversationChoice {
  final String conversationId;
  final String displayTitle;
  final String displayProject;

  const SlashConversationChoice({
    required this.conversationId,
    required this.displayTitle,
    this.displayProject = '',
  });
}

enum SlashPaletteSelectionType {
  command,
  connector,
  model,
  reasoning,
  conversation,
}

class SlashPaletteSelection {
  final SlashPaletteSelectionType type;
  final String id;
  final String alias;
  final String title;
  final String description;
  final String argumentHint;
  final bool enabled;
  final Object? value;
  final String handlerContract;

  const SlashPaletteSelection({
    required this.type,
    required this.id,
    this.alias = '',
    required this.title,
    this.description = '',
    this.argumentHint = '',
    this.enabled = true,
    this.value,
    this.handlerContract = '',
  });
}

List<SlashPaletteSelection> buildSlashPaletteResults({
  required SlashCommandCatalog catalog,
  required String locale,
  String filter = '',
  bool currentWebAvailable = false,
  String activeProviderId = '',
  String activeModelId = '',
  List<SlashConnectorChoice> connectors = const [],
  List<SlashModelChoice> models = const [],
  List<SlashConversationChoice> conversations = const [],
}) {
  final boundedFilter = filter.length <= slashMaxFilterChars
      ? filter
      : filter.substring(0, slashMaxFilterChars);
  final query = boundedFilter.trim().toLowerCase();
  final rows = <SlashPaletteSelection>[];
  for (final item in catalog.entries) {
    final available = switch (item.availabilityPredicate) {
      'current_web_available' => currentWebAvailable,
      'selectable_models_present' => models.isNotEmpty,
      'other_conversations_present' => conversations.isNotEmpty,
      'reasoning_options_present' => models.any(
        (model) =>
            model.providerId == activeProviderId &&
            model.modelId == activeModelId &&
            model.reasoningOptions.isNotEmpty,
      ),
      _ => true,
    };
    if (!available) continue;
    rows.add(
      SlashPaletteSelection(
        type: SlashPaletteSelectionType.command,
        id: item.id,
        alias: item.alias,
        title: item.localizedName(locale),
        description: item.localizedDescription(locale),
        argumentHint:
            item.argumentHint[locale.startsWith('fr') ? 'fr' : 'en'] ??
            item.argumentHint['en'] ??
            '',
        handlerContract: item.handlerContract,
      ),
    );
  }
  rows.addAll(
    connectors.map(
      (item) => SlashPaletteSelection(
        type: SlashPaletteSelectionType.connector,
        id: 'connector.${item.connectorId}',
        alias: item.alias,
        title: item.displayName,
        description: item.usable
            ? (locale.startsWith('fr') ? 'Disponible' : 'Available')
            : '${locale.startsWith('fr') ? 'Indisponible' : 'Unavailable'} · '
                  '${_connectorStateLabel(item.state, locale)}',
        enabled: item.usable,
        value: item,
        handlerContract: 'select_connector_hint_v1',
      ),
    ),
  );
  rows.addAll(
    conversations.map(
      (item) => SlashPaletteSelection(
        type: SlashPaletteSelectionType.conversation,
        id: 'conversation.${item.conversationId}',
        alias: 'conversation',
        title: item.displayTitle.isEmpty
            ? (locale.startsWith('fr') ? 'Sans titre' : 'Untitled')
            : item.displayTitle,
        description: item.displayProject,
        value: item,
        handlerContract: 'select_conversation_reference_v1',
      ),
    ),
  );
  final filtered = query.isEmpty
      ? rows
      : rows
            .where(
              (item) =>
                  item.alias.toLowerCase().contains(query) ||
                  item.title.toLowerCase().contains(query) ||
                  item.description.toLowerCase().contains(query),
            )
            .toList();
  final counts = <SlashPaletteSelectionType, int>{};
  final bounded = <SlashPaletteSelection>[];
  for (final item in filtered) {
    final count = counts[item.type] ?? 0;
    if (count >= slashMaxResultsPerCategory) continue;
    counts[item.type] = count + 1;
    bounded.add(item);
    if (bounded.length >= slashMaxResults) break;
  }
  return List.unmodifiable(bounded);
}

String _connectorStateLabel(String state, String locale) {
  if (!locale.startsWith('fr')) return state;
  return switch (state) {
    'disconnected' => 'déconnecté',
    'failed' => 'échec',
    'authorization_required' => 'autorisation requise',
    'configuration_missing' => 'configuration manquante',
    'offline' => 'hors ligne',
    _ => 'indisponible',
  };
}
