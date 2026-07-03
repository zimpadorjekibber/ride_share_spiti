import 'package:flutter/material.dart';
import '../services/spiti_routes.dart';

/// From/To text field with Spiti place suggestions.
///
/// Typing 2+ letters shows matching villages/towns from the route matcher's
/// canonical list, so searches and broadcasts always use spellings the
/// corridor matcher ([SpitiRoutes]) understands — no more missed rides
/// because of "Kasa" / "Kajaa" typos.
///
/// The caller owns the [controller] and supplies its own [decoration] so the
/// field visually matches the surrounding form.
class PlaceAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final Color accent;
  final ValueChanged<String>? onChanged; // fires on typing AND on selection
  final String? Function(String?)? validator;

  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.accent,
    this.style,
    this.onChanged,
    this.validator,
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _optionsFor(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    if (q.length < 2) return const Iterable<String>.empty();
    final starts = <String>[];
    final contains = <String>[];
    for (final place in SpitiRoutes.knownPlaces) {
      final lp = place.toLowerCase();
      if (lp == q) continue; // already typed exactly — no popup needed
      if (lp.startsWith(q)) {
        starts.add(place);
      } else if (lp.contains(q)) {
        contains.add(place);
      }
    }
    return [...starts, ...contains].take(6);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: _optionsFor,
        onSelected: (place) => widget.onChanged?.call(place),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: widget.style,
            decoration: widget.decoration,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: (_) => onFieldSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              width: constraints.maxWidth,
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: onSurface.withValues(alpha: 0.08)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 16, color: widget.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
