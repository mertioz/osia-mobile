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
      'status',
      'help',
      'vision',
      'skill',
      'skillcreator',
    ]);
  });

  test(
    'extended commands appear with a compatible PC and keep their typed intent',
    () async {
      final catalog = await SlashCommandCatalog.load();
      final legacy = buildSlashPaletteResults(catalog: catalog, locale: 'en');
      expect(
        legacy.map((item) => item.alias),
        isNot(contains('vision')),
      );

      final current = buildSlashPaletteResults(
        catalog: catalog,
        locale: 'fr',
        chatSlashExtensionsAvailable: true,
        currentWebAvailable: true,
        specialMode: true,
        modelsAvailable: true,
      );
      expect(
        current.where((item) => item.type == SlashPaletteSelectionType.command),
        hasLength(7),
      );
      expect(
        current.firstWhere((item) => item.alias == 'vision').description,
        startsWith('Réactiver'),
      );

      final create = SlashTurnDirectivesV1.fromJson({
        'schema_version': 1,
        'skill_creator': true,
      });
      expect(create.toJson()['skill_creator'], true);
      expect(
        () => create.validateForSend(body: '', hasAttachment: true),
        throwsA(isA<SlashDirectiveException>()),
      );
      final use = create.copyWith(skillName: 'brief.md', skillCreator: false);
      expect(use.toJson()['skill_name'], 'brief.md');
      expect(use.toJson().containsKey('skill_creator'), isFalse);
      expect(
        () => SlashTurnDirectivesV1.fromJson({
          'schema_version': 1,
          'skill_name': '../other.md',
        }),
        throwsA(isA<SlashDirectiveException>()),
      );
    },
  );

  test('palette grammar is initial-only and preserves literal slash text', () {
    expect(slashPaletteQuery('/'), '');
    expect(slashPaletteQuery('/ '), '');
    expect(slashPaletteQuery('/ vision'), 'vision');
    expect(slashPaletteQuery('  /web'), 'web');
    expect(slashPaletteQuery('//web'), isNull);
    expect(slashPaletteQuery('https://osia.space'), isNull);
    expect(slashPaletteQuery('hello /web'), isNull);
    expect(slashPaletteQuery('/UPPER'), isNull);
    expect(slashPaletteQuery('/1'), isNull);
    expect(
      consumeSlashPalettePrefix('/ skillcreator a new brief'),
      'a new brief',
    );
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
      skillCreator: true,
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
    'slash filters keep connectors separate from conversation mentions',
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
      );
      expect(results.single.type, SlashPaletteSelectionType.connector);
      const prefix = 'Compare 🙂 @Linear';
      const draft = '$prefix puis résume.';
      final mention = conversationMention(draft, prefix.length)!;
      expect(mention.query, 'Linear');
      expect(
        draft.replaceRange(mention.start, mention.end, ''),
        'Compare 🙂  puis résume.',
      );
      expect(conversationMention('name@example.com', 16), isNull);
      expect(conversationMention('@@literal', 9), isNull);
    },
  );

  test('exact model and advanced effort share one typed slot', () {
    for (final level in ['xhigh', 'max', 'ultra']) {
      final selection = SlashTurnDirectivesV1.fromJson({
        'schema_version': 1,
        'model_override': {
          'provider_id': 'chatgpt_account',
          'model_id': 'gpt-6.1-sol',
        },
        'reasoning_override': level,
      });
      expect(selection.modifierCount, 1);
      expect(selection.toJson()['reasoning_override'], level);
    }
  });
}
