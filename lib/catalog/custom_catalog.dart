import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Custom catalog that uses our own Button (same schema as core, but with
/// spacing so buttons don't touch), an agreement/scale slider for range
/// questions (e.g. Likert), and all other CoreCatalogItems.
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

  /// Agreement / scale slider for questions whose answer is on a range,
  /// e.g. "Strongly disagree" … "Strongly agree", or "Never" … "Always".
  /// Prefer this over multiple buttons when the question is a single scale.
  static final CatalogItem agreementScale = CatalogItem(
    name: 'agreementScale',
    dataSchema: Schema.object(
      description: 'A single question where the user picks one point on a '
          'labeled scale (e.g. agree/disagree, frequency). Use this instead of '
          'multiple choice or several buttons when the answer is on a range.',
      properties: {
        'question': A2uiSchemas.stringReference(
          description: 'The question or prompt text (e.g. "How much do you agree?")',
        ),
        'options': A2uiSchemas.stringArrayReference(
          description: 'Scale labels from one end to the other, e.g. '
              '["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"]',
        ),
        'value': A2uiSchemas.numberReference(
          description: 'Selected index (0-based). Optional; defaults to middle.',
        ),
      },
      required: ['question', 'options'],
    ),
    widgetBuilder: _buildAgreementScale,
    exampleData: [
      () => _exampleScale(
        'How much do you agree with this statement?',
        [
          'Strongly disagree',
          'Disagree',
          'Neutral',
          'Agree',
          'Strongly agree',
        ],
      ),
      () => _exampleScale(
        'How often would you like to work outdoors?',
        ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
      ),
      () => _exampleScale(
        'How interested are you in technical hands-on work?',
        ['Not at all', 'A little', 'Moderately', 'Very', 'Extremely'],
      ),
    ],
  );

  static Widget _buildAgreementScale(CatalogItemContext itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final dc = itemContext.dataContext;

    final questionRef = _asRef(data['question']);
    final optionsRef = _asRef(data['options']);
    final valueRef = _asRef(data['value']);

    final questionNotifier = dc.subscribeToString(questionRef);
    final optionsNotifier = dc.subscribeToObjectArray(optionsRef);
    final valueNotifier = dc.subscribeToValue(valueRef, 'literalNumber');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _AgreementScaleContent(
        itemContext: itemContext,
        dataContext: dc,
        questionNotifier: questionNotifier,
        optionsNotifier: optionsNotifier,
        valueNotifier: valueNotifier,
      ),
    );
  }

  /// Normalize component prop to a ref (JsonMap) so subscribe* get literal or path.
  static JsonMap? _asRef(Object? value) {
    if (value == null) return null;
    if (value is Map<String, Object?>) return value;
    if (value is String) return {'literal': value};
    if (value is num) return {'literalNumber': value};
    if (value is List) return {'literalArray': value};
    return null;
  }

  static String _exampleScale(String question, List<String> options) {
    final middle = (options.length - 1) ~/ 2;
    return '''
{
  "question": {"literal": "$question"},
  "options": {"literalArray": ${options.map((s) => '"$s"').toList()}},
  "value": {"literalNumber": $middle}
}
''';
  }

  /// Builds a catalog with our custom button, agreement scale, and all other core items.
  static Catalog asCatalog() {
    return Catalog(
      [
        button,
        agreementScale,
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

/// Stateful content for the agreement scale so the slider uses local state
/// and responds immediately to drags; still syncs to data model for submit.
class _AgreementScaleContent extends StatefulWidget {
  const _AgreementScaleContent({
    required this.itemContext,
    required this.dataContext,
    required this.questionNotifier,
    required this.optionsNotifier,
    required this.valueNotifier,
  });

  final CatalogItemContext itemContext;
  final DataContext dataContext;
  final ValueListenable<String?> questionNotifier;
  final ValueListenable<List<Object?>?> optionsNotifier;
  final ValueListenable<Object?> valueNotifier;

  @override
  State<_AgreementScaleContent> createState() => _AgreementScaleContentState();
}

class _AgreementScaleContentState extends State<_AgreementScaleContent> {
  /// Local index so the slider thumb updates immediately on drag; the data
  /// model may not notify synchronously.
  int? _localIndex;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.questionNotifier,
      builder: (context, question, _) {
        return ValueListenableBuilder<List<Object?>?>(
          valueListenable: widget.optionsNotifier,
          builder: (context, optionsRaw, _) {
            final options =
                (optionsRaw ?? []).whereType<String>().toList();
            if (options.isEmpty) return const SizedBox.shrink();
            final maxIndex = options.length - 1;
            final middle = (maxIndex / 2).floor();
            final fromNotifier = widget.valueNotifier.value is num
                ? (widget.valueNotifier.value as num).toInt()
                : null;
            final index = (_localIndex ?? fromNotifier ?? middle).clamp(0, maxIndex);
            final theme = Theme.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (question != null && question.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      question,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 48,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: index.toDouble().clamp(0.0, maxIndex.toDouble()),
                      min: 0,
                      max: maxIndex > 0 ? maxIndex.toDouble() : 1.0,
                      divisions: maxIndex > 0 ? maxIndex : null,
                      label: options[index],
                      onChanged: (v) {
                        final i = v.round().clamp(0, maxIndex);
                        setState(() => _localIndex = i);
                        widget.dataContext.update(DataPath('value'), i);
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        options.first,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        options.last,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: FilledButton(
                    onPressed: () {
                      widget.itemContext.dispatchEvent(
                        UserActionEvent(
                          surfaceId: widget.itemContext.surfaceId,
                          name: 'scaleSubmit',
                          sourceComponentId: widget.itemContext.id,
                          context: {
                            'selectedIndex': index,
                            'selectedLabel': options[index],
                          },
                        ),
                      );
                    },
                    child: const Text('Submit'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
