/// Material product for the add-materials flow (Figma 2021:4128).
class PostMaterialOption {
  const PostMaterialOption({
    required this.id,
    required this.name,
    required this.category,
  });

  final String id;
  final String name;
  final String category;
}

abstract final class PostMaterialOptions {
  PostMaterialOptions._();

  static const categories = <String>[
    'Paint',
    'Brushes',
    'Surfaces',
    'Drawing & Sketching',
    'Sculpture & 3D',
  ];

  static const all = <PostMaterialOption>[
    // Paint
    PostMaterialOption(
      id: 'winsor_newton_professional_watercolour',
      name: 'Winsor & Newton Professional Watercolour',
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'golden_heavy_body_acrylic',
      name: 'Golden Heavy Body Acrylic',
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'gamblin_artists_oil_color',
      name: "Gamblin Artist's Oil Color",
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'm_graham_oil_paint',
      name: 'M. Graham Oil Paint',
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'liquitex_basics_acrylic',
      name: 'Liquitex Basics Acrylic',
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'daniel_smith_extra_fine_watercolor',
      name: 'Daniel Smith Extra Fine Watercolor',
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'sennelier_oil_pastel',
      name: 'Sennelier Oil Pastel',
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'holbein_gouache',
      name: 'Holbein Gouache',
      category: 'Paint',
    ),
    PostMaterialOption(
      id: 'speedball_screen_printing_ink',
      name: 'Speedball Screen Printing Ink',
      category: 'Paint',
    ),

    // Brushes
    PostMaterialOption(
      id: 'princeton_velvetouch_round',
      name: 'Princeton Velvetouch Round',
      category: 'Brushes',
    ),
    PostMaterialOption(
      id: 'winsor_newton_series_7_kolinsky_sable',
      name: 'Winsor & Newton Series 7 Kolinsky Sable',
      category: 'Brushes',
    ),
    PostMaterialOption(
      id: 'escoda_clasico_flat',
      name: 'Escoda Clásico Flat',
      category: 'Brushes',
    ),
    PostMaterialOption(
      id: 'da_vinci_maestro_kolinsky',
      name: 'Da Vinci Maestro Kolinsky',
      category: 'Brushes',
    ),
    PostMaterialOption(
      id: 'robert_simmons_signet_round',
      name: 'Robert Simmons Signet Round',
      category: 'Brushes',
    ),
    PostMaterialOption(
      id: 'silver_brush_black_velvet',
      name: 'Silver Brush Black Velvet',
      category: 'Brushes',
    ),
    PostMaterialOption(
      id: 'rosemary_co_series_302',
      name: 'Rosemary & Co Series 302',
      category: 'Brushes',
    ),
    PostMaterialOption(
      id: 'isabey_mongoose_bright',
      name: 'Isabey Mongoose Bright',
      category: 'Brushes',
    ),

    // Surfaces
    PostMaterialOption(
      id: 'fredrix_canvas',
      name: 'Fredrix Canvas',
      category: 'Surfaces',
    ),
    PostMaterialOption(
      id: 'arches_watercolor_paper',
      name: 'Arches Watercolor Paper',
      category: 'Surfaces',
    ),
    PostMaterialOption(
      id: 'strathmore_bristol_board',
      name: 'Strathmore Bristol Board',
      category: 'Surfaces',
    ),
    PostMaterialOption(
      id: 'claessens_linen',
      name: 'Claessens Linen',
      category: 'Surfaces',
    ),
    PostMaterialOption(
      id: 'ampersand_wood_panel',
      name: 'Ampersand Wood Panel',
      category: 'Surfaces',
    ),
    PostMaterialOption(
      id: 'canson_mi_teintes_paper',
      name: 'Canson Mi-Teintes Paper',
      category: 'Surfaces',
    ),
    PostMaterialOption(
      id: 'yupo_synthetic_paper',
      name: 'Yupo Synthetic Paper',
      category: 'Surfaces',
    ),
    PostMaterialOption(
      id: 'raymar_panels',
      name: 'RayMar Panels',
      category: 'Surfaces',
    ),

    // Drawing & Sketching
    PostMaterialOption(
      id: 'faber_castell_polychromos',
      name: 'Faber-Castell Polychromos',
      category: 'Drawing & Sketching',
    ),
    PostMaterialOption(
      id: 'staedtler_mars_lumograph',
      name: 'Staedtler Mars Lumograph',
      category: 'Drawing & Sketching',
    ),
    PostMaterialOption(
      id: 'generals_charcoal',
      name: "General's Charcoal",
      category: 'Drawing & Sketching',
    ),
    PostMaterialOption(
      id: 'prismacolor_premier_colored_pencil',
      name: 'Prismacolor Premier Colored Pencil',
      category: 'Drawing & Sketching',
    ),
    PostMaterialOption(
      id: 'derwent_pastel_pencil',
      name: 'Derwent Pastel Pencil',
      category: 'Drawing & Sketching',
    ),
    PostMaterialOption(
      id: 'copic_marker',
      name: 'Copic Marker',
      category: 'Drawing & Sketching',
    ),
    PostMaterialOption(
      id: 'sakura_pigma_micron_pen',
      name: 'Sakura Pigma Micron Pen',
      category: 'Drawing & Sketching',
    ),
    PostMaterialOption(
      id: 'conte_a_paris_crayon',
      name: 'Conté à Paris Crayon',
      category: 'Drawing & Sketching',
    ),

    // Sculpture & 3D
    PostMaterialOption(
      id: 'laguna_clay_stoneware',
      name: 'Laguna Clay Stoneware',
      category: 'Sculpture & 3D',
    ),
    PostMaterialOption(
      id: 'amaco_air_dry_clay',
      name: 'Amaco Air-Dry Clay',
      category: 'Sculpture & 3D',
    ),
    PostMaterialOption(
      id: 'sculpey_polymer_clay',
      name: 'Sculpey Polymer Clay',
      category: 'Sculpture & 3D',
    ),
    PostMaterialOption(
      id: 'plaster_of_paris_us_gypsum',
      name: 'Plaster of Paris (US Gypsum)',
      category: 'Sculpture & 3D',
    ),
    PostMaterialOption(
      id: 'smooth_on_resin',
      name: 'Smooth-On Resin',
      category: 'Sculpture & 3D',
    ),
    PostMaterialOption(
      id: 'environtex_lite_epoxy',
      name: 'EnvironTex Lite Epoxy',
      category: 'Sculpture & 3D',
    ),
    PostMaterialOption(
      id: 'chavant_sculpting',
      name: 'Chavant Sculpting',
      category: 'Sculpture & 3D',
    ),
  ];

  static Map<String, List<PostMaterialOption>> get byCategory => {
    for (final category in categories)
      category: all.where((m) => m.category == category).toList(),
  };

  static PostMaterialOption? byId(String id) {
    for (final material in all) {
      if (material.id == id) return material;
    }
    return null;
  }
}
