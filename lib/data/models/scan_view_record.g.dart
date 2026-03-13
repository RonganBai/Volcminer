// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_view_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetScanViewRecordCollection on Isar {
  IsarCollection<ScanViewRecord> get scanViewRecords => this.collection();
}

const ScanViewRecordSchema = CollectionSchema(
  name: r'ScanViewRecord',
  id: -3735036214895989184,
  properties: {
    r'cidr': PropertySchema(id: 0, name: r'cidr', type: IsarType.string),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'endIp': PropertySchema(id: 2, name: r'endIp', type: IsarType.string),
    r'name': PropertySchema(id: 3, name: r'name', type: IsarType.string),
    r'startIp': PropertySchema(id: 4, name: r'startIp', type: IsarType.string),
    r'tags': PropertySchema(id: 5, name: r'tags', type: IsarType.stringList),
    r'updatedAt': PropertySchema(
      id: 6,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'viewId': PropertySchema(id: 7, name: r'viewId', type: IsarType.string),
  },
  estimateSize: _scanViewRecordEstimateSize,
  serialize: _scanViewRecordSerialize,
  deserialize: _scanViewRecordDeserialize,
  deserializeProp: _scanViewRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'viewId': IndexSchema(
      id: 1556026688347355539,
      name: r'viewId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'viewId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _scanViewRecordGetId,
  getLinks: _scanViewRecordGetLinks,
  attach: _scanViewRecordAttach,
  version: '3.1.0+1',
);

int _scanViewRecordEstimateSize(
  ScanViewRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidr.length * 3;
  bytesCount += 3 + object.endIp.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.startIp.length * 3;
  bytesCount += 3 + object.tags.length * 3;
  {
    for (var i = 0; i < object.tags.length; i++) {
      final value = object.tags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.viewId.length * 3;
  return bytesCount;
}

void _scanViewRecordSerialize(
  ScanViewRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidr);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.endIp);
  writer.writeString(offsets[3], object.name);
  writer.writeString(offsets[4], object.startIp);
  writer.writeStringList(offsets[5], object.tags);
  writer.writeDateTime(offsets[6], object.updatedAt);
  writer.writeString(offsets[7], object.viewId);
}

ScanViewRecord _scanViewRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ScanViewRecord();
  object.cidr = reader.readString(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.endIp = reader.readString(offsets[2]);
  object.id = id;
  object.name = reader.readString(offsets[3]);
  object.startIp = reader.readString(offsets[4]);
  object.tags = reader.readStringList(offsets[5]) ?? [];
  object.updatedAt = reader.readDateTime(offsets[6]);
  object.viewId = reader.readString(offsets[7]);
  return object;
}

P _scanViewRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringList(offset) ?? []) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _scanViewRecordGetId(ScanViewRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _scanViewRecordGetLinks(ScanViewRecord object) {
  return [];
}

void _scanViewRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  ScanViewRecord object,
) {
  object.id = id;
}

extension ScanViewRecordByIndex on IsarCollection<ScanViewRecord> {
  Future<ScanViewRecord?> getByViewId(String viewId) {
    return getByIndex(r'viewId', [viewId]);
  }

  ScanViewRecord? getByViewIdSync(String viewId) {
    return getByIndexSync(r'viewId', [viewId]);
  }

  Future<bool> deleteByViewId(String viewId) {
    return deleteByIndex(r'viewId', [viewId]);
  }

  bool deleteByViewIdSync(String viewId) {
    return deleteByIndexSync(r'viewId', [viewId]);
  }

  Future<List<ScanViewRecord?>> getAllByViewId(List<String> viewIdValues) {
    final values = viewIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'viewId', values);
  }

  List<ScanViewRecord?> getAllByViewIdSync(List<String> viewIdValues) {
    final values = viewIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'viewId', values);
  }

  Future<int> deleteAllByViewId(List<String> viewIdValues) {
    final values = viewIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'viewId', values);
  }

  int deleteAllByViewIdSync(List<String> viewIdValues) {
    final values = viewIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'viewId', values);
  }

  Future<Id> putByViewId(ScanViewRecord object) {
    return putByIndex(r'viewId', object);
  }

  Id putByViewIdSync(ScanViewRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'viewId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByViewId(List<ScanViewRecord> objects) {
    return putAllByIndex(r'viewId', objects);
  }

  List<Id> putAllByViewIdSync(
    List<ScanViewRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'viewId', objects, saveLinks: saveLinks);
  }
}

extension ScanViewRecordQueryWhereSort
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QWhere> {
  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ScanViewRecordQueryWhere
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QWhereClause> {
  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhereClause> viewIdEqualTo(
    String viewId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'viewId', value: [viewId]),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterWhereClause>
  viewIdNotEqualTo(String viewId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'viewId',
                lower: [],
                upper: [viewId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'viewId',
                lower: [viewId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'viewId',
                lower: [viewId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'viewId',
                lower: [],
                upper: [viewId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ScanViewRecordQueryFilter
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QFilterCondition> {
  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cidr',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cidr',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cidr',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cidr',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cidr',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cidr',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cidr',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cidr',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cidr', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  cidrIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cidr', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'endIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'endIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'endIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'endIp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'endIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'endIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'endIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'endIp',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'endIp', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  endIpIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'endIp', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'startIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startIp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'startIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'startIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'startIp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'startIp',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startIp', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  startIpIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'startIp', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tags',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tags',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tags', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tags', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', length, true, length, true);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, true, 0, true);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, false, 999999, true);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, true, length, include);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', length, include, 999999, true);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'viewId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'viewId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'viewId', value: ''),
      );
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterFilterCondition>
  viewIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'viewId', value: ''),
      );
    });
  }
}

extension ScanViewRecordQueryObject
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QFilterCondition> {}

extension ScanViewRecordQueryLinks
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QFilterCondition> {}

extension ScanViewRecordQuerySortBy
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QSortBy> {
  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByCidr() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidr', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByCidrDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidr', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByEndIp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endIp', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByEndIpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endIp', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByStartIp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startIp', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  sortByStartIpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startIp', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> sortByViewId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  sortByViewIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.desc);
    });
  }
}

extension ScanViewRecordQuerySortThenBy
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QSortThenBy> {
  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByCidr() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidr', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByCidrDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidr', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByEndIp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endIp', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByEndIpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endIp', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByStartIp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startIp', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  thenByStartIpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startIp', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy> thenByViewId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.asc);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QAfterSortBy>
  thenByViewIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.desc);
    });
  }
}

extension ScanViewRecordQueryWhereDistinct
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct> {
  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct> distinctByCidr({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidr', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct> distinctByEndIp({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endIp', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct> distinctByStartIp({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startIp', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct> distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<ScanViewRecord, ScanViewRecord, QDistinct> distinctByViewId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'viewId', caseSensitive: caseSensitive);
    });
  }
}

extension ScanViewRecordQueryProperty
    on QueryBuilder<ScanViewRecord, ScanViewRecord, QQueryProperty> {
  QueryBuilder<ScanViewRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ScanViewRecord, String, QQueryOperations> cidrProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidr');
    });
  }

  QueryBuilder<ScanViewRecord, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ScanViewRecord, String, QQueryOperations> endIpProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endIp');
    });
  }

  QueryBuilder<ScanViewRecord, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<ScanViewRecord, String, QQueryOperations> startIpProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startIp');
    });
  }

  QueryBuilder<ScanViewRecord, List<String>, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<ScanViewRecord, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<ScanViewRecord, String, QQueryOperations> viewIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'viewId');
    });
  }
}
