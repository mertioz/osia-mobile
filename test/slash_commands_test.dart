import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osia_mobile/slash_commands.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog loads the exact v1 aliases', () async {
    final catalog = await SlashCommandCatalog.load();
    expect(catalog.entries.map((entry) => entry.alias), [
      'web',
      'model',
      'reasoning',
      'conversation',
      'tools',
      'status',
      'help',
    ]);
  });

  test('palette grammar is initial-only and preserves literal slash text', () {
    expect(slashPaletteQuery('/'), '');
    expect(slashPaletteQuery('  /web'), 'web');
    expect(slashPaletteQuery('//web'), isNull);
    expect(slashPaletteQuery('https://osia.space'), isNull);
    expect(slashPaletteQuery('hello /web'), isNull);
    expect(slashPaletteQuery('/UPPER'), isNull);
    expect(slashPaletteQuery('/1'), isNull);
    expect(slashEscapedLiteralText('  //web'), '  /web');
    expect(
      consumeSlashAlias('  /web /linear find it', 'web'),
      '  /linear find it',
    );
    expect(
      consumeSlashPalettePrefix('  /we /linear find it'),
      '  /linear find it',
    );
  });

  test('typed metadata is strict, bounded, and stable across replay', () {
    final directives = SlashTurnDirectivesV1(
      connectorHints: const [SlashConnectorHint('linear')],
      capabilityRequirements: const SlashCapabilityRequirements(
        currentWeb: true,
      ),
      conversationRefs: const [
        SlashConversationRef(
          conversationId: 'conv-1',
          displayTitle: 'Title',
          displayProject: 'Project',
        ),
      ],
      modelOverride: const SlashModelOverride(
        providerId: 'openai',
        modelId: 'gpt-5.4',
      ),
    );
    directives.validateBounds();
    final replayed = SlashTurnDirectivesV1.fromJson(
      jsonDecode(jsonEncode(directives.toJson())),
    );
    expect(replayed.toJson(), directives.toJson());
    expect(
      directives.canonicalJson(),
      '{"capability_requirements":{"current_web":true},'
      '"connector_hints":[{"connector_id":"linear"}],'
      '"conversation_refs":[{"conversation_id":"conv-1",'
      '"display_project":"Project","display_title":"Title"}],'
      '"model_override":{"model_id":"gpt-5.4",'
      '"provider_id":"openai"},"schema_version":1}',
    );
    expect(
      () => SlashTurnDirectivesV1.fromJson({
        ...directives.toJson(),
        'commands': ['/web'],
      }),
      throwsA(
        isA<SlashDirectiveException>().having(
          (error) => error.code,
          'code',
          'unknown_directive_metadata',
        ),
      ),
    );
  });

  test('fifth modifier and empty modifier-only send fail closed', () {
    final fifth = SlashTurnDirectivesV1(
      connectorHints: const [SlashConnectorHint('linear')],
      capabilityRequirements: const SlashCapabilityRequirements(
        currentWeb: true,
      ),
      conversationRefs: const [SlashConversationRef(conversationId: 'conv-1')],
      modelOverride: const SlashModelOverride(
        providerId: 'openai',
        modelId: 'gpt',
      ),
      reasoningOverride: 'high',
    );
    expect(fifth.validateBounds, throwsA(isA<SlashDirectiveException>()));
    const modifier = SlashTurnDirectivesV1(
      connectorHints: [SlashConnectorHint('linear')],
    );
    expect(
      () => modifier.validateForSend(body: '', hasAttachment: false),
      throwsA(isA<SlashDirectiveException>()),
    );
    modifier.validateForSend(body: '', hasAttachment: true);
  });

  test('directive maps are deeply immutable and availability is bounded', () {
    final original = <String, dynamic>{
      'schema_version': 1,
      'connector_hints': <dynamic>[],
      'capability_requirements': <String, dynamic>{'current_web': true},
      'conversation_refs': <dynamic>[],
    };
    final frozen = freezeSlashDirectiveMap(original);
    original['capability_requirements']['current_web'] = false;
    expect(frozen['capability_requirements']['current_web'], isTrue);
    expect(
      () => frozen['capability_requirements']['current_web'] = false,
      throwsUnsupportedError,
    );

    final overlay = parseSlashAvailabilityOverlay({
      'schema_version': 1,
      'current_web_available': true,
      'capability_families': ['web_search'],
      'connectors': [
        for (var index = 0; index < 30; index++)
          {
            'connector_id': 'connector-$index',
            'alias': 'connector-$index',
            'display_name': 'Connector $index',
            'family': 'Connector',
            'state': 'connected',
            'usable': true,
          },
      ],
    });
    expect((overlay['connectors'] as List), hasLength(slashMaxResults));
    expect(
      parseSlashAvailabilityOverlay({
        'schema_version': 1,
        'current_web_available': true,
        'connectors': const [],
        'endpoint': 'https://secret.invalid',
      }),
      isEmpty,
    );
  });

  test(
    'availability hides unavailable static commands and caps categories',
    () async {
      final catalog = await SlashCommandCatalog.load();
      final results = buildSlashPaletteResults(
        catalog: catalog,
        locale: 'fr',
        currentWebAvailable: false,
        models: const [],
        conversations: const [],
        connectors: const [
          SlashConnectorChoice(
            connectorId: 'linear',
            alias: 'linear',
            displayName: 'Linear',
            family: 'Connector',
            state: 'failed',
            usable: false,
          ),
        ],
      );
      expect(results.any((item) => item.alias == 'web'), isFalse);
      expect(results.any((item) => item.alias == 'model'), isFalse);
      expect(
        results.singleWhere((item) => item.alias == 'linear').enabled,
        isFalse,
      );
      expect(results.length, lessThanOrEqualTo(slashMaxResults));
    },
  );

  test(
    'connector and conversation title collision remain category-distinct',
    () async {
      final catalog = await SlashCommandCatalog.load();
      final results = buildSlashPaletteResults(
        catalog: catalog,
        locale: 'en',
        filter: 'linear',
        connectors: const [
          SlashConnectorChoice(
            connectorId: 'linear',
            alias: 'linear',
            displayName: 'Linear',
            family: 'Connector',
            state: 'connected',
            usable: true,
          ),
        ],
        conversations: const [
          SlashConversationChoice(
            conversationId: 'conv-linear',
            displayTitle: 'Linear',
            displayProject: 'Delivery',
          ),
        ],
      );
      expect(results.map((item) => item.type).toSet(), {
        SlashPaletteSelectionType.connector,
        SlashPaletteSelectionType.conversation,
      });
    },
  );
}
