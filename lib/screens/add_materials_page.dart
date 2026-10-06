import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/post_material_options.dart';
import '../data/post_media_assets.dart';
import '../screens/profile/profile_constants.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/create_flow/create_flow_widgets.dart';
import '../theme/app_fonts.dart';

/// Piece posting materials: empty state → custom add form → list.
class AddMaterialsPage extends StatefulWidget {
  const AddMaterialsPage({
    super.key,
    required this.initialMaterials,
  });

  final List<PostMaterialOption> initialMaterials;

  @override
  State<AddMaterialsPage> createState() => _AddMaterialsPageState();
}

class _AddMaterialsPageState extends State<AddMaterialsPage> {
  late List<PostMaterialOption> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<PostMaterialOption>.from(widget.initialMaterials);
  }

  void _popWithSelection() => Navigator.pop(context, _selected);

  Future<void> _openAddForm() async {
    final created = await Navigator.push<PostMaterialOption>(
      context,
      MaterialPageRoute(builder: (_) => const _AddMaterialFormPage()),
    );
    if (created != null && mounted) {
      setState(() => _selected.add(created));
    }
  }

  void _removeAt(int index) {
    setState(() => _selected.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final empty = _selected.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithSelection();
      },
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        body: Column(
          children: [
            _MaterialsBanner(
              topInset: topInset,
              onBack: _popWithSelection,
            ),
            Expanded(
              child: empty
                  ? _EmptyMaterials(onAdd: _openAddForm)
                  : _MaterialsList(
                      materials: _selected,
                      bottomInset: bottomInset,
                      onRemove: _removeAt,
                      onAddAnother: _openAddForm,
                      onDone: _popWithSelection,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialsBanner extends StatelessWidget {
  const _MaterialsBanner({required this.topInset, required this.onBack});

  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeFeedTokens.background,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: 53,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onBack,
                    behavior: HitTestBehavior.opaque,
                    child: SvgPicture.asset(
                      PostMediaAssets.createBannerBack,
                      width: 7,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        HomeFeedTokens.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                Text(
                  'Materials',
                  style: kProfileGeist(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMaterials extends StatelessWidget {
  const _EmptyMaterials({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing added yet',
              textAlign: TextAlign.center,
              style: kProfileGeist(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8C8880),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Oil, ink, linen, whatever it was. Add it here',
              textAlign: TextAlign.center,
              style: kProfileGeist(
                fontSize: 13,
                color: const Color(0xFF8C8880),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HomeFeedTokens.textPrimary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add,
                      size: 16,
                      color: HomeFeedTokens.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add materials',
                      style: kProfileGeist(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialsList extends StatelessWidget {
  const _MaterialsList({
    required this.materials,
    required this.bottomInset,
    required this.onRemove,
    required this.onAddAnother,
    required this.onDone,
  });

  final List<PostMaterialOption> materials;
  final double bottomInset;
  final ValueChanged<int> onRemove;
  final VoidCallback onAddAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            children: [
              for (var i = 0; i < materials.length; i++) ...[
                _MaterialListRow(
                  material: materials[i],
                  onRemove: () => onRemove(i),
                ),
                const Divider(height: 1, thickness: 0.5, color: Color(0xFFC8C5BC)),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onAddAnother,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add,
                      size: 16,
                      color: HomeFeedTokens.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add another',
                      style: kProfileGeist(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ).copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: HomeFeedTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset + 16),
          child: CreateFlowBottomButton(
            label: 'Done',
            height: 40,
            backgroundColor: HomeFeedTokens.neutral800,
            textColor: HomeFeedTokens.textInverse,
            onTap: onDone,
            child: Text(
              'Done',
              style: AppFonts.geist(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: HomeFeedTokens.textInverse,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MaterialListRow extends StatelessWidget {
  const _MaterialListRow({required this.material, required this.onRemove});

  final PostMaterialOption material;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final brand = material.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  style: kProfileGeist(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (brand != null && brand.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    brand,
                    style: kProfileGeist(
                      fontSize: 13,
                      color: const Color(0xFF8C8880),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: SvgPicture.asset(
                PostMediaAssets.createCloseIcon,
                width: 12,
                height: 12,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF8C8880),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMaterialFormPage extends StatefulWidget {
  const _AddMaterialFormPage();

  @override
  State<_AddMaterialFormPage> createState() => _AddMaterialFormPageState();
}

class _AddMaterialFormPageState extends State<_AddMaterialFormPage> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool get _canAdd => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canAdd) return;
    Navigator.pop(
      context,
      PostMaterialOption.custom(
        name: _nameController.text,
        brand: _brandController.text,
        description: _descriptionController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          ColoredBox(
            color: HomeFeedTokens.background,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                height: 53,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: SvgPicture.asset(
                          PostMediaAssets.createCloseIcon,
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                            HomeFeedTokens.textPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _canAdd ? _submit : null,
                        child: Text(
                          'Add',
                          style: kProfileGeist(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _canAdd
                                ? HomeFeedTokens.textPrimary
                                : const Color(0xFFC8C5BC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                _UnderlineField(
                  label: 'Material',
                  hint: 'Oil paint',
                  controller: _nameController,
                  textColor: HomeFeedTokens.textPrimary,
                ),
                const SizedBox(height: 28),
                _UnderlineField(
                  label: 'Brand · optional',
                  hint: 'e.g. Winsor & Newton',
                  controller: _brandController,
                  textColor: const Color(0xFF8C8880),
                ),
                const SizedBox(height: 28),
                _UnderlineField(
                  label: 'Description · optional',
                  hint: 'e.g. Applied thick with a palette knife',
                  controller: _descriptionController,
                  textColor: const Color(0xFF8C8880),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.textColor,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: kProfileGeist(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8C8880),
          ),
        ),
        TextField(
          controller: controller,
          cursorColor: HomeFeedTokens.textPrimary,
          style: AppFonts.geist(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: HomeFeedTokens.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppFonts.geist(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textColor.withValues(alpha: 0.55),
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: HomeFeedTokens.textPrimary),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: HomeFeedTokens.textPrimary),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: HomeFeedTokens.textPrimary, width: 1.2),
            ),
            contentPadding: const EdgeInsets.only(top: 8, bottom: 10),
          ),
        ),
      ],
    );
  }
}
