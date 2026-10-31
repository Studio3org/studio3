/// Simple id + label option for create-post pickers.
class PostPickerOption {
  const PostPickerOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

abstract final class PostMediumOptions {
  PostMediumOptions._();

  /// Board order (`PostMedium`), then the rest.
  static const all = <PostPickerOption>[
    PostPickerOption(id: 'oil', name: 'Oil'),
    PostPickerOption(id: 'acrylic', name: 'Acrylic'),
    PostPickerOption(id: 'watercolor', name: 'Watercolor'),
    PostPickerOption(id: 'gouache', name: 'Gouache'),
    PostPickerOption(id: 'mixed_media', name: 'Mixed media'),
    PostPickerOption(id: 'encaustic', name: 'Encaustic'),
    PostPickerOption(id: 'photography', name: 'Photography'),
    PostPickerOption(id: 'printmaking', name: 'Printmaking'),
    PostPickerOption(id: 'sculpture', name: 'Sculpture'),
    PostPickerOption(id: 'tempera', name: 'Tempera'),
    PostPickerOption(id: 'fresco', name: 'Fresco'),
    PostPickerOption(id: 'ink', name: 'Ink'),
    PostPickerOption(id: 'charcoal', name: 'Charcoal'),
    PostPickerOption(id: 'pastel', name: 'Pastel'),
    PostPickerOption(id: 'digital', name: 'Digital'),
  ];

  static PostPickerOption? byId(String id) {
    for (final option in all) {
      if (option.id == id) return option;
    }
    return null;
  }
}

abstract final class PostStyleOptions {
  PostStyleOptions._();

  static const maxSelections = 3;

  static const all = <PostPickerOption>[
    PostPickerOption(id: 'abstract', name: 'Abstract'),
    PostPickerOption(id: 'expressionist', name: 'Expressionist'),
    PostPickerOption(id: 'figurative', name: 'Figurative'),
    PostPickerOption(id: 'geometric', name: 'Geometric'),
    PostPickerOption(id: 'landscape', name: 'Landscape'),
    PostPickerOption(id: 'minimalist', name: 'Minimalist'),
    PostPickerOption(id: 'portrait', name: 'Portrait'),
    PostPickerOption(id: 'surrealist', name: 'Surrealist'),
    PostPickerOption(id: 'realist', name: 'Realist'),
    PostPickerOption(id: 'conceptual', name: 'Conceptual'),
    PostPickerOption(id: 'street', name: 'Street art'),
    PostPickerOption(id: 'pop', name: 'Pop art'),
  ];

  static PostPickerOption? byId(String id) {
    for (final option in all) {
      if (option.id == id) return option;
    }
    return null;
  }
}

abstract final class EventCategoryOptions {
  EventCategoryOptions._();

  /// Every category the server accepts (`EVENT_CATEGORIES`), in sentence case as the hosting
  /// boards write them (`HostDetails` "Gallery walk").
  static const all = <PostPickerOption>[
    PostPickerOption(id: 'gallery_walk', name: 'Gallery walk'),
    PostPickerOption(id: 'exhibition', name: 'Exhibition'),
    PostPickerOption(id: 'workshop', name: 'Workshop'),
    PostPickerOption(id: 'talks_panels', name: 'Talks and panels'),
    PostPickerOption(id: 'demos_performances', name: 'Demos and performances'),
    PostPickerOption(id: 'studio_visit', name: 'Studio visit'),
    PostPickerOption(id: 'popup', name: 'Pop-up'),
    PostPickerOption(id: 'market', name: 'Market'),
    PostPickerOption(id: 'auction', name: 'Auction'),
    PostPickerOption(id: 'other', name: 'Other'),
  ];

  static PostPickerOption? byId(String id) {
    for (final option in all) {
      if (option.id == id) return option;
    }
    return null;
  }
}
