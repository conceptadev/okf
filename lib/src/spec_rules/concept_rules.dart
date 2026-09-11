import '../concept_id.dart';
import '../document.dart';
import '../finding.dart';
import '../iso_date.dart';
import 'rule.dart';

/// Fixed Spec rules over concept documents, in validation order.
final List<OkfSpecRule>
conceptRules = List<OkfSpecRule>.unmodifiable(<OkfSpecRule>[
  _conceptRule(
    'missing-frontmatter',
    'Concept documents must begin with YAML frontmatter.',
    OkfFindingSeverity.error,
    (id, document) => <String>[
      if (!document.hasFrontmatter)
        'Concept documents must begin with YAML frontmatter.',
    ],
  ),
  _conceptRule(
    'missing-type',
    'Concept frontmatter must contain a non-empty type field.',
    OkfFindingSeverity.error,
    (id, document) => <String>[
      if (!_isTruthy(document.frontmatter['type']))
        'Concept frontmatter must contain a non-empty type field.',
    ],
  ),
  _conceptRule(
    'type-not-string',
    'Concept type fields should be short strings.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final type = document.frontmatter['type'];
      return <String>[
        if (_isTruthy(type) && type is! String)
          'The type field should be a short string; it will be consumed '
              'best-effort.',
      ];
    },
  ),
  _conceptRule(
    'non-portable-concept-id',
    'Concept IDs should be portable to ASCII-only producer tooling.',
    OkfFindingSeverity.advisory,
    (id, document) => <String>[
      if (!id.isPortableAscii)
        'This safe Unicode concept ID is valid but may not be accepted by '
            'ASCII-only producer tooling.',
    ],
  ),
  _conceptRule(
    'invalid-tags',
    'Tags should be a list of non-empty strings.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final tags = document.frontmatter['tags'];
      return <String>[
        if (tags != null &&
            (tags is! List<Object?> ||
                tags.any((tag) => tag is! String || tag.trim().isEmpty)))
          'tags should be a YAML list of non-empty strings.',
      ];
    },
  ),
  _conceptRule(
    'invalid-sources',
    'Sources should be a list of mappings.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final sources = document.frontmatter['sources'];
      return <String>[
        if (sources != null && sources is! List<Object?>)
          'sources should be a list of mappings.',
      ];
    },
  ),
  _conceptRule(
    'invalid-source',
    'Each source should contain a non-empty resource.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final sources = document.frontmatter['sources'];
      return <String>[
        if (sources is List<Object?>)
          for (var index = 0; index < sources.length; index++)
            if (!_hasResource(sources[index]))
              'sources[$index] should be a mapping with a non-empty resource.',
      ];
    },
  ),
  _conceptRule(
    'invalid-usage-window',
    'Usage windows should contain valid ISO date boundaries.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final window = document.frontmatter['usage_window'];
      return <String>[
        if (window != null &&
            (window is! Map<Object?, Object?> ||
                !_isIsoDate(window['from']) ||
                !_isIsoDate(window['to'])))
          'usage_window should contain ISO date from and to values.',
      ];
    },
  ),
  _conceptRule(
    'invalid-generated',
    'Generation metadata should identify an actor and valid timestamp.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final generated = document.frontmatter['generated'];
      return <String>[
        if (generated != null &&
            (generated is! Map<Object?, Object?> ||
                !isNonEmptyString(generated['by']) ||
                (generated['at'] != null && !_isIsoDateTime(generated['at']))))
          'generated should contain a non-empty by actor and an optional '
              'ISO 8601 at timestamp.',
      ];
    },
  ),
  _conceptRule(
    'invalid-verified',
    'Verification metadata should identify actors and valid timestamps.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final verified = document.frontmatter['verified'];
      if (verified == null) {
        return const <String>[];
      }
      final events = verified is List<Object?> ? verified : <Object?>[verified];
      return <String>[
        if (events.isEmpty ||
            events.any(
              (event) =>
                  event is! Map<Object?, Object?> ||
                  !isNonEmptyString(event['by']) ||
                  !_isIsoDateTime(event['at']),
            ))
          'verified should be a mapping or list of mappings containing by '
              'and an ISO 8601 at timestamp.',
      ];
    },
  ),
  _conceptRule(
    'invalid-status',
    'Lifecycle status should be draft, stable, or deprecated.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final status = document.frontmatter['status'];
      return <String>[
        if (status != null &&
            (status is! String ||
                !const <String>{
                  'draft',
                  'stable',
                  'deprecated',
                }.contains(status)))
          'status should be draft, stable, or deprecated.',
      ];
    },
  ),
  _conceptRule(
    'invalid-stale-after',
    'Staleness dates should use the ISO 8601 YYYY-MM-DD form.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final staleAfter = document.frontmatter['stale_after'];
      return <String>[
        if (staleAfter != null && !_isIsoDate(staleAfter))
          'stale_after should be an ISO 8601 YYYY-MM-DD date.',
      ];
    },
  ),
  _conceptRule(
    'missing-computation-runtime',
    'Attested computations should declare a runtime.',
    OkfFindingSeverity.advisory,
    (id, document) => <String>[
      if (_isAttestedComputation(document) &&
          !isNonEmptyString(document.frontmatter['runtime']))
        'Attested Computation concepts should declare a runtime.',
    ],
  ),
  _conceptRule(
    'invalid-computation-parameters',
    'Computation parameters should declare valid names, types, and flags.',
    OkfFindingSeverity.advisory,
    (id, document) {
      final parameters = document.frontmatter['parameters'];
      return <String>[
        if (_isAttestedComputation(document) &&
            parameters != null &&
            (parameters is! List<Object?> ||
                parameters.any(
                  (parameter) => !_isComputationParameter(parameter),
                )))
          'parameters should contain mappings with name, type, and an '
              'optional boolean required field.',
      ];
    },
  ),
  _conceptRule(
    'invalid-executor',
    'Computation executors should contain a non-empty resource.',
    OkfFindingSeverity.advisory,
    (id, document) => _computationActorMessages(document, 'executor'),
  ),
  _conceptRule(
    'invalid-attester',
    'Computation attesters should contain a non-empty resource.',
    OkfFindingSeverity.advisory,
    (id, document) => _computationActorMessages(document, 'attester'),
  ),
]);

/// The messages one rule reports for a single concept document.
typedef _ConceptCheck =
    Iterable<String> Function(OkfConceptId id, OkfDocument document);

/// A Spec rule that checks every concept document independently.
OkfSpecRule _conceptRule(
  String code,
  String prose,
  OkfFindingSeverity severity,
  _ConceptCheck check,
) => OkfSpecRule(
  code: code,
  prose: prose,
  severity: severity,
  run: (rule, context) => <OkfFinding>[
    for (final MapEntry(key: id, value: document)
        in context.bundle.concepts.entries)
      for (final message in check(id, document))
        rule.finding(
          message: message,
          location: OkfFindingLocation(path: id.documentPath),
        ),
  ],
);

Iterable<String> _computationActorMessages(OkfDocument document, String key) {
  final actor = document.frontmatter[key];
  return <String>[
    if (_isAttestedComputation(document) &&
        actor != null &&
        !_hasResource(actor))
      '$key should be a mapping with a non-empty resource.',
  ];
}

bool _isAttestedComputation(OkfDocument document) =>
    document.frontmatter['type'] == 'Attested Computation';

bool _hasResource(Object? value) =>
    value is Map<Object?, Object?> && isNonEmptyString(value['resource']);

bool _isComputationParameter(Object? value) =>
    value is Map<Object?, Object?> &&
    isNonEmptyString(value['name']) &&
    isNonEmptyString(value['type']) &&
    (value['required'] == null || value['required'] is bool);

bool _isTruthy(Object? value) {
  if (value == null || value == false) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is Iterable<Object?>) {
    return value.isNotEmpty;
  }
  if (value is Map<Object?, Object?>) {
    return value.isNotEmpty;
  }
  return true;
}

bool _isIsoDate(Object? value) {
  if (value is DateTime) {
    return true;
  }
  return value is String &&
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      parseIsoDate(value) != null;
}

bool _isIsoDateTime(Object? value) {
  if (value is DateTime) {
    return true;
  }
  return value is String && parseIsoDateTime(value) != null;
}
