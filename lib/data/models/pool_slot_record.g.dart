// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pool_slot_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPoolSlotRecordCollection on Isar {
  IsarCollection<PoolSlotRecord> get poolSlotRecords => this.collection();
}

const PoolSlotRecordSchema = CollectionSchema(
  name: r'PoolSlotRecord',
  id: -3905437408098126015,
  properties: {
    r'poolUrl': PropertySchema(id: 0, name: r'poolUrl', type: IsarType.string),
    r'slotNo': PropertySchema(id: 1, name: r'slotNo', type: IsarType.long),
    r'workerCode': PropertySchema(
      id: 2,
      name: r'workerCode',
      type: IsarType.string,
    ),
  },
  estimateSize: _poolSlotRecordEstimateSize,
  serialize: _poolSlotRecordSerialize,
  deserialize: _poolSlotRecordDeserialize,
  deserializeProp: _poolSlotRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'slotNo': IndexSchema(
      id: 1850348867115986134,
      name: r'slotNo',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'slotNo',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _poolSlotRecordGetId,
  getLinks: _poolSlotRecordGetLinks,
  attach: _poolSlotRecordAttach,
  version: '3.1.0+1',
);

int _poolSlotRecordEstimateSize(
  PoolSlotRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.poolUrl.length * 3;
  bytesCount += 3 + object.workerCode.length * 3;
  return bytesCount;
}

void _poolSlotRecordSerialize(
  PoolSlotRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.poolUrl);
  writer.writeLong(offsets[1], object.slotNo);
  writer.writeString(offsets[2], object.workerCode);
}

PoolSlotRecord _poolSlotRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PoolSlotRecord();
  object.id = id;
  object.poolUrl = reader.readString(offsets[0]);
  object.slotNo = reader.readLong(offsets[1]);
  object.workerCode = reader.readString(offsets[2]);
  return object;
}

P _poolSlotRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _poolSlotRecordGetId(PoolSlotRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _poolSlotRecordGetLinks(PoolSlotRecord object) {
  return [];
}

void _poolSlotRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  PoolSlotRecord object,
) {
  object.id = id;
}

extension PoolSlotRecordByIndex on IsarCollection<PoolSlotRecord> {
  Future<PoolSlotRecord?> getBySlotNo(int slotNo) {
    return getByIndex(r'slotNo', [slotNo]);
  }

  PoolSlotRecord? getBySlotNoSync(int slotNo) {
    return getByIndexSync(r'slotNo', [slotNo]);
  }

  Future<bool> deleteBySlotNo(int slotNo) {
    return deleteByIndex(r'slotNo', [slotNo]);
  }

  bool deleteBySlotNoSync(int slotNo) {
    return deleteByIndexSync(r'slotNo', [slotNo]);
  }

  Future<List<PoolSlotRecord?>> getAllBySlotNo(List<int> slotNoValues) {
    final values = slotNoValues.map((e) => [e]).toList();
    return getAllByIndex(r'slotNo', values);
  }

  List<PoolSlotRecord?> getAllBySlotNoSync(List<int> slotNoValues) {
    final values = slotNoValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'slotNo', values);
  }

  Future<int> deleteAllBySlotNo(List<int> slotNoValues) {
    final values = slotNoValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'slotNo', values);
  }

  int deleteAllBySlotNoSync(List<int> slotNoValues) {
    final values = slotNoValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'slotNo', values);
  }

  Future<Id> putBySlotNo(PoolSlotRecord object) {
    return putByIndex(r'slotNo', object);
  }

  Id putBySlotNoSync(PoolSlotRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'slotNo', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySlotNo(List<PoolSlotRecord> objects) {
    return putAllByIndex(r'slotNo', objects);
  }

  List<Id> putAllBySlotNoSync(
    List<PoolSlotRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'slotNo', objects, saveLinks: saveLinks);
  }
}

extension PoolSlotRecordQueryWhereSort
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QWhere> {
  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhere> anySlotNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'slotNo'),
      );
    });
  }
}

extension PoolSlotRecordQueryWhere
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QWhereClause> {
  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause> idBetween(
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

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause> slotNoEqualTo(
    int slotNo,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'slotNo', value: [slotNo]),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause>
  slotNoNotEqualTo(int slotNo) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slotNo',
                lower: [],
                upper: [slotNo],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slotNo',
                lower: [slotNo],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slotNo',
                lower: [slotNo],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'slotNo',
                lower: [],
                upper: [slotNo],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause>
  slotNoGreaterThan(int slotNo, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'slotNo',
          lower: [slotNo],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause>
  slotNoLessThan(int slotNo, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'slotNo',
          lower: [],
          upper: [slotNo],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterWhereClause> slotNoBetween(
    int lowerSlotNo,
    int upperSlotNo, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'slotNo',
          lower: [lowerSlotNo],
          includeLower: includeLower,
          upper: [upperSlotNo],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension PoolSlotRecordQueryFilter
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QFilterCondition> {
  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
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

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
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

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'poolUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'poolUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'poolUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'poolUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'poolUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'poolUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'poolUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'poolUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'poolUrl', value: ''),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  poolUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'poolUrl', value: ''),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  slotNoEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'slotNo', value: value),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  slotNoGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'slotNo',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  slotNoLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'slotNo',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  slotNoBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'slotNo',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'workerCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'workerCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'workerCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'workerCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'workerCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'workerCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'workerCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'workerCode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'workerCode', value: ''),
      );
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterFilterCondition>
  workerCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'workerCode', value: ''),
      );
    });
  }
}

extension PoolSlotRecordQueryObject
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QFilterCondition> {}

extension PoolSlotRecordQueryLinks
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QFilterCondition> {}

extension PoolSlotRecordQuerySortBy
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QSortBy> {
  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy> sortByPoolUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolUrl', Sort.asc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  sortByPoolUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolUrl', Sort.desc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy> sortBySlotNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotNo', Sort.asc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  sortBySlotNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotNo', Sort.desc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  sortByWorkerCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workerCode', Sort.asc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  sortByWorkerCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workerCode', Sort.desc);
    });
  }
}

extension PoolSlotRecordQuerySortThenBy
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QSortThenBy> {
  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy> thenByPoolUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolUrl', Sort.asc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  thenByPoolUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolUrl', Sort.desc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy> thenBySlotNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotNo', Sort.asc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  thenBySlotNoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'slotNo', Sort.desc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  thenByWorkerCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workerCode', Sort.asc);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QAfterSortBy>
  thenByWorkerCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workerCode', Sort.desc);
    });
  }
}

extension PoolSlotRecordQueryWhereDistinct
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QDistinct> {
  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QDistinct> distinctByPoolUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'poolUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QDistinct> distinctBySlotNo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'slotNo');
    });
  }

  QueryBuilder<PoolSlotRecord, PoolSlotRecord, QDistinct> distinctByWorkerCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workerCode', caseSensitive: caseSensitive);
    });
  }
}

extension PoolSlotRecordQueryProperty
    on QueryBuilder<PoolSlotRecord, PoolSlotRecord, QQueryProperty> {
  QueryBuilder<PoolSlotRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PoolSlotRecord, String, QQueryOperations> poolUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'poolUrl');
    });
  }

  QueryBuilder<PoolSlotRecord, int, QQueryOperations> slotNoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'slotNo');
    });
  }

  QueryBuilder<PoolSlotRecord, String, QQueryOperations> workerCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workerCode');
    });
  }
}
