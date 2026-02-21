import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// Custom catalog that uses our own Button (same schema as core, but with
/// spacing so buttons don't touch) and all other CoreCatalogItems.
abstract final class CustomCatalogItems {
  CustomCatalogItems._();

  /// Custom Button: same as CoreCatalogItems.button but wrapped with
  /// padding so there is margin between adjacent buttons.
  static final CatalogItem button = CatalogItem(
    name: CoreCatalogItems.button.name,
    dataSchema: CoreCatalogItems.button.dataSchema,
    widgetBuilder: (itemContext) {
      final coreWidget = CoreCatalogItems.button.widgetBuilder(itemContext);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: coreWidget,
      );
    },
    exampleData: CoreCatalogItems.button.exampleData,
  );

  /// Builds a catalog with our custom button and all other core items.
  static Catalog asCatalog() {
    return Catalog(
      [
        button,
        CoreCatalogItems.audioPlayer,
        CoreCatalogItems.card,
        CoreCatalogItems.checkBox,
        CoreCatalogItems.column,
        CoreCatalogItems.dateTimeInput,
        CoreCatalogItems.divider,
        CoreCatalogItems.icon,
        CoreCatalogItems.image,
        CoreCatalogItems.imageFixedSize,
        CoreCatalogItems.list,
        CoreCatalogItems.modal,
        CoreCatalogItems.multipleChoice,
        CoreCatalogItems.row,
        CoreCatalogItems.slider,
        CoreCatalogItems.tabs,
        CoreCatalogItems.text,
        CoreCatalogItems.textField,
        CoreCatalogItems.video,
      ],
      catalogId: 'a2ui_jobs_v2.custom_catalog',
    );
  }
}
