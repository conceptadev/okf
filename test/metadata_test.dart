import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  group('core metadata', () {
    test('reads core fields and retains extensions', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'type': 'Reference',
        'title': 'Policy',
        'description': 'The canonical policy.',
        'resource': 'https://example.com/policy',
        'tags': <Object?>['governance', 2026],
        'x-owner': 'finance',
        'x-settings': <String, Object?>{'visible': true},
      });

      expect(metadata.type, 'Reference');
      expect(metadata.title, 'Policy');
      expect(metadata.description, 'The canonical policy.');
      expect(metadata.resource, 'https://example.com/policy');
      expect(metadata.tags, <String>['governance', '2026']);
      expect(metadata.extensionKeys, <String>['x-owner', 'x-settings']);
      expect(metadata.raw['x-settings'], <String, Object?>{'visible': true});
    });

    test('coerces a scalar type for permissive consumption', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'type': 42,
      });

      expect(metadata.type, '42');
    });
  });

  group('trust', () {
    test('normalizes a bare verified mapping', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'verified': <String, Object?>{
          'by': 'human:ana',
          'at': '2026-07-20T09:00:00Z',
        },
      });

      expect(metadata.verified, hasLength(1));
      expect(metadata.verified.single.by, 'human:ana');
      expect(metadata.trustTier, OkfTrustTier.humanReviewed);
      expect(metadata.trustTier.wireValue, 'human-reviewed');
    });

    test(
      'derives all three trust tiers and ignores malformed list entries',
      () {
        expect(
          OkfMetadata.fromFrontmatter(const <String, Object?>{}).trustTier,
          OkfTrustTier.unverified,
        );
        expect(
          OkfMetadata.fromFrontmatter(<String, Object?>{
            'verified': <Object?>[
              'malformed',
              <String, Object?>{
                'by': 'process:nightly',
                'at': '2026-07-20T09:00:00Z',
              },
            ],
          }).trustTier,
          OkfTrustTier.machineConfirmed,
        );
        expect(
          OkfMetadata.fromFrontmatter(<String, Object?>{
            'verified': <Object?>[
              <String, Object?>{
                'by': 'team:data-platform',
                'at': '2026-07-20T09:00:00Z',
              },
              <String, Object?>{
                'by': 'human:reviewer',
                'at': '2026-07-21T09:00:00Z',
              },
            ],
          }).trustTier,
          OkfTrustTier.humanReviewed,
        );
      },
    );

    test('does not raise trust for structurally unusable events', () {
      for (final verified in <Object?>[
        <String, Object?>{},
        <String, Object?>{'by': 'process:nightly'},
        <String, Object?>{'by': 'human:', 'at': '2026-07-20T09:00:00Z'},
        <String, Object?>{'by': 'human:reviewer', 'at': 'not-a-date'},
      ]) {
        expect(
          OkfMetadata.fromFrontmatter(<String, Object?>{
            'verified': verified,
          }).trustTier,
          OkfTrustTier.unverified,
          reason: '$verified',
        );
      }
    });

    test('finds the latest parseable verification', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'verified': <Object?>[
          <String, Object?>{'by': 'process:bad-time', 'at': 'later'},
          <String, Object?>{
            'by': 'process:first',
            'at': '2026-07-20T09:00:00Z',
          },
          <String, Object?>{'by': 'human:last', 'at': '2026-07-21T09:00:00Z'},
        ],
      });

      expect(metadata.latestVerification?.by, 'human:last');
    });
  });

  group('lifecycle', () {
    test('defaults status to stable and preserves unknown status', () {
      expect(
        OkfMetadata.fromFrontmatter(const <String, Object?>{}).status,
        OkfLifecycleStatus.stable,
      );

      final unknown = OkfMetadata.fromFrontmatter(<String, Object?>{
        'status': 'archived',
      });
      expect(unknown.status, OkfLifecycleStatus.unknown);
      expect(unknown.rawStatus, 'archived');
    });

    test('becomes stale at the boundary instant', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'stale_after': '2026-09-23T12:00:00+02:00',
      });

      expect(metadata.staleAfter, DateTime.utc(2026, 9, 23, 10));
      expect(metadata.isStale(DateTime.utc(2026, 9, 23, 9, 59)), isFalse);
      expect(metadata.isStale(DateTime.utc(2026, 9, 23, 10)), isTrue);
      expect(metadata.isStale(DateTime.utc(2026, 9, 24)), isTrue);
    });

    test('reads a date-only stale_after as midnight UTC', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'stale_after': '2026-09-23',
      });

      expect(metadata.staleAfter, DateTime.utc(2026, 9, 23));
      expect(metadata.isStale(DateTime.utc(2026, 9, 22, 23, 59)), isFalse);
      expect(metadata.isStale(DateTime.utc(2026, 9, 23)), isTrue);
    });

    test('treats an invalid date as not stale', () {
      final invalidText = OkfMetadata.fromFrontmatter(<String, Object?>{
        'stale_after': 'not-a-date',
      });
      final invalidCalendar = OkfMetadata.fromFrontmatter(<String, Object?>{
        'stale_after': '2026-02-31',
      });

      expect(invalidText.isStale(DateTime(2030)), isFalse);
      expect(invalidCalendar.isStale(DateTime(2030)), isFalse);
    });
  });

  group('generation and v0.1 fallback', () {
    test('uses generated.at when generated is present', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'generated': <String, Object?>{
          'by': 'reference_agent/gemini',
          'at': '2026-07-21T12:30:00Z',
        },
        'timestamp': '2020-01-01T00:00:00Z',
      });

      expect(metadata.generated?.by, 'reference_agent/gemini');
      expect(metadata.contentChangedAt, DateTime.parse('2026-07-21T12:30:00Z'));
      expect(metadata.legacyTimestamp, '2020-01-01T00:00:00Z');
    });

    test('falls back only when generated is absent', () {
      final legacy = OkfMetadata.fromFrontmatter(<String, Object?>{
        'timestamp': '2026-07-19T08:00:00Z',
      });
      final generatedWithoutAt = OkfMetadata.fromFrontmatter(<String, Object?>{
        'generated': <String, Object?>{'by': 'process:writer'},
        'timestamp': '2026-07-19T08:00:00Z',
      });

      expect(legacy.contentChangedAt, DateTime.parse('2026-07-19T08:00:00Z'));
      expect(generatedWithoutAt.contentChangedAt, isNull);
    });
  });

  group('provenance', () {
    test('reads source signals and usage-window override', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'usage_window': <String, Object?>{
          'from': '2026-06-01',
          'to': '2026-06-30',
        },
        'sources': <Object?>[
          <String, Object?>{
            'id': 'policy',
            'resource': 'https://example.com/policy',
            'title': 'Finance policy',
            'author': 'team:finance',
            'usage_count': 5000,
            'last_modified': '2026-05-30',
          },
          <String, Object?>{
            'resource': '../references/dashboard.md',
            'usage_count': '12',
            'usage_window': <String, Object?>{
              'from': '2026-07-01',
              'to': '2026-07-07',
            },
            'extension': true,
          },
          'malformed',
        ],
      });

      expect(metadata.sources, hasLength(2));
      final policy = metadata.sources.first;
      expect(policy.id, 'policy');
      expect(policy.author, 'team:finance');
      expect(policy.usageCount, 5000);
      expect(policy.lastModified, DateTime.utc(2026, 5, 30));
      expect(
        policy.effectiveUsageWindow(metadata.usageWindow)?.from,
        DateTime.utc(2026, 6, 1),
      );

      final dashboard = metadata.sources.last;
      expect(dashboard.usageCount, 12);
      expect(
        dashboard.effectiveUsageWindow(metadata.usageWindow)?.from,
        DateTime.utc(2026, 7, 1),
      );
      expect(dashboard.raw['extension'], isTrue);
    });
  });

  group('Attested Computation', () {
    test('provides a typed contract without executing anything', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'type': 'Attested Computation',
        'runtime': 'bigquery',
        'parameters': <Object?>[
          <String, Object?>{
            'name': 'year',
            'type': 'integer',
            'required': true,
          },
          <String, Object?>{
            'name': 'region',
            'type': 'string',
            'required': false,
            'extension': 'kept',
          },
        ],
        'computation': 'references/revenue.sql',
        'executor': <String, Object?>{
          'resource': 'references/run.md',
          'receipt': <Object?>['job_id', 'executed_sql', 'result'],
        },
        'attester': <String, Object?>{
          'resource': 'references/attest.py',
          'language': 'python',
        },
      });

      expect(metadata.isAttestedComputation, isTrue);
      final contract = metadata.computationContract;
      expect(contract, isNotNull);
      expect(contract?.runtime, 'bigquery');
      expect(contract?.parameters, hasLength(2));
      expect(contract?.parameters.first.name, 'year');
      expect(contract?.parameters.first.required, isTrue);
      expect(contract?.computation, 'references/revenue.sql');
      expect(contract?.executor?.receipt, <String>[
        'job_id',
        'executed_sql',
        'result',
      ]);
      expect(contract?.attester?.resource, 'references/attest.py');
      expect(contract?.attester?.raw['language'], 'python');
    });

    test('does not reinterpret similarly named fields on another type', () {
      final metadata = OkfMetadata.fromFrontmatter(<String, Object?>{
        'type': 'Metric',
        'runtime': 'bigquery',
      });

      expect(metadata.runtime, 'bigquery');
      expect(metadata.computationContract, isNull);
    });
  });
}
