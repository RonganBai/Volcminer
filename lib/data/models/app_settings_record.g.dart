// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppSettingsRecordCollection on Isar {
  IsarCollection<AppSettingsRecord> get appSettingsRecords => this.collection();
}

const AppSettingsRecordSchema = CollectionSchema(
  name: r'AppSettingsRecord',
  id: -5800169138830006153,
  properties: {
    r'autoRefreshEnabled': PropertySchema(
      id: 0,
      name: r'autoRefreshEnabled',
      type: IsarType.bool,
    ),
    r'collectLogsEnabled': PropertySchema(
      id: 1,
      name: r'collectLogsEnabled',
      type: IsarType.bool,
    ),
    r'fontScale': PropertySchema(
      id: 2,
      name: r'fontScale',
      type: IsarType.double,
    ),
    r'minerUsername': PropertySchema(
      id: 3,
      name: r'minerUsername',
      type: IsarType.string,
    ),
    r'poolSearchUsername': PropertySchema(
      id: 4,
      name: r'poolSearchUsername',
      type: IsarType.string,
    ),
    r'refreshIntervalSec': PropertySchema(
      id: 5,
      name: r'refreshIntervalSec',
      type: IsarType.long,
    ),
    r'scanConcurrency': PropertySchema(
      id: 6,
      name: r'scanConcurrency',
      type: IsarType.long,
    ),
    r'showOfflineEnabled': PropertySchema(
      id: 7,
      name: r'showOfflineEnabled',
      type: IsarType.bool,
    )
  },
  estimateSize: _appSettingsRecordEstimateSize,
  serialize: _appSettingsRecordSerialize,
  deserialize: _appSettingsRecordDeserialize,
  deserializeProp: _appSettingsRecordDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appSettingsRecordGetId,
  getLinks: _appSettingsRecordGetLinks,
  attach: _appSettingsRecordAttach,
  version: '3.1.0+1',
);

int _appSettingsRecordEstimateSize(
  AppSettingsRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.minerUsername.length * 3;
  bytesCount += 3 + object.poolSearchUsername.length * 3;
  return bytesCount;
}

void _appSettingsRecordSerialize(
  AppSettingsRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.autoRefreshEnabled);
  writer.writeBool(offsets[1], object.collectLogsEnabled);
  writer.writeDouble(offsets[2], object.fontScale);
  writer.writeString(offsets[3], object.minerUsername);
  writer.writeString(offsets[4], object.poolSearchUsername);
  writer.writeLong(offsets[5], object.refreshIntervalSec);
  writer.writeLong(offsets[6], object.scanConcurrency);
  writer.writeBool(offsets[7], object.showOfflineEnabled);
}

AppSettingsRecord _appSettingsRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppSettingsRecord();
  object.autoRefreshEnabled = reader.readBool(offsets[0]);
  object.collectLogsEnabled = reader.readBool(offsets[1]);
  object.fontScale = reader.readDouble(offsets[2]);
  object.id = id;
  object.minerUsername = reader.readString(offsets[3]);
  object.poolSearchUsername = reader.readString(offsets[4]);
  object.refreshIntervalSec = reader.readLong(offsets[5]);
  object.scanConcurrency = reader.readLong(offsets[6]);
  object.showOfflineEnabled = reader.readBool(offsets[7]);
  return object;
}

P _appSettingsRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appSettingsRecordGetId(AppSettingsRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appSettingsRecordGetLinks(
    AppSettingsRecord object) {
  return [];
}

void _appSettingsRecordAttach(
    IsarCollection<dynamic> col, Id id, AppSettingsRecord object) {
  object.id = id;
}

extension AppSettingsRecordQueryWhereSort
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QWhere> {
  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppSettingsRecordQueryWhere
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QWhereClause> {
  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AppSettingsRecordQueryFilter
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QFilterCondition> {
  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      autoRefreshEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoRefreshEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      collectLogsEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'collectLogsEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      fontScaleEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      fontScaleGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      fontScaleLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      fontScaleBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fontScale',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minerUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minerUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minerUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minerUsername',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'minerUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'minerUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'minerUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'minerUsername',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minerUsername',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      minerUsernameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'minerUsername',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'poolSearchUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'poolSearchUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'poolSearchUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'poolSearchUsername',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'poolSearchUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'poolSearchUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'poolSearchUsername',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'poolSearchUsername',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'poolSearchUsername',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      poolSearchUsernameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'poolSearchUsername',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      refreshIntervalSecEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'refreshIntervalSec',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      refreshIntervalSecGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'refreshIntervalSec',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      refreshIntervalSecLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'refreshIntervalSec',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      refreshIntervalSecBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'refreshIntervalSec',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      scanConcurrencyEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scanConcurrency',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      scanConcurrencyGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scanConcurrency',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      scanConcurrencyLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scanConcurrency',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      scanConcurrencyBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scanConcurrency',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterFilterCondition>
      showOfflineEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'showOfflineEnabled',
        value: value,
      ));
    });
  }
}

extension AppSettingsRecordQueryObject
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QFilterCondition> {}

extension AppSettingsRecordQueryLinks
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QFilterCondition> {}

extension AppSettingsRecordQuerySortBy
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QSortBy> {
  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByAutoRefreshEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRefreshEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByAutoRefreshEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRefreshEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByCollectLogsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectLogsEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByCollectLogsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectLogsEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByFontScaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByMinerUsername() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minerUsername', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByMinerUsernameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minerUsername', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByPoolSearchUsername() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolSearchUsername', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByPoolSearchUsernameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolSearchUsername', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByRefreshIntervalSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refreshIntervalSec', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByRefreshIntervalSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refreshIntervalSec', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByScanConcurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanConcurrency', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByScanConcurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanConcurrency', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByShowOfflineEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showOfflineEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      sortByShowOfflineEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showOfflineEnabled', Sort.desc);
    });
  }
}

extension AppSettingsRecordQuerySortThenBy
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QSortThenBy> {
  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByAutoRefreshEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRefreshEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByAutoRefreshEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoRefreshEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByCollectLogsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectLogsEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByCollectLogsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'collectLogsEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByFontScaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontScale', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByMinerUsername() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minerUsername', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByMinerUsernameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minerUsername', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByPoolSearchUsername() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolSearchUsername', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByPoolSearchUsernameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'poolSearchUsername', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByRefreshIntervalSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refreshIntervalSec', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByRefreshIntervalSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refreshIntervalSec', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByScanConcurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanConcurrency', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByScanConcurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanConcurrency', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByShowOfflineEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showOfflineEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QAfterSortBy>
      thenByShowOfflineEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showOfflineEnabled', Sort.desc);
    });
  }
}

extension AppSettingsRecordQueryWhereDistinct
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct> {
  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByAutoRefreshEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoRefreshEnabled');
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByCollectLogsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'collectLogsEnabled');
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fontScale');
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByMinerUsername({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minerUsername',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByPoolSearchUsername({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'poolSearchUsername',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByRefreshIntervalSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'refreshIntervalSec');
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByScanConcurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scanConcurrency');
    });
  }

  QueryBuilder<AppSettingsRecord, AppSettingsRecord, QDistinct>
      distinctByShowOfflineEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'showOfflineEnabled');
    });
  }
}

extension AppSettingsRecordQueryProperty
    on QueryBuilder<AppSettingsRecord, AppSettingsRecord, QQueryProperty> {
  QueryBuilder<AppSettingsRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppSettingsRecord, bool, QQueryOperations>
      autoRefreshEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoRefreshEnabled');
    });
  }

  QueryBuilder<AppSettingsRecord, bool, QQueryOperations>
      collectLogsEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'collectLogsEnabled');
    });
  }

  QueryBuilder<AppSettingsRecord, double, QQueryOperations>
      fontScaleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fontScale');
    });
  }

  QueryBuilder<AppSettingsRecord, String, QQueryOperations>
      minerUsernameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minerUsername');
    });
  }

  QueryBuilder<AppSettingsRecord, String, QQueryOperations>
      poolSearchUsernameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'poolSearchUsername');
    });
  }

  QueryBuilder<AppSettingsRecord, int, QQueryOperations>
      refreshIntervalSecProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'refreshIntervalSec');
    });
  }

  QueryBuilder<AppSettingsRecord, int, QQueryOperations>
      scanConcurrencyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scanConcurrency');
    });
  }

  QueryBuilder<AppSettingsRecord, bool, QQueryOperations>
      showOfflineEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'showOfflineEnabled');
    });
  }
}
