import 'package:okf/okf.dart';
import 'package:okf/src/mcp/inputs.dart';
import 'package:test/test.dart';

void main() {
  test('generated concept inputs round-trip IDs as wire strings', () {
    const id = 'metrics/café';
    const target = 'areas/東京';
    final lookup = LookupConceptInput.fromJson({'id': id});
    final create = CreateConceptInput.fromJson({'id': id, 'type': 'Metric'});
    final update = UpdateConceptInput.fromJson({
      'id': id,
      'description': '',
      'tags': <String>[],
      'body': '',
    });
    final link = LinkConceptsInput.fromJson({
      'source': id,
      'target': target,
      'relationship': 'related',
    });
    final deprecate = DeprecateConceptInput.fromJson({'id': id});

    expect(<OkfConceptId>[
      lookup.id,
      create.id,
      update.id,
      link.source,
      deprecate.id,
    ], everyElement(OkfConceptId(id)));
    expect(link.target, OkfConceptId(target));
    expect(lookup.toJson(), {'id': id});
    expect(create.toJson(), {'id': id, 'type': 'Metric'});
    expect(update.toJson(), {
      'id': id,
      'description': '',
      'tags': <String>[],
      'body': '',
    });
    expect(link.toJson(), {
      'source': id,
      'target': target,
      'relationship': 'related',
    });
    expect(deprecate.toJson(), {'id': id});

    expect(LookupConceptInput.fromJson(lookup.toJson()), lookup);
    expect(CreateConceptInput.fromJson(create.toJson()), create);
    expect(UpdateConceptInput.fromJson(update.toJson()), update);
    expect(LinkConceptsInput.fromJson(link.toJson()), link);
    expect(DeprecateConceptInput.fromJson(deprecate.toJson()), deprecate);
  });
}
