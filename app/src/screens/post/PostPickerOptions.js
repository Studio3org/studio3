/**
 * Shared selection option definitions matching Flutter app data sources:
 * - lib/data/post_picker_options.dart
 * - lib/data/post_material_options.dart
 * - lib/data/post_location_options.dart
 */

export const MEDIUM_OPTIONS = [
  { id: 'acrylic', name: 'Acrylic' },
  { id: 'encaustic', name: 'Encaustic' },
  { id: 'fresco', name: 'Fresco' },
  { id: 'gouache', name: 'Gouache' },
  { id: 'oil', name: 'Oil' },
  { id: 'tempera', name: 'Tempera' },
  { id: 'watercolor', name: 'Watercolor' },
  { id: 'ink', name: 'Ink' },
  { id: 'charcoal', name: 'Charcoal' },
  { id: 'pastel', name: 'Pastel' },
  { id: 'mixed_media', name: 'Mixed media' },
  { id: 'digital', name: 'Digital' },
];

export const STYLE_OPTIONS = [
  { id: 'abstract', name: 'Abstract' },
  { id: 'expressionist', name: 'Expressionist' },
  { id: 'figurative', name: 'Figurative' },
  { id: 'geometric', name: 'Geometric' },
  { id: 'landscape', name: 'Landscape' },
  { id: 'minimalist', name: 'Minimalist' },
  { id: 'portrait', name: 'Portrait' },
  { id: 'surrealist', name: 'Surrealist' },
  { id: 'realist', name: 'Realist' },
  { id: 'conceptual', name: 'Conceptual' },
  { id: 'street', name: 'Street art' },
  { id: 'pop', name: 'Pop art' },
];

export const MATERIAL_CATEGORIES = ['Paint', 'Brushes', 'Surfaces', 'Drawing & Sketching', 'Sculpture & 3D'];

export const MATERIAL_OPTIONS = [
  { id: 'winsor_newton_professional_watercolour', name: 'Winsor & Newton Professional Watercolour', category: 'Paint' },
  { id: 'golden_heavy_body_acrylic', name: 'Golden Heavy Body Acrylic', category: 'Paint' },
  { id: 'gamblin_artists_oil_color', name: "Gamblin Artist's Oil Color", category: 'Paint' },
  { id: 'm_graham_oil_paint', name: 'M. Graham Oil Paint', category: 'Paint' },
  { id: 'liquitex_basics_acrylic', name: 'Liquitex Basics Acrylic', category: 'Paint' },
  { id: 'daniel_smith_extra_fine_watercolor', name: 'Daniel Smith Extra Fine Watercolor', category: 'Paint' },
  { id: 'sennelier_oil_pastel', name: 'Sennelier Oil Pastel', category: 'Paint' },
  { id: 'holbein_gouache', name: 'Holbein Gouache', category: 'Paint' },
  { id: 'speedball_screen_printing_ink', name: 'Speedball Screen Printing Ink', category: 'Paint' },

  { id: 'princeton_velvetouch_round', name: 'Princeton Velvetouch Round', category: 'Brushes' },
  { id: 'winsor_newton_series_7_kolinsky_sable', name: 'Winsor & Newton Series 7 Kolinsky Sable', category: 'Brushes' },
  { id: 'escoda_clasico_flat', name: 'Escoda Clásico Flat', category: 'Brushes' },
  { id: 'da_vinci_maestro_kolinsky', name: 'Da Vinci Maestro Kolinsky', category: 'Brushes' },
  { id: 'robert_simmons_signet_round', name: 'Robert Simmons Signet Round', category: 'Brushes' },
  { id: 'silver_brush_black_velvet', name: 'Silver Brush Black Velvet', category: 'Brushes' },

  { id: 'fredrix_canvas', name: 'Fredrix Canvas', category: 'Surfaces' },
  { id: 'arches_watercolor_paper', name: 'Arches Watercolor Paper', category: 'Surfaces' },
  { id: 'strathmore_bristol_board', name: 'Strathmore Bristol Board', category: 'Surfaces' },
  { id: 'claessens_linen', name: 'Claessens Linen', category: 'Surfaces' },
  { id: 'ampersand_wood_panel', name: 'Ampersand Wood Panel', category: 'Surfaces' },

  { id: 'faber_castell_polychromos', name: 'Faber-Castell Polychromos', category: 'Drawing & Sketching' },
  { id: 'staedtler_mars_lumograph', name: 'Staedtler Mars Lumograph', category: 'Drawing & Sketching' },
  { id: 'generals_charcoal', name: "General's Charcoal", category: 'Drawing & Sketching' },
  { id: 'prismacolor_premier_colored_pencil', name: 'Prismacolor Premier Colored Pencil', category: 'Drawing & Sketching' },

  { id: 'laguna_clay_stoneware', name: 'Laguna Clay Stoneware', category: 'Sculpture & 3D' },
  { id: 'amaco_air_dry_clay', name: 'Amaco Air-Dry Clay', category: 'Sculpture & 3D' },
  { id: 'sculpey_polymer_clay', name: 'Sculpey Polymer Clay', category: 'Sculpture & 3D' },
];

export const LOCATION_OPTIONS = [
  { id: 'nyc', name: 'New York, NY, USA' },
  { id: 'london', name: 'London, United Kingdom' },
  { id: 'paris', name: 'Paris, France' },
  { id: 'tokyo', name: 'Tokyo, Japan' },
  { id: 'berlin', name: 'Berlin, Germany' },
  { id: 'la', name: 'Los Angeles, CA, USA' },
  { id: 'sf', name: 'San Francisco, CA, USA' },
  { id: 'milan', name: 'Milan, Italy' },
];

/** lib/data/post_picker_options.dart's EventCategoryOptions. */
export const EVENT_CATEGORY_OPTIONS = [
  { id: 'workshop', name: 'Workshop' },
  { id: 'gallery_walk', name: 'Gallery Walk' },
  { id: 'exhibition', name: 'Exhibition' },
  { id: 'talks_panels', name: 'Talks & Panels' },
  { id: 'demos_performances', name: 'Demos & Performances' },
];
