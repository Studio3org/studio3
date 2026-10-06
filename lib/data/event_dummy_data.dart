/// Local dummy events for the Events tab until a real API exists.
class DummyEventArtist {
  const DummyEventArtist({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;

  Map<String, dynamic> toJson() => {'name': name, 'avatarUrl': avatarUrl};

  factory DummyEventArtist.fromJson(Map<String, dynamic> json) =>
      DummyEventArtist(
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '',
      );
}

class DummyEventFaq {
  const DummyEventFaq({required this.question, required this.answer});

  final String question;
  final String answer;

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory DummyEventFaq.fromJson(Map<String, dynamic> json) => DummyEventFaq(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );
}

class DummyEvent {
  const DummyEvent({
    required this.id,
    required this.title,
    required this.venue,
    required this.priceLabel,
    required this.whenLabel,
    required this.imageUrl,
    this.kicker = 'GALLERY WALK',
    this.hostName = 'Amara Osmei',
    this.hostAvatarUrl = 'https://picsum.photos/seed/event-host-amara/80/80',
    this.details = _kDefaultDetails,
    this.whenFullLabel,
    this.address = '1414 Dragon St, Dallas, TX 75201, USA',
    this.mapImageUrl = 'https://picsum.photos/seed/event-map-dallas/900/520',
    this.artists = _kDefaultArtists,
    this.pieceImageUrls = _kDefaultPieces,
    this.faqs = _kDefaultFaqs,
    this.saved = false,
  });

  final String id;
  final String title;
  final String venue;
  final String priceLabel;
  final String whenLabel;
  final String imageUrl;
  final String kicker;
  final String hostName;
  final String hostAvatarUrl;
  final String details;
  final String? whenFullLabel;
  final String address;
  final String mapImageUrl;
  final List<DummyEventArtist> artists;
  final List<String> pieceImageUrls;
  final List<DummyEventFaq> faqs;
  final bool saved;

  String get venueLine => '$venue · $priceLabel';

  String get scheduleLine => whenFullLabel ?? whenLabel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'venue': venue,
        'priceLabel': priceLabel,
        'whenLabel': whenLabel,
        'imageUrl': imageUrl,
        'kicker': kicker,
        'hostName': hostName,
        'hostAvatarUrl': hostAvatarUrl,
        'details': details,
        if (whenFullLabel != null) 'whenFullLabel': whenFullLabel,
        'address': address,
        'mapImageUrl': mapImageUrl,
        'artists': artists.map((a) => a.toJson()).toList(),
        'pieceImageUrls': pieceImageUrls,
        'faqs': faqs.map((f) => f.toJson()).toList(),
      };

  factory DummyEvent.fromJson(Map<String, dynamic> json) => DummyEvent(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        venue: json['venue'] as String? ?? '',
        priceLabel: json['priceLabel'] as String? ?? '',
        whenLabel: json['whenLabel'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        kicker: json['kicker'] as String? ?? 'GALLERY WALK',
        hostName: json['hostName'] as String? ?? 'Amara Osmei',
        hostAvatarUrl: json['hostAvatarUrl'] as String? ??
            'https://picsum.photos/seed/event-host-amara/80/80',
        details: json['details'] as String? ?? _kDefaultDetails,
        whenFullLabel: json['whenFullLabel'] as String?,
        address: json['address'] as String? ??
            '1414 Dragon St, Dallas, TX 75201, USA',
        mapImageUrl: json['mapImageUrl'] as String? ??
            'https://picsum.photos/seed/event-map-dallas/900/520',
        artists: (json['artists'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(DummyEventArtist.fromJson)
                .toList() ??
            _kDefaultArtists,
        pieceImageUrls:
            (json['pieceImageUrls'] as List?)?.cast<String>() ?? _kDefaultPieces,
        faqs: (json['faqs'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(DummyEventFaq.fromJson)
                .toList() ??
            _kDefaultFaqs,
      );
}

const _kDefaultDetails =
    'Started this one trying to paint skin as light rather than surface. The teal came first... I wasn\'t really planning it, but once it was there everything else had to answer to it. I kept asking myself what happens when color leads the portrait instead of likeness, and how a room of people would stand in that glow together.';

const _kDefaultArtists = <DummyEventArtist>[
  DummyEventArtist(
    name: 'Amara',
    avatarUrl: 'https://picsum.photos/seed/event-artist-amara/160/160',
  ),
  DummyEventArtist(
    name: 'Cedric',
    avatarUrl: 'https://picsum.photos/seed/event-artist-cedric/160/160',
  ),
  DummyEventArtist(
    name: 'Daisy',
    avatarUrl: 'https://picsum.photos/seed/event-artist-daisy/160/160',
  ),
];

const _kDefaultPieces = <String>[
  'https://picsum.photos/seed/event-piece-a/520/680',
  'https://picsum.photos/seed/event-piece-b/520/680',
  'https://picsum.photos/seed/event-piece-c/400/680',
];

const _kDefaultFaqs = <DummyEventFaq>[
  DummyEventFaq(
    question: 'Where do I park?',
    answer:
        'Street parking on Dragon St after 6PM, plus the Design District garage at Hi Line. A valet stand sits at the front door.',
  ),
  DummyEventFaq(
    question: 'What do I wear?',
    answer:
        'Gallery-casual. Comfortable shoes for standing; the studio floors can get dusty.',
  ),
  DummyEventFaq(
    question: 'Is there a waitlist?',
    answer:
        'Yes — if tickets sell out, join the waitlist from Get tickets and we’ll email you if a spot opens.',
  ),
];

abstract final class EventDummyData {
  static const featured = DummyEvent(
    id: 'featured-1',
    kicker: 'GALLERY WALK',
    title: 'Inside the Mind of an Artist',
    venue: 'Dec on Dragon',
    priceLabel: '\$25',
    whenLabel: 'Sat · 8PM CST',
    whenFullLabel: 'Sat, July 25th · 8:00PM - 10:00PM CST',
    imageUrl: 'https://picsum.photos/seed/event-hero-mind/800/1100',
  );

  static const today = <DummyEvent>[
    DummyEvent(
      id: 'today-1',
      title: 'Collector’s Preview & Auction',
      venue: 'Cedars Union',
      priceLabel: '\$25',
      whenLabel: 'Sat · 6PM CST',
      imageUrl: 'https://picsum.photos/seed/event-today-1/400/520',
    ),
    DummyEvent(
      id: 'today-2',
      title: 'Night Market at Deep Ellum',
      venue: 'Elm Street',
      priceLabel: 'Free',
      whenLabel: 'Sat · 7PM CST',
      imageUrl: 'https://picsum.photos/seed/event-today-2/400/520',
    ),
    DummyEvent(
      id: 'today-3',
      title: 'Figure Drawing Session',
      venue: 'The Power Station',
      priceLabel: '\$15',
      whenLabel: 'Sat · 4PM CST',
      imageUrl: 'https://picsum.photos/seed/event-today-3/400/520',
    ),
  ];

  static const following = <DummyEvent>[
    DummyEvent(
      id: 'follow-1',
      title: 'Amara’s Open Studio',
      venue: 'Cedars Union',
      priceLabel: '\$25',
      whenLabel: 'Sat · 6PM CST',
      imageUrl: 'https://picsum.photos/seed/event-follow-1/520/680',
    ),
    DummyEvent(
      id: 'follow-2',
      title: 'Amara’s Open Studio',
      venue: 'Cedars Union',
      priceLabel: '\$25',
      whenLabel: 'Sat · 6PM CST',
      imageUrl: 'https://picsum.photos/seed/event-follow-2/520/680',
      saved: true,
    ),
    DummyEvent(
      id: 'follow-3',
      title: 'Clay & Conversation',
      venue: 'Oak Cliff Clay',
      priceLabel: '\$40',
      whenLabel: 'Sun · 2PM CST',
      imageUrl: 'https://picsum.photos/seed/event-follow-3/520/680',
    ),
  ];

  static const workshops = <DummyEvent>[
    DummyEvent(
      id: 'ws-1',
      title: 'Intro to Cyanotype',
      venue: 'Cedars Union',
      priceLabel: '\$45',
      whenLabel: 'Sat · 11AM CST',
      imageUrl: 'https://picsum.photos/seed/event-ws-1/520/680',
    ),
    DummyEvent(
      id: 'ws-2',
      title: 'Color Mixing Lab',
      venue: 'The MAC',
      priceLabel: '\$35',
      whenLabel: 'Sun · 1PM CST',
      imageUrl: 'https://picsum.photos/seed/event-ws-2/520/680',
    ),
    DummyEvent(
      id: 'ws-3',
      title: 'Portrait Lighting 101',
      venue: 'Fair Park',
      priceLabel: '\$60',
      whenLabel: 'Sat · 3PM CST',
      imageUrl: 'https://picsum.photos/seed/event-ws-3/520/680',
    ),
  ];

  static const exhibitions = <DummyEvent>[
    DummyEvent(
      id: 'ex-1',
      title: 'New Work: East Dallas',
      venue: 'Kirk Hopper',
      priceLabel: 'Free',
      whenLabel: 'Sat · 6PM CST',
      imageUrl: 'https://picsum.photos/seed/event-ex-1/520/680',
    ),
    DummyEvent(
      id: 'ex-2',
      title: 'Small Works Fair',
      venue: 'Cedars Union',
      priceLabel: '\$10',
      whenLabel: 'Sun · 12PM CST',
      imageUrl: 'https://picsum.photos/seed/event-ex-2/520/680',
    ),
    DummyEvent(
      id: 'ex-3',
      title: 'After Hours at the Warehouse',
      venue: 'The Power Station',
      priceLabel: '\$20',
      whenLabel: 'Fri · 8PM CST',
      imageUrl: 'https://picsum.photos/seed/event-ex-3/520/680',
    ),
  ];

  static const categories = <DummyEventCategory>[
    DummyEventCategory(
      id: 'cat-studio',
      title: 'Studio Visits',
      upcomingLabel: '6 upcoming',
      imageUrl: 'https://picsum.photos/seed/event-cat-studio/520/520',
    ),
    DummyEventCategory(
      id: 'cat-popups',
      title: 'Pop-ups',
      upcomingLabel: '6 upcoming',
      imageUrl: 'https://picsum.photos/seed/event-cat-popups/520/520',
    ),
    DummyEventCategory(
      id: 'cat-walks',
      title: 'Gallery Walks',
      upcomingLabel: '8 upcoming',
      imageUrl: 'https://picsum.photos/seed/event-cat-walks/520/520',
    ),
    DummyEventCategory(
      id: 'cat-markets',
      title: 'Markets',
      upcomingLabel: '4 upcoming',
      imageUrl: 'https://picsum.photos/seed/event-cat-markets/520/520',
    ),
  ];

  static List<DummyEvent> get all => [
        featured,
        ...today,
        ...following,
        ...workshops,
        ...exhibitions,
      ];

  static DummyEvent byId(String id) {
    for (final event in all) {
      if (event.id == id) return event;
    }
    return featured;
  }
}

class DummyEventCategory {
  const DummyEventCategory({
    required this.id,
    required this.title,
    required this.upcomingLabel,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String upcomingLabel;
  final String imageUrl;
}
