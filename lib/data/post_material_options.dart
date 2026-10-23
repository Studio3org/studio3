/// Whether a catalog entry is something the work is made of or something used to make it
/// (`PostMaterials` groups them; `PostMaterialsSearch` tags them).
enum MaterialKind { material, tool }

/// A catalog product: a type ("Oil paint") and a brand ("Winsor & Newton"), so entries can
/// link to Marketplace stores later (`NotePostMaterials`). [name] is what is saved on the
/// piece.
class PostMaterialOption {
  const PostMaterialOption({
    required this.id,
    required this.type,
    required this.brand,
    required this.kind,
  });

  /// An artist's own entry when nothing in the catalog matches.
  factory PostMaterialOption.custom(String text) => PostMaterialOption(
    id: 'custom:${text.trim()}',
    type: text.trim(),
    brand: '',
    kind: MaterialKind.material,
  );

  final String id;
  final String type;
  final String brand;
  final MaterialKind kind;

  bool get isCustom => id.startsWith('custom:');

  /// "Oil paint · Winsor & Newton", or the type alone for an own entry.
  String get name => brand.isEmpty ? type : '$type · $brand';

  @override
  bool operator ==(Object other) => other is PostMaterialOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The materials and tools catalog. Needs an owner to keep it current (`NotePostMaterials`).
abstract final class PostMaterialOptions {
  PostMaterialOptions._();

  static const _m = MaterialKind.material;
  static const _t = MaterialKind.tool;

  static const all = <PostMaterialOption>[
    // Paint and mediums
    PostMaterialOption(id: 'winsor_newton_oil_paint', type: 'Oil paint', brand: 'Winsor & Newton', kind: _m),
    PostMaterialOption(id: 'gamblin_artists_oil_color', type: 'Oil paint', brand: 'Gamblin', kind: _m),
    PostMaterialOption(id: 'michael_harding_oil_paint', type: 'Oil paint', brand: 'Michael Harding', kind: _m),
    PostMaterialOption(id: 'm_graham_oil_paint', type: 'Oil paint', brand: 'M. Graham', kind: _m),
    PostMaterialOption(id: 'sennelier_oil_pastel', type: 'Oil pastel', brand: 'Sennelier', kind: _m),
    PostMaterialOption(id: 'golden_heavy_body_acrylic', type: 'Acrylic paint', brand: 'Golden', kind: _m),
    PostMaterialOption(id: 'liquitex_basics_acrylic', type: 'Acrylic paint', brand: 'Liquitex', kind: _m),
    PostMaterialOption(id: 'winsor_newton_professional_watercolour', type: 'Watercolor paint', brand: 'Winsor & Newton', kind: _m),
    PostMaterialOption(id: 'daniel_smith_extra_fine_watercolor', type: 'Watercolor paint', brand: 'Daniel Smith', kind: _m),
    PostMaterialOption(id: 'holbein_gouache', type: 'Gouache', brand: 'Holbein', kind: _m),
    PostMaterialOption(id: 'speedball_screen_printing_ink', type: 'Screen printing ink', brand: 'Speedball', kind: _m),
    PostMaterialOption(id: 'gamblin_cold_wax_medium', type: 'Cold wax medium', brand: 'Gamblin', kind: _m),
    PostMaterialOption(id: 'gamblin_gamsol', type: 'Gamsol', brand: 'Gamblin', kind: _m),
    PostMaterialOption(id: 'liquitex_gesso', type: 'Gesso', brand: 'Liquitex', kind: _m),

    // Surfaces
    PostMaterialOption(id: 'belle_arti_linen_canvas', type: 'Linen canvas', brand: 'Belle Arti', kind: _m),
    PostMaterialOption(id: 'claessens_linen', type: 'Linen canvas', brand: 'Claessens', kind: _m),
    PostMaterialOption(id: 'fredrix_canvas', type: 'Cotton canvas', brand: 'Fredrix', kind: _m),
    PostMaterialOption(id: 'raymar_panels', type: 'Canvas panel', brand: 'RayMar', kind: _m),
    PostMaterialOption(id: 'ampersand_wood_panel', type: 'Wood panel', brand: 'Ampersand', kind: _m),
    PostMaterialOption(id: 'arches_watercolor_paper', type: 'Watercolor paper', brand: 'Arches', kind: _m),
    PostMaterialOption(id: 'strathmore_bristol_board', type: 'Bristol board', brand: 'Strathmore', kind: _m),
    PostMaterialOption(id: 'canson_mi_teintes_paper', type: 'Pastel paper', brand: 'Canson', kind: _m),
    PostMaterialOption(id: 'yupo_synthetic_paper', type: 'Synthetic paper', brand: 'Yupo', kind: _m),

    // Drawing
    PostMaterialOption(id: 'faber_castell_polychromos', type: 'Colored pencil', brand: 'Faber-Castell', kind: _m),
    PostMaterialOption(id: 'prismacolor_premier_colored_pencil', type: 'Colored pencil', brand: 'Prismacolor', kind: _m),
    PostMaterialOption(id: 'staedtler_mars_lumograph', type: 'Graphite pencil', brand: 'Staedtler', kind: _m),
    PostMaterialOption(id: 'generals_charcoal', type: 'Charcoal', brand: "General's", kind: _m),
    PostMaterialOption(id: 'derwent_pastel_pencil', type: 'Pastel pencil', brand: 'Derwent', kind: _m),
    PostMaterialOption(id: 'conte_a_paris_crayon', type: 'Conté crayon', brand: 'Conté à Paris', kind: _m),
    PostMaterialOption(id: 'copic_marker', type: 'Marker', brand: 'Copic', kind: _m),
    PostMaterialOption(id: 'sakura_pigma_micron_pen', type: 'Fineliner pen', brand: 'Sakura', kind: _m),

    // Sculpture
    PostMaterialOption(id: 'laguna_clay_stoneware', type: 'Stoneware clay', brand: 'Laguna', kind: _m),
    PostMaterialOption(id: 'amaco_air_dry_clay', type: 'Air-dry clay', brand: 'Amaco', kind: _m),
    PostMaterialOption(id: 'sculpey_polymer_clay', type: 'Polymer clay', brand: 'Sculpey', kind: _m),
    PostMaterialOption(id: 'chavant_sculpting', type: 'Modeling clay', brand: 'Chavant', kind: _m),
    PostMaterialOption(id: 'plaster_of_paris_us_gypsum', type: 'Plaster', brand: 'US Gypsum', kind: _m),
    PostMaterialOption(id: 'smooth_on_resin', type: 'Casting resin', brand: 'Smooth-On', kind: _m),
    PostMaterialOption(id: 'environtex_lite_epoxy', type: 'Epoxy resin', brand: 'EnvironTex', kind: _m),

    // Tools
    PostMaterialOption(id: 'princeton_filbert_brush', type: 'Filbert brush', brand: 'Princeton', kind: _t),
    PostMaterialOption(id: 'princeton_oil_brush_set', type: 'Oil painting brush set', brand: 'Princeton', kind: _t),
    PostMaterialOption(id: 'princeton_velvetouch_round', type: 'Round brush', brand: 'Princeton', kind: _t),
    PostMaterialOption(id: 'robert_simmons_signet_round', type: 'Round brush', brand: 'Robert Simmons', kind: _t),
    PostMaterialOption(id: 'silver_brush_black_velvet', type: 'Round brush', brand: 'Silver Brush', kind: _t),
    PostMaterialOption(id: 'winsor_newton_series_7_kolinsky_sable', type: 'Sable brush', brand: 'Winsor & Newton', kind: _t),
    PostMaterialOption(id: 'da_vinci_maestro_kolinsky', type: 'Sable brush', brand: 'Da Vinci', kind: _t),
    PostMaterialOption(id: 'rosemary_co_series_302', type: 'Sable brush', brand: 'Rosemary & Co', kind: _t),
    PostMaterialOption(id: 'escoda_clasico_flat', type: 'Flat brush', brand: 'Escoda', kind: _t),
    PostMaterialOption(id: 'isabey_mongoose_bright', type: 'Bright brush', brand: 'Isabey', kind: _t),
    PostMaterialOption(id: 'liquitex_palette_knife', type: 'Palette knife', brand: 'Liquitex', kind: _t),
  ];

  static PostMaterialOption? byId(String id) {
    if (id.startsWith('custom:')) return PostMaterialOption.custom(id.substring(7));
    for (final material in all) {
      if (material.id == id) return material;
    }
    return null;
  }

  /// Catalog entries whose type or brand contains [query], type matches first.
  static List<PostMaterialOption> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final byType = all.where((m) => m.type.toLowerCase().contains(q));
    final byBrand = all.where(
      (m) => !m.type.toLowerCase().contains(q) && m.brand.toLowerCase().contains(q),
    );
    return [...byType, ...byBrand];
  }
}
