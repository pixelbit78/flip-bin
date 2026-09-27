// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$InventoryItemsDaoMixin on DatabaseAccessor<FlipBinDatabase> {
  $InventoryItemsTable get inventoryItems => attachedDatabase.inventoryItems;
  InventoryItemsDaoManager get managers => InventoryItemsDaoManager(this);
}

class InventoryItemsDaoManager {
  final _$InventoryItemsDaoMixin _db;
  InventoryItemsDaoManager(this._db);
  $$InventoryItemsTableTableManager get inventoryItems =>
      $$InventoryItemsTableTableManager(
          _db.attachedDatabase, _db.inventoryItems);
}

mixin _$ExpensesDaoMixin on DatabaseAccessor<FlipBinDatabase> {
  $ExpensesTable get expenses => attachedDatabase.expenses;
  ExpensesDaoManager get managers => ExpensesDaoManager(this);
}

class ExpensesDaoManager {
  final _$ExpensesDaoMixin _db;
  ExpensesDaoManager(this._db);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db.attachedDatabase, _db.expenses);
}

mixin _$BarcodeCacheDaoMixin on DatabaseAccessor<FlipBinDatabase> {
  $BarcodeCacheEntriesTable get barcodeCacheEntries =>
      attachedDatabase.barcodeCacheEntries;
  BarcodeCacheDaoManager get managers => BarcodeCacheDaoManager(this);
}

class BarcodeCacheDaoManager {
  final _$BarcodeCacheDaoMixin _db;
  BarcodeCacheDaoManager(this._db);
  $$BarcodeCacheEntriesTableTableManager get barcodeCacheEntries =>
      $$BarcodeCacheEntriesTableTableManager(
          _db.attachedDatabase, _db.barcodeCacheEntries);
}

class $InventoryItemsTable extends InventoryItems
    with TableInfo<$InventoryItemsTable, InventoryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dateAddedMeta =
      const VerificationMeta('dateAdded');
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
      'date_added', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _itemDescriptionMeta =
      const VerificationMeta('itemDescription');
  @override
  late final GeneratedColumn<String> itemDescription = GeneratedColumn<String>(
      'item_description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<ItemType, String> type =
      GeneratedColumn<String>('type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<ItemType>($InventoryItemsTable.$convertertype);
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<double> cost = GeneratedColumn<double>(
      'cost', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _platformMeta =
      const VerificationMeta('platform');
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
      'platform', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<ItemStatus, String> status =
      GeneratedColumn<String>('status', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<ItemStatus>($InventoryItemsTable.$converterstatus);
  static const VerificationMeta _dateSoldMeta =
      const VerificationMeta('dateSold');
  @override
  late final GeneratedColumn<DateTime> dateSold = GeneratedColumn<DateTime>(
      'date_sold', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _saleNumberMeta =
      const VerificationMeta('saleNumber');
  @override
  late final GeneratedColumn<String> saleNumber = GeneratedColumn<String>(
      'sale_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commentsMeta =
      const VerificationMeta('comments');
  @override
  late final GeneratedColumn<String> comments = GeneratedColumn<String>(
      'comments', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lookupNameMeta =
      const VerificationMeta('lookupName');
  @override
  late final GeneratedColumn<String> lookupName = GeneratedColumn<String>(
      'lookup_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lookupDescriptionMeta =
      const VerificationMeta('lookupDescription');
  @override
  late final GeneratedColumn<String> lookupDescription =
      GeneratedColumn<String>('lookup_description', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        dateAdded,
        barcode,
        itemDescription,
        type,
        cost,
        quantity,
        platform,
        status,
        dateSold,
        saleNumber,
        comments,
        imageUrl,
        lookupName,
        lookupDescription
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_items';
  @override
  VerificationContext validateIntegrity(Insertable<InventoryItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_added')) {
      context.handle(_dateAddedMeta,
          dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta));
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('item_description')) {
      context.handle(
          _itemDescriptionMeta,
          itemDescription.isAcceptableOrUnknown(
              data['item_description']!, _itemDescriptionMeta));
    } else if (isInserting) {
      context.missing(_itemDescriptionMeta);
    }
    if (data.containsKey('cost')) {
      context.handle(
          _costMeta, cost.isAcceptableOrUnknown(data['cost']!, _costMeta));
    } else if (isInserting) {
      context.missing(_costMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    if (data.containsKey('platform')) {
      context.handle(_platformMeta,
          platform.isAcceptableOrUnknown(data['platform']!, _platformMeta));
    }
    if (data.containsKey('date_sold')) {
      context.handle(_dateSoldMeta,
          dateSold.isAcceptableOrUnknown(data['date_sold']!, _dateSoldMeta));
    }
    if (data.containsKey('sale_number')) {
      context.handle(
          _saleNumberMeta,
          saleNumber.isAcceptableOrUnknown(
              data['sale_number']!, _saleNumberMeta));
    }
    if (data.containsKey('comments')) {
      context.handle(_commentsMeta,
          comments.isAcceptableOrUnknown(data['comments']!, _commentsMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('lookup_name')) {
      context.handle(
          _lookupNameMeta,
          lookupName.isAcceptableOrUnknown(
              data['lookup_name']!, _lookupNameMeta));
    }
    if (data.containsKey('lookup_description')) {
      context.handle(
          _lookupDescriptionMeta,
          lookupDescription.isAcceptableOrUnknown(
              data['lookup_description']!, _lookupDescriptionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      dateAdded: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_added'])!,
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode']),
      itemDescription: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}item_description'])!,
      type: $InventoryItemsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!),
      cost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}cost'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      platform: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}platform']),
      status: $InventoryItemsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!),
      dateSold: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_sold']),
      saleNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sale_number']),
      comments: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comments']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      lookupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lookup_name']),
      lookupDescription: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}lookup_description']),
    );
  }

  @override
  $InventoryItemsTable createAlias(String alias) {
    return $InventoryItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemType, String, String> $convertertype =
      const EnumNameConverter<ItemType>(ItemType.values);
  static JsonTypeConverter2<ItemStatus, String, String> $converterstatus =
      const EnumNameConverter<ItemStatus>(ItemStatus.values);
}

class InventoryItem extends DataClass implements Insertable<InventoryItem> {
  final int id;
  final DateTime dateAdded;
  final String? barcode;
  final String itemDescription;
  final ItemType type;
  final double cost;
  final int quantity;
  final String? platform;
  final ItemStatus status;
  final DateTime? dateSold;
  final String? saleNumber;
  final String? comments;
  final String? imageUrl;
  final String? lookupName;
  final String? lookupDescription;
  const InventoryItem(
      {required this.id,
      required this.dateAdded,
      this.barcode,
      required this.itemDescription,
      required this.type,
      required this.cost,
      required this.quantity,
      this.platform,
      required this.status,
      this.dateSold,
      this.saleNumber,
      this.comments,
      this.imageUrl,
      this.lookupName,
      this.lookupDescription});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_added'] = Variable<DateTime>(dateAdded);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['item_description'] = Variable<String>(itemDescription);
    {
      map['type'] =
          Variable<String>($InventoryItemsTable.$convertertype.toSql(type));
    }
    map['cost'] = Variable<double>(cost);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || platform != null) {
      map['platform'] = Variable<String>(platform);
    }
    {
      map['status'] =
          Variable<String>($InventoryItemsTable.$converterstatus.toSql(status));
    }
    if (!nullToAbsent || dateSold != null) {
      map['date_sold'] = Variable<DateTime>(dateSold);
    }
    if (!nullToAbsent || saleNumber != null) {
      map['sale_number'] = Variable<String>(saleNumber);
    }
    if (!nullToAbsent || comments != null) {
      map['comments'] = Variable<String>(comments);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || lookupName != null) {
      map['lookup_name'] = Variable<String>(lookupName);
    }
    if (!nullToAbsent || lookupDescription != null) {
      map['lookup_description'] = Variable<String>(lookupDescription);
    }
    return map;
  }

  InventoryItemsCompanion toCompanion(bool nullToAbsent) {
    return InventoryItemsCompanion(
      id: Value(id),
      dateAdded: Value(dateAdded),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      itemDescription: Value(itemDescription),
      type: Value(type),
      cost: Value(cost),
      quantity: Value(quantity),
      platform: platform == null && nullToAbsent
          ? const Value.absent()
          : Value(platform),
      status: Value(status),
      dateSold: dateSold == null && nullToAbsent
          ? const Value.absent()
          : Value(dateSold),
      saleNumber: saleNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(saleNumber),
      comments: comments == null && nullToAbsent
          ? const Value.absent()
          : Value(comments),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      lookupName: lookupName == null && nullToAbsent
          ? const Value.absent()
          : Value(lookupName),
      lookupDescription: lookupDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(lookupDescription),
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryItem(
      id: serializer.fromJson<int>(json['id']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      itemDescription: serializer.fromJson<String>(json['itemDescription']),
      type: $InventoryItemsTable.$convertertype
          .fromJson(serializer.fromJson<String>(json['type'])),
      cost: serializer.fromJson<double>(json['cost']),
      quantity: serializer.fromJson<int>(json['quantity']),
      platform: serializer.fromJson<String?>(json['platform']),
      status: $InventoryItemsTable.$converterstatus
          .fromJson(serializer.fromJson<String>(json['status'])),
      dateSold: serializer.fromJson<DateTime?>(json['dateSold']),
      saleNumber: serializer.fromJson<String?>(json['saleNumber']),
      comments: serializer.fromJson<String?>(json['comments']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      lookupName: serializer.fromJson<String?>(json['lookupName']),
      lookupDescription:
          serializer.fromJson<String?>(json['lookupDescription']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
      'barcode': serializer.toJson<String?>(barcode),
      'itemDescription': serializer.toJson<String>(itemDescription),
      'type': serializer
          .toJson<String>($InventoryItemsTable.$convertertype.toJson(type)),
      'cost': serializer.toJson<double>(cost),
      'quantity': serializer.toJson<int>(quantity),
      'platform': serializer.toJson<String?>(platform),
      'status': serializer
          .toJson<String>($InventoryItemsTable.$converterstatus.toJson(status)),
      'dateSold': serializer.toJson<DateTime?>(dateSold),
      'saleNumber': serializer.toJson<String?>(saleNumber),
      'comments': serializer.toJson<String?>(comments),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'lookupName': serializer.toJson<String?>(lookupName),
      'lookupDescription': serializer.toJson<String?>(lookupDescription),
    };
  }

  InventoryItem copyWith(
          {int? id,
          DateTime? dateAdded,
          Value<String?> barcode = const Value.absent(),
          String? itemDescription,
          ItemType? type,
          double? cost,
          int? quantity,
          Value<String?> platform = const Value.absent(),
          ItemStatus? status,
          Value<DateTime?> dateSold = const Value.absent(),
          Value<String?> saleNumber = const Value.absent(),
          Value<String?> comments = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> lookupName = const Value.absent(),
          Value<String?> lookupDescription = const Value.absent()}) =>
      InventoryItem(
        id: id ?? this.id,
        dateAdded: dateAdded ?? this.dateAdded,
        barcode: barcode.present ? barcode.value : this.barcode,
        itemDescription: itemDescription ?? this.itemDescription,
        type: type ?? this.type,
        cost: cost ?? this.cost,
        quantity: quantity ?? this.quantity,
        platform: platform.present ? platform.value : this.platform,
        status: status ?? this.status,
        dateSold: dateSold.present ? dateSold.value : this.dateSold,
        saleNumber: saleNumber.present ? saleNumber.value : this.saleNumber,
        comments: comments.present ? comments.value : this.comments,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        lookupName: lookupName.present ? lookupName.value : this.lookupName,
        lookupDescription: lookupDescription.present
            ? lookupDescription.value
            : this.lookupDescription,
      );
  InventoryItem copyWithCompanion(InventoryItemsCompanion data) {
    return InventoryItem(
      id: data.id.present ? data.id.value : this.id,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      itemDescription: data.itemDescription.present
          ? data.itemDescription.value
          : this.itemDescription,
      type: data.type.present ? data.type.value : this.type,
      cost: data.cost.present ? data.cost.value : this.cost,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      platform: data.platform.present ? data.platform.value : this.platform,
      status: data.status.present ? data.status.value : this.status,
      dateSold: data.dateSold.present ? data.dateSold.value : this.dateSold,
      saleNumber:
          data.saleNumber.present ? data.saleNumber.value : this.saleNumber,
      comments: data.comments.present ? data.comments.value : this.comments,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      lookupName:
          data.lookupName.present ? data.lookupName.value : this.lookupName,
      lookupDescription: data.lookupDescription.present
          ? data.lookupDescription.value
          : this.lookupDescription,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItem(')
          ..write('id: $id, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('barcode: $barcode, ')
          ..write('itemDescription: $itemDescription, ')
          ..write('type: $type, ')
          ..write('cost: $cost, ')
          ..write('quantity: $quantity, ')
          ..write('platform: $platform, ')
          ..write('status: $status, ')
          ..write('dateSold: $dateSold, ')
          ..write('saleNumber: $saleNumber, ')
          ..write('comments: $comments, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('lookupName: $lookupName, ')
          ..write('lookupDescription: $lookupDescription')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      dateAdded,
      barcode,
      itemDescription,
      type,
      cost,
      quantity,
      platform,
      status,
      dateSold,
      saleNumber,
      comments,
      imageUrl,
      lookupName,
      lookupDescription);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryItem &&
          other.id == this.id &&
          other.dateAdded == this.dateAdded &&
          other.barcode == this.barcode &&
          other.itemDescription == this.itemDescription &&
          other.type == this.type &&
          other.cost == this.cost &&
          other.quantity == this.quantity &&
          other.platform == this.platform &&
          other.status == this.status &&
          other.dateSold == this.dateSold &&
          other.saleNumber == this.saleNumber &&
          other.comments == this.comments &&
          other.imageUrl == this.imageUrl &&
          other.lookupName == this.lookupName &&
          other.lookupDescription == this.lookupDescription);
}

class InventoryItemsCompanion extends UpdateCompanion<InventoryItem> {
  final Value<int> id;
  final Value<DateTime> dateAdded;
  final Value<String?> barcode;
  final Value<String> itemDescription;
  final Value<ItemType> type;
  final Value<double> cost;
  final Value<int> quantity;
  final Value<String?> platform;
  final Value<ItemStatus> status;
  final Value<DateTime?> dateSold;
  final Value<String?> saleNumber;
  final Value<String?> comments;
  final Value<String?> imageUrl;
  final Value<String?> lookupName;
  final Value<String?> lookupDescription;
  const InventoryItemsCompanion({
    this.id = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.barcode = const Value.absent(),
    this.itemDescription = const Value.absent(),
    this.type = const Value.absent(),
    this.cost = const Value.absent(),
    this.quantity = const Value.absent(),
    this.platform = const Value.absent(),
    this.status = const Value.absent(),
    this.dateSold = const Value.absent(),
    this.saleNumber = const Value.absent(),
    this.comments = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.lookupName = const Value.absent(),
    this.lookupDescription = const Value.absent(),
  });
  InventoryItemsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime dateAdded,
    this.barcode = const Value.absent(),
    required String itemDescription,
    required ItemType type,
    required double cost,
    this.quantity = const Value.absent(),
    this.platform = const Value.absent(),
    required ItemStatus status,
    this.dateSold = const Value.absent(),
    this.saleNumber = const Value.absent(),
    this.comments = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.lookupName = const Value.absent(),
    this.lookupDescription = const Value.absent(),
  })  : dateAdded = Value(dateAdded),
        itemDescription = Value(itemDescription),
        type = Value(type),
        cost = Value(cost),
        status = Value(status);
  static Insertable<InventoryItem> custom({
    Expression<int>? id,
    Expression<DateTime>? dateAdded,
    Expression<String>? barcode,
    Expression<String>? itemDescription,
    Expression<String>? type,
    Expression<double>? cost,
    Expression<int>? quantity,
    Expression<String>? platform,
    Expression<String>? status,
    Expression<DateTime>? dateSold,
    Expression<String>? saleNumber,
    Expression<String>? comments,
    Expression<String>? imageUrl,
    Expression<String>? lookupName,
    Expression<String>? lookupDescription,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateAdded != null) 'date_added': dateAdded,
      if (barcode != null) 'barcode': barcode,
      if (itemDescription != null) 'item_description': itemDescription,
      if (type != null) 'type': type,
      if (cost != null) 'cost': cost,
      if (quantity != null) 'quantity': quantity,
      if (platform != null) 'platform': platform,
      if (status != null) 'status': status,
      if (dateSold != null) 'date_sold': dateSold,
      if (saleNumber != null) 'sale_number': saleNumber,
      if (comments != null) 'comments': comments,
      if (imageUrl != null) 'image_url': imageUrl,
      if (lookupName != null) 'lookup_name': lookupName,
      if (lookupDescription != null) 'lookup_description': lookupDescription,
    });
  }

  InventoryItemsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? dateAdded,
      Value<String?>? barcode,
      Value<String>? itemDescription,
      Value<ItemType>? type,
      Value<double>? cost,
      Value<int>? quantity,
      Value<String?>? platform,
      Value<ItemStatus>? status,
      Value<DateTime?>? dateSold,
      Value<String?>? saleNumber,
      Value<String?>? comments,
      Value<String?>? imageUrl,
      Value<String?>? lookupName,
      Value<String?>? lookupDescription}) {
    return InventoryItemsCompanion(
      id: id ?? this.id,
      dateAdded: dateAdded ?? this.dateAdded,
      barcode: barcode ?? this.barcode,
      itemDescription: itemDescription ?? this.itemDescription,
      type: type ?? this.type,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      dateSold: dateSold ?? this.dateSold,
      saleNumber: saleNumber ?? this.saleNumber,
      comments: comments ?? this.comments,
      imageUrl: imageUrl ?? this.imageUrl,
      lookupName: lookupName ?? this.lookupName,
      lookupDescription: lookupDescription ?? this.lookupDescription,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (itemDescription.present) {
      map['item_description'] = Variable<String>(itemDescription.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
          $InventoryItemsTable.$convertertype.toSql(type.value));
    }
    if (cost.present) {
      map['cost'] = Variable<double>(cost.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
          $InventoryItemsTable.$converterstatus.toSql(status.value));
    }
    if (dateSold.present) {
      map['date_sold'] = Variable<DateTime>(dateSold.value);
    }
    if (saleNumber.present) {
      map['sale_number'] = Variable<String>(saleNumber.value);
    }
    if (comments.present) {
      map['comments'] = Variable<String>(comments.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (lookupName.present) {
      map['lookup_name'] = Variable<String>(lookupName.value);
    }
    if (lookupDescription.present) {
      map['lookup_description'] = Variable<String>(lookupDescription.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItemsCompanion(')
          ..write('id: $id, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('barcode: $barcode, ')
          ..write('itemDescription: $itemDescription, ')
          ..write('type: $type, ')
          ..write('cost: $cost, ')
          ..write('quantity: $quantity, ')
          ..write('platform: $platform, ')
          ..write('status: $status, ')
          ..write('dateSold: $dateSold, ')
          ..write('saleNumber: $saleNumber, ')
          ..write('comments: $comments, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('lookupName: $lookupName, ')
          ..write('lookupDescription: $lookupDescription')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses with TableInfo<$ExpensesTable, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _merchantMeta =
      const VerificationMeta('merchant');
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
      'merchant', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receiptImagePathMeta =
      const VerificationMeta('receiptImagePath');
  @override
  late final GeneratedColumn<String> receiptImagePath = GeneratedColumn<String>(
      'receipt_image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _upcMeta = const VerificationMeta('upc');
  @override
  late final GeneratedColumn<String> upc = GeneratedColumn<String>(
      'upc', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _itemDescriptionMeta =
      const VerificationMeta('itemDescription');
  @override
  late final GeneratedColumn<String> itemDescription = GeneratedColumn<String>(
      'item_description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _unitPriceMeta =
      const VerificationMeta('unitPrice');
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
      'unit_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<ExpenseType, String> expenseType =
      GeneratedColumn<String>('expense_type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<ExpenseType>($ExpensesTable.$converterexpenseType);
  static const VerificationMeta _taxAmountMeta =
      const VerificationMeta('taxAmount');
  @override
  late final GeneratedColumn<double> taxAmount = GeneratedColumn<double>(
      'tax_amount', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        date,
        merchant,
        receiptImagePath,
        upc,
        itemDescription,
        quantity,
        unitPrice,
        expenseType,
        taxAmount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(Insertable<Expense> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(_merchantMeta,
          merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta));
    } else if (isInserting) {
      context.missing(_merchantMeta);
    }
    if (data.containsKey('receipt_image_path')) {
      context.handle(
          _receiptImagePathMeta,
          receiptImagePath.isAcceptableOrUnknown(
              data['receipt_image_path']!, _receiptImagePathMeta));
    }
    if (data.containsKey('upc')) {
      context.handle(
          _upcMeta, upc.isAcceptableOrUnknown(data['upc']!, _upcMeta));
    }
    if (data.containsKey('item_description')) {
      context.handle(
          _itemDescriptionMeta,
          itemDescription.isAcceptableOrUnknown(
              data['item_description']!, _itemDescriptionMeta));
    } else if (isInserting) {
      context.missing(_itemDescriptionMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    if (data.containsKey('unit_price')) {
      context.handle(_unitPriceMeta,
          unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta));
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('tax_amount')) {
      context.handle(_taxAmountMeta,
          taxAmount.isAcceptableOrUnknown(data['tax_amount']!, _taxAmountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      merchant: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}merchant'])!,
      receiptImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}receipt_image_path']),
      upc: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}upc']),
      itemDescription: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}item_description'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      unitPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}unit_price'])!,
      expenseType: $ExpensesTable.$converterexpenseType.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}expense_type'])!),
      taxAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}tax_amount']),
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExpenseType, String, String> $converterexpenseType =
      const EnumNameConverter<ExpenseType>(ExpenseType.values);
}

class Expense extends DataClass implements Insertable<Expense> {
  final int id;
  final DateTime date;
  final String merchant;
  final String? receiptImagePath;
  final String? upc;
  final String itemDescription;
  final int quantity;
  final double unitPrice;
  final ExpenseType expenseType;
  final double? taxAmount;
  const Expense(
      {required this.id,
      required this.date,
      required this.merchant,
      this.receiptImagePath,
      this.upc,
      required this.itemDescription,
      required this.quantity,
      required this.unitPrice,
      required this.expenseType,
      this.taxAmount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['merchant'] = Variable<String>(merchant);
    if (!nullToAbsent || receiptImagePath != null) {
      map['receipt_image_path'] = Variable<String>(receiptImagePath);
    }
    if (!nullToAbsent || upc != null) {
      map['upc'] = Variable<String>(upc);
    }
    map['item_description'] = Variable<String>(itemDescription);
    map['quantity'] = Variable<int>(quantity);
    map['unit_price'] = Variable<double>(unitPrice);
    {
      map['expense_type'] = Variable<String>(
          $ExpensesTable.$converterexpenseType.toSql(expenseType));
    }
    if (!nullToAbsent || taxAmount != null) {
      map['tax_amount'] = Variable<double>(taxAmount);
    }
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      date: Value(date),
      merchant: Value(merchant),
      receiptImagePath: receiptImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptImagePath),
      upc: upc == null && nullToAbsent ? const Value.absent() : Value(upc),
      itemDescription: Value(itemDescription),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      expenseType: Value(expenseType),
      taxAmount: taxAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(taxAmount),
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      merchant: serializer.fromJson<String>(json['merchant']),
      receiptImagePath: serializer.fromJson<String?>(json['receiptImagePath']),
      upc: serializer.fromJson<String?>(json['upc']),
      itemDescription: serializer.fromJson<String>(json['itemDescription']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      expenseType: $ExpensesTable.$converterexpenseType
          .fromJson(serializer.fromJson<String>(json['expenseType'])),
      taxAmount: serializer.fromJson<double?>(json['taxAmount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'merchant': serializer.toJson<String>(merchant),
      'receiptImagePath': serializer.toJson<String?>(receiptImagePath),
      'upc': serializer.toJson<String?>(upc),
      'itemDescription': serializer.toJson<String>(itemDescription),
      'quantity': serializer.toJson<int>(quantity),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'expenseType': serializer.toJson<String>(
          $ExpensesTable.$converterexpenseType.toJson(expenseType)),
      'taxAmount': serializer.toJson<double?>(taxAmount),
    };
  }

  Expense copyWith(
          {int? id,
          DateTime? date,
          String? merchant,
          Value<String?> receiptImagePath = const Value.absent(),
          Value<String?> upc = const Value.absent(),
          String? itemDescription,
          int? quantity,
          double? unitPrice,
          ExpenseType? expenseType,
          Value<double?> taxAmount = const Value.absent()}) =>
      Expense(
        id: id ?? this.id,
        date: date ?? this.date,
        merchant: merchant ?? this.merchant,
        receiptImagePath: receiptImagePath.present
            ? receiptImagePath.value
            : this.receiptImagePath,
        upc: upc.present ? upc.value : this.upc,
        itemDescription: itemDescription ?? this.itemDescription,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        expenseType: expenseType ?? this.expenseType,
        taxAmount: taxAmount.present ? taxAmount.value : this.taxAmount,
      );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      receiptImagePath: data.receiptImagePath.present
          ? data.receiptImagePath.value
          : this.receiptImagePath,
      upc: data.upc.present ? data.upc.value : this.upc,
      itemDescription: data.itemDescription.present
          ? data.itemDescription.value
          : this.itemDescription,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      expenseType:
          data.expenseType.present ? data.expenseType.value : this.expenseType,
      taxAmount: data.taxAmount.present ? data.taxAmount.value : this.taxAmount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('merchant: $merchant, ')
          ..write('receiptImagePath: $receiptImagePath, ')
          ..write('upc: $upc, ')
          ..write('itemDescription: $itemDescription, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('expenseType: $expenseType, ')
          ..write('taxAmount: $taxAmount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, merchant, receiptImagePath, upc,
      itemDescription, quantity, unitPrice, expenseType, taxAmount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.date == this.date &&
          other.merchant == this.merchant &&
          other.receiptImagePath == this.receiptImagePath &&
          other.upc == this.upc &&
          other.itemDescription == this.itemDescription &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.expenseType == this.expenseType &&
          other.taxAmount == this.taxAmount);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> merchant;
  final Value<String?> receiptImagePath;
  final Value<String?> upc;
  final Value<String> itemDescription;
  final Value<int> quantity;
  final Value<double> unitPrice;
  final Value<ExpenseType> expenseType;
  final Value<double?> taxAmount;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.merchant = const Value.absent(),
    this.receiptImagePath = const Value.absent(),
    this.upc = const Value.absent(),
    this.itemDescription = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.expenseType = const Value.absent(),
    this.taxAmount = const Value.absent(),
  });
  ExpensesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String merchant,
    this.receiptImagePath = const Value.absent(),
    this.upc = const Value.absent(),
    required String itemDescription,
    this.quantity = const Value.absent(),
    required double unitPrice,
    required ExpenseType expenseType,
    this.taxAmount = const Value.absent(),
  })  : date = Value(date),
        merchant = Value(merchant),
        itemDescription = Value(itemDescription),
        unitPrice = Value(unitPrice),
        expenseType = Value(expenseType);
  static Insertable<Expense> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? merchant,
    Expression<String>? receiptImagePath,
    Expression<String>? upc,
    Expression<String>? itemDescription,
    Expression<int>? quantity,
    Expression<double>? unitPrice,
    Expression<String>? expenseType,
    Expression<double>? taxAmount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (merchant != null) 'merchant': merchant,
      if (receiptImagePath != null) 'receipt_image_path': receiptImagePath,
      if (upc != null) 'upc': upc,
      if (itemDescription != null) 'item_description': itemDescription,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (expenseType != null) 'expense_type': expenseType,
      if (taxAmount != null) 'tax_amount': taxAmount,
    });
  }

  ExpensesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? date,
      Value<String>? merchant,
      Value<String?>? receiptImagePath,
      Value<String?>? upc,
      Value<String>? itemDescription,
      Value<int>? quantity,
      Value<double>? unitPrice,
      Value<ExpenseType>? expenseType,
      Value<double?>? taxAmount}) {
    return ExpensesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      upc: upc ?? this.upc,
      itemDescription: itemDescription ?? this.itemDescription,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      expenseType: expenseType ?? this.expenseType,
      taxAmount: taxAmount ?? this.taxAmount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (receiptImagePath.present) {
      map['receipt_image_path'] = Variable<String>(receiptImagePath.value);
    }
    if (upc.present) {
      map['upc'] = Variable<String>(upc.value);
    }
    if (itemDescription.present) {
      map['item_description'] = Variable<String>(itemDescription.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (expenseType.present) {
      map['expense_type'] = Variable<String>(
          $ExpensesTable.$converterexpenseType.toSql(expenseType.value));
    }
    if (taxAmount.present) {
      map['tax_amount'] = Variable<double>(taxAmount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('merchant: $merchant, ')
          ..write('receiptImagePath: $receiptImagePath, ')
          ..write('upc: $upc, ')
          ..write('itemDescription: $itemDescription, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('expenseType: $expenseType, ')
          ..write('taxAmount: $taxAmount')
          ..write(')'))
        .toString();
  }
}

class $BarcodeCacheEntriesTable extends BarcodeCacheEntries
    with TableInfo<$BarcodeCacheEntriesTable, BarcodeCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BarcodeCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        barcode,
        productName,
        description,
        imageUrl,
        category,
        source,
        fetchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'barcode_cache_entries';
  @override
  VerificationContext validateIntegrity(Insertable<BarcodeCacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    } else if (isInserting) {
      context.missing(_barcodeMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {barcode};
  @override
  BarcodeCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BarcodeCacheEntry(
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $BarcodeCacheEntriesTable createAlias(String alias) {
    return $BarcodeCacheEntriesTable(attachedDatabase, alias);
  }
}

class BarcodeCacheEntry extends DataClass
    implements Insertable<BarcodeCacheEntry> {
  final String barcode;
  final String? productName;
  final String? description;
  final String? imageUrl;
  final String? category;
  final String source;
  final DateTime fetchedAt;
  const BarcodeCacheEntry(
      {required this.barcode,
      this.productName,
      this.description,
      this.imageUrl,
      this.category,
      required this.source,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['barcode'] = Variable<String>(barcode);
    if (!nullToAbsent || productName != null) {
      map['product_name'] = Variable<String>(productName);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['source'] = Variable<String>(source);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  BarcodeCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return BarcodeCacheEntriesCompanion(
      barcode: Value(barcode),
      productName: productName == null && nullToAbsent
          ? const Value.absent()
          : Value(productName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      source: Value(source),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory BarcodeCacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BarcodeCacheEntry(
      barcode: serializer.fromJson<String>(json['barcode']),
      productName: serializer.fromJson<String?>(json['productName']),
      description: serializer.fromJson<String?>(json['description']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      category: serializer.fromJson<String?>(json['category']),
      source: serializer.fromJson<String>(json['source']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'barcode': serializer.toJson<String>(barcode),
      'productName': serializer.toJson<String?>(productName),
      'description': serializer.toJson<String?>(description),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'category': serializer.toJson<String?>(category),
      'source': serializer.toJson<String>(source),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  BarcodeCacheEntry copyWith(
          {String? barcode,
          Value<String?> productName = const Value.absent(),
          Value<String?> description = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> category = const Value.absent(),
          String? source,
          DateTime? fetchedAt}) =>
      BarcodeCacheEntry(
        barcode: barcode ?? this.barcode,
        productName: productName.present ? productName.value : this.productName,
        description: description.present ? description.value : this.description,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        category: category.present ? category.value : this.category,
        source: source ?? this.source,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  BarcodeCacheEntry copyWithCompanion(BarcodeCacheEntriesCompanion data) {
    return BarcodeCacheEntry(
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      description:
          data.description.present ? data.description.value : this.description,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      category: data.category.present ? data.category.value : this.category,
      source: data.source.present ? data.source.value : this.source,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeCacheEntry(')
          ..write('barcode: $barcode, ')
          ..write('productName: $productName, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('category: $category, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      barcode, productName, description, imageUrl, category, source, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BarcodeCacheEntry &&
          other.barcode == this.barcode &&
          other.productName == this.productName &&
          other.description == this.description &&
          other.imageUrl == this.imageUrl &&
          other.category == this.category &&
          other.source == this.source &&
          other.fetchedAt == this.fetchedAt);
}

class BarcodeCacheEntriesCompanion extends UpdateCompanion<BarcodeCacheEntry> {
  final Value<String> barcode;
  final Value<String?> productName;
  final Value<String?> description;
  final Value<String?> imageUrl;
  final Value<String?> category;
  final Value<String> source;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const BarcodeCacheEntriesCompanion({
    this.barcode = const Value.absent(),
    this.productName = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.category = const Value.absent(),
    this.source = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BarcodeCacheEntriesCompanion.insert({
    required String barcode,
    this.productName = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.category = const Value.absent(),
    required String source,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : barcode = Value(barcode),
        source = Value(source),
        fetchedAt = Value(fetchedAt);
  static Insertable<BarcodeCacheEntry> custom({
    Expression<String>? barcode,
    Expression<String>? productName,
    Expression<String>? description,
    Expression<String>? imageUrl,
    Expression<String>? category,
    Expression<String>? source,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (barcode != null) 'barcode': barcode,
      if (productName != null) 'product_name': productName,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (category != null) 'category': category,
      if (source != null) 'source': source,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BarcodeCacheEntriesCompanion copyWith(
      {Value<String>? barcode,
      Value<String?>? productName,
      Value<String?>? description,
      Value<String?>? imageUrl,
      Value<String?>? category,
      Value<String>? source,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return BarcodeCacheEntriesCompanion(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeCacheEntriesCompanion(')
          ..write('barcode: $barcode, ')
          ..write('productName: $productName, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('category: $category, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FlipBinDatabase extends GeneratedDatabase {
  _$FlipBinDatabase(QueryExecutor e) : super(e);
  $FlipBinDatabaseManager get managers => $FlipBinDatabaseManager(this);
  late final $InventoryItemsTable inventoryItems = $InventoryItemsTable(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $BarcodeCacheEntriesTable barcodeCacheEntries =
      $BarcodeCacheEntriesTable(this);
  late final InventoryItemsDao inventoryItemsDao =
      InventoryItemsDao(this as FlipBinDatabase);
  late final ExpensesDao expensesDao = ExpensesDao(this as FlipBinDatabase);
  late final BarcodeCacheDao barcodeCacheDao =
      BarcodeCacheDao(this as FlipBinDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [inventoryItems, expenses, barcodeCacheEntries];
}

typedef $$InventoryItemsTableCreateCompanionBuilder = InventoryItemsCompanion
    Function({
  Value<int> id,
  required DateTime dateAdded,
  Value<String?> barcode,
  required String itemDescription,
  required ItemType type,
  required double cost,
  Value<int> quantity,
  Value<String?> platform,
  required ItemStatus status,
  Value<DateTime?> dateSold,
  Value<String?> saleNumber,
  Value<String?> comments,
  Value<String?> imageUrl,
  Value<String?> lookupName,
  Value<String?> lookupDescription,
});
typedef $$InventoryItemsTableUpdateCompanionBuilder = InventoryItemsCompanion
    Function({
  Value<int> id,
  Value<DateTime> dateAdded,
  Value<String?> barcode,
  Value<String> itemDescription,
  Value<ItemType> type,
  Value<double> cost,
  Value<int> quantity,
  Value<String?> platform,
  Value<ItemStatus> status,
  Value<DateTime?> dateSold,
  Value<String?> saleNumber,
  Value<String?> comments,
  Value<String?> imageUrl,
  Value<String?> lookupName,
  Value<String?> lookupDescription,
});

class $$InventoryItemsTableFilterComposer
    extends Composer<_$FlipBinDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateAdded => $composableBuilder(
      column: $table.dateAdded, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemDescription => $composableBuilder(
      column: $table.itemDescription,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ItemType, ItemType, String> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<double> get cost => $composableBuilder(
      column: $table.cost, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get platform => $composableBuilder(
      column: $table.platform, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ItemStatus, ItemStatus, String> get status =>
      $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get dateSold => $composableBuilder(
      column: $table.dateSold, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get saleNumber => $composableBuilder(
      column: $table.saleNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comments => $composableBuilder(
      column: $table.comments, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lookupName => $composableBuilder(
      column: $table.lookupName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lookupDescription => $composableBuilder(
      column: $table.lookupDescription,
      builder: (column) => ColumnFilters(column));
}

class $$InventoryItemsTableOrderingComposer
    extends Composer<_$FlipBinDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateAdded => $composableBuilder(
      column: $table.dateAdded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemDescription => $composableBuilder(
      column: $table.itemDescription,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cost => $composableBuilder(
      column: $table.cost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get platform => $composableBuilder(
      column: $table.platform, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateSold => $composableBuilder(
      column: $table.dateSold, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get saleNumber => $composableBuilder(
      column: $table.saleNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comments => $composableBuilder(
      column: $table.comments, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lookupName => $composableBuilder(
      column: $table.lookupName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lookupDescription => $composableBuilder(
      column: $table.lookupDescription,
      builder: (column) => ColumnOrderings(column));
}

class $$InventoryItemsTableAnnotationComposer
    extends Composer<_$FlipBinDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get dateAdded =>
      $composableBuilder(column: $table.dateAdded, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get itemDescription => $composableBuilder(
      column: $table.itemDescription, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get dateSold =>
      $composableBuilder(column: $table.dateSold, builder: (column) => column);

  GeneratedColumn<String> get saleNumber => $composableBuilder(
      column: $table.saleNumber, builder: (column) => column);

  GeneratedColumn<String> get comments =>
      $composableBuilder(column: $table.comments, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get lookupName => $composableBuilder(
      column: $table.lookupName, builder: (column) => column);

  GeneratedColumn<String> get lookupDescription => $composableBuilder(
      column: $table.lookupDescription, builder: (column) => column);
}

class $$InventoryItemsTableTableManager extends RootTableManager<
    _$FlipBinDatabase,
    $InventoryItemsTable,
    InventoryItem,
    $$InventoryItemsTableFilterComposer,
    $$InventoryItemsTableOrderingComposer,
    $$InventoryItemsTableAnnotationComposer,
    $$InventoryItemsTableCreateCompanionBuilder,
    $$InventoryItemsTableUpdateCompanionBuilder,
    (
      InventoryItem,
      BaseReferences<_$FlipBinDatabase, $InventoryItemsTable, InventoryItem>
    ),
    InventoryItem,
    PrefetchHooks Function()> {
  $$InventoryItemsTableTableManager(
      _$FlipBinDatabase db, $InventoryItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> dateAdded = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<String> itemDescription = const Value.absent(),
            Value<ItemType> type = const Value.absent(),
            Value<double> cost = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<String?> platform = const Value.absent(),
            Value<ItemStatus> status = const Value.absent(),
            Value<DateTime?> dateSold = const Value.absent(),
            Value<String?> saleNumber = const Value.absent(),
            Value<String?> comments = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> lookupName = const Value.absent(),
            Value<String?> lookupDescription = const Value.absent(),
          }) =>
              InventoryItemsCompanion(
            id: id,
            dateAdded: dateAdded,
            barcode: barcode,
            itemDescription: itemDescription,
            type: type,
            cost: cost,
            quantity: quantity,
            platform: platform,
            status: status,
            dateSold: dateSold,
            saleNumber: saleNumber,
            comments: comments,
            imageUrl: imageUrl,
            lookupName: lookupName,
            lookupDescription: lookupDescription,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime dateAdded,
            Value<String?> barcode = const Value.absent(),
            required String itemDescription,
            required ItemType type,
            required double cost,
            Value<int> quantity = const Value.absent(),
            Value<String?> platform = const Value.absent(),
            required ItemStatus status,
            Value<DateTime?> dateSold = const Value.absent(),
            Value<String?> saleNumber = const Value.absent(),
            Value<String?> comments = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> lookupName = const Value.absent(),
            Value<String?> lookupDescription = const Value.absent(),
          }) =>
              InventoryItemsCompanion.insert(
            id: id,
            dateAdded: dateAdded,
            barcode: barcode,
            itemDescription: itemDescription,
            type: type,
            cost: cost,
            quantity: quantity,
            platform: platform,
            status: status,
            dateSold: dateSold,
            saleNumber: saleNumber,
            comments: comments,
            imageUrl: imageUrl,
            lookupName: lookupName,
            lookupDescription: lookupDescription,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$InventoryItemsTable, InventoryItem>(table),
                    BaseReferences<_$FlipBinDatabase, $InventoryItemsTable,
                        InventoryItem>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InventoryItemsTableProcessedTableManager = ProcessedTableManager<
    _$FlipBinDatabase,
    $InventoryItemsTable,
    InventoryItem,
    $$InventoryItemsTableFilterComposer,
    $$InventoryItemsTableOrderingComposer,
    $$InventoryItemsTableAnnotationComposer,
    $$InventoryItemsTableCreateCompanionBuilder,
    $$InventoryItemsTableUpdateCompanionBuilder,
    (
      InventoryItem,
      BaseReferences<_$FlipBinDatabase, $InventoryItemsTable, InventoryItem>
    ),
    InventoryItem,
    PrefetchHooks Function()>;
typedef $$ExpensesTableCreateCompanionBuilder = ExpensesCompanion Function({
  Value<int> id,
  required DateTime date,
  required String merchant,
  Value<String?> receiptImagePath,
  Value<String?> upc,
  required String itemDescription,
  Value<int> quantity,
  required double unitPrice,
  required ExpenseType expenseType,
  Value<double?> taxAmount,
});
typedef $$ExpensesTableUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<int> id,
  Value<DateTime> date,
  Value<String> merchant,
  Value<String?> receiptImagePath,
  Value<String?> upc,
  Value<String> itemDescription,
  Value<int> quantity,
  Value<double> unitPrice,
  Value<ExpenseType> expenseType,
  Value<double?> taxAmount,
});

class $$ExpensesTableFilterComposer
    extends Composer<_$FlipBinDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receiptImagePath => $composableBuilder(
      column: $table.receiptImagePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get upc => $composableBuilder(
      column: $table.upc, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemDescription => $composableBuilder(
      column: $table.itemDescription,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ExpenseType, ExpenseType, String>
      get expenseType => $composableBuilder(
          column: $table.expenseType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<double> get taxAmount => $composableBuilder(
      column: $table.taxAmount, builder: (column) => ColumnFilters(column));
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$FlipBinDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receiptImagePath => $composableBuilder(
      column: $table.receiptImagePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get upc => $composableBuilder(
      column: $table.upc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemDescription => $composableBuilder(
      column: $table.itemDescription,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get expenseType => $composableBuilder(
      column: $table.expenseType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get taxAmount => $composableBuilder(
      column: $table.taxAmount, builder: (column) => ColumnOrderings(column));
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$FlipBinDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get receiptImagePath => $composableBuilder(
      column: $table.receiptImagePath, builder: (column) => column);

  GeneratedColumn<String> get upc =>
      $composableBuilder(column: $table.upc, builder: (column) => column);

  GeneratedColumn<String> get itemDescription => $composableBuilder(
      column: $table.itemDescription, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExpenseType, String> get expenseType =>
      $composableBuilder(
          column: $table.expenseType, builder: (column) => column);

  GeneratedColumn<double> get taxAmount =>
      $composableBuilder(column: $table.taxAmount, builder: (column) => column);
}

class $$ExpensesTableTableManager extends RootTableManager<
    _$FlipBinDatabase,
    $ExpensesTable,
    Expense,
    $$ExpensesTableFilterComposer,
    $$ExpensesTableOrderingComposer,
    $$ExpensesTableAnnotationComposer,
    $$ExpensesTableCreateCompanionBuilder,
    $$ExpensesTableUpdateCompanionBuilder,
    (Expense, BaseReferences<_$FlipBinDatabase, $ExpensesTable, Expense>),
    Expense,
    PrefetchHooks Function()> {
  $$ExpensesTableTableManager(_$FlipBinDatabase db, $ExpensesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> merchant = const Value.absent(),
            Value<String?> receiptImagePath = const Value.absent(),
            Value<String?> upc = const Value.absent(),
            Value<String> itemDescription = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<double> unitPrice = const Value.absent(),
            Value<ExpenseType> expenseType = const Value.absent(),
            Value<double?> taxAmount = const Value.absent(),
          }) =>
              ExpensesCompanion(
            id: id,
            date: date,
            merchant: merchant,
            receiptImagePath: receiptImagePath,
            upc: upc,
            itemDescription: itemDescription,
            quantity: quantity,
            unitPrice: unitPrice,
            expenseType: expenseType,
            taxAmount: taxAmount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime date,
            required String merchant,
            Value<String?> receiptImagePath = const Value.absent(),
            Value<String?> upc = const Value.absent(),
            required String itemDescription,
            Value<int> quantity = const Value.absent(),
            required double unitPrice,
            required ExpenseType expenseType,
            Value<double?> taxAmount = const Value.absent(),
          }) =>
              ExpensesCompanion.insert(
            id: id,
            date: date,
            merchant: merchant,
            receiptImagePath: receiptImagePath,
            upc: upc,
            itemDescription: itemDescription,
            quantity: quantity,
            unitPrice: unitPrice,
            expenseType: expenseType,
            taxAmount: taxAmount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ExpensesTable, Expense>(table),
                    BaseReferences<_$FlipBinDatabase, $ExpensesTable, Expense>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExpensesTableProcessedTableManager = ProcessedTableManager<
    _$FlipBinDatabase,
    $ExpensesTable,
    Expense,
    $$ExpensesTableFilterComposer,
    $$ExpensesTableOrderingComposer,
    $$ExpensesTableAnnotationComposer,
    $$ExpensesTableCreateCompanionBuilder,
    $$ExpensesTableUpdateCompanionBuilder,
    (Expense, BaseReferences<_$FlipBinDatabase, $ExpensesTable, Expense>),
    Expense,
    PrefetchHooks Function()>;
typedef $$BarcodeCacheEntriesTableCreateCompanionBuilder
    = BarcodeCacheEntriesCompanion Function({
  required String barcode,
  Value<String?> productName,
  Value<String?> description,
  Value<String?> imageUrl,
  Value<String?> category,
  required String source,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$BarcodeCacheEntriesTableUpdateCompanionBuilder
    = BarcodeCacheEntriesCompanion Function({
  Value<String> barcode,
  Value<String?> productName,
  Value<String?> description,
  Value<String?> imageUrl,
  Value<String?> category,
  Value<String> source,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$BarcodeCacheEntriesTableFilterComposer
    extends Composer<_$FlipBinDatabase, $BarcodeCacheEntriesTable> {
  $$BarcodeCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$BarcodeCacheEntriesTableOrderingComposer
    extends Composer<_$FlipBinDatabase, $BarcodeCacheEntriesTable> {
  $$BarcodeCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$BarcodeCacheEntriesTableAnnotationComposer
    extends Composer<_$FlipBinDatabase, $BarcodeCacheEntriesTable> {
  $$BarcodeCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$BarcodeCacheEntriesTableTableManager extends RootTableManager<
    _$FlipBinDatabase,
    $BarcodeCacheEntriesTable,
    BarcodeCacheEntry,
    $$BarcodeCacheEntriesTableFilterComposer,
    $$BarcodeCacheEntriesTableOrderingComposer,
    $$BarcodeCacheEntriesTableAnnotationComposer,
    $$BarcodeCacheEntriesTableCreateCompanionBuilder,
    $$BarcodeCacheEntriesTableUpdateCompanionBuilder,
    (
      BarcodeCacheEntry,
      BaseReferences<_$FlipBinDatabase, $BarcodeCacheEntriesTable,
          BarcodeCacheEntry>
    ),
    BarcodeCacheEntry,
    PrefetchHooks Function()> {
  $$BarcodeCacheEntriesTableTableManager(
      _$FlipBinDatabase db, $BarcodeCacheEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BarcodeCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BarcodeCacheEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BarcodeCacheEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> barcode = const Value.absent(),
            Value<String?> productName = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BarcodeCacheEntriesCompanion(
            barcode: barcode,
            productName: productName,
            description: description,
            imageUrl: imageUrl,
            category: category,
            source: source,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String barcode,
            Value<String?> productName = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> category = const Value.absent(),
            required String source,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BarcodeCacheEntriesCompanion.insert(
            barcode: barcode,
            productName: productName,
            description: description,
            imageUrl: imageUrl,
            category: category,
            source: source,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$BarcodeCacheEntriesTable, BarcodeCacheEntry>(
                        table),
                    BaseReferences<_$FlipBinDatabase, $BarcodeCacheEntriesTable,
                        BarcodeCacheEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BarcodeCacheEntriesTableProcessedTableManager = ProcessedTableManager<
    _$FlipBinDatabase,
    $BarcodeCacheEntriesTable,
    BarcodeCacheEntry,
    $$BarcodeCacheEntriesTableFilterComposer,
    $$BarcodeCacheEntriesTableOrderingComposer,
    $$BarcodeCacheEntriesTableAnnotationComposer,
    $$BarcodeCacheEntriesTableCreateCompanionBuilder,
    $$BarcodeCacheEntriesTableUpdateCompanionBuilder,
    (
      BarcodeCacheEntry,
      BaseReferences<_$FlipBinDatabase, $BarcodeCacheEntriesTable,
          BarcodeCacheEntry>
    ),
    BarcodeCacheEntry,
    PrefetchHooks Function()>;

class $FlipBinDatabaseManager {
  final _$FlipBinDatabase _db;
  $FlipBinDatabaseManager(this._db);
  $$InventoryItemsTableTableManager get inventoryItems =>
      $$InventoryItemsTableTableManager(_db, _db.inventoryItems);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$BarcodeCacheEntriesTableTableManager get barcodeCacheEntries =>
      $$BarcodeCacheEntriesTableTableManager(_db, _db.barcodeCacheEntries);
}
