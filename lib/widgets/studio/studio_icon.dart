import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/studio_colors.dart';

/// Icon files extracted from the boards (`assets/icons/`, catalog in docs/new-ui/ICONS.md).
/// Each SVG keeps the board's own stroke width, so only size and color are set here.
abstract final class StudioIcons {
  static const String _dir = 'assets/icons';

  static const String arrowRight = '$_dir/arrow_right.svg';
  static const String attach = '$_dir/attach_a_photo_or_video.svg';
  static const String back = '$_dir/back.svg';
  static const String backBold = '$_dir/back_to_explore.svg';
  static const String block = '$_dir/block.svg';
  static const String chat = '$_dir/chat.svg';
  static const String chevronRight = '$_dir/chevron_right.svg';
  static const String chevronDown = '$_dir/chevron_down.svg';
  static const String plus = '$_dir/plus.svg';
  static const String sliders = '$_dir/sliders.svg';
  static const String scan = '$_dir/scan.svg';
  static const String camera = '$_dir/camera.svg';
  static const String qrCode = '$_dir/qr_code.svg';
  static const String ticket = '$_dir/ticket.svg';
  static const String card = '$_dir/card.svg';
  static const String check = '$_dir/check.svg';
  static const String close = '$_dir/close.svg';
  static const String edit = '$_dir/edit_piece.svg';
  static const String eye = '$_dir/eye.svg';
  static const String eyeOff = '$_dir/eye_off.svg';
  static const String events = '$_dir/events.svg';
  static const String folder = '$_dir/folder.svg';
  static const String folderOptions = '$_dir/conversation_options.svg';
  static const String deleteFolder = '$_dir/delete_folder.svg';
  static const String renameFolder = '$_dir/rename_folder.svg';
  static const String newFolder = '$_dir/add_a_photo.svg';
  static const String filter = '$_dir/filter_feed.svg';
  static const String inbox = '$_dir/inbox_unread_items.svg';
  static const String layers = '$_dir/layers.svg';

  /// Not on any board: the piece page keeps its like action (plan rule 4), drawn in the
  /// boards' icon style (24 grid, 1.8 stroke, round caps). Liked is filled Ink, not red.
  static const String like = '$_dir/like.svg';
  static const String liked = '$_dir/liked.svg';
  static const String link = '$_dir/link.svg';
  static const String location = '$_dir/location.svg';
  static const String lock = '$_dir/lock.svg';
  static const String shareBold = '$_dir/share_bold.svg';
  static const String unlink = '$_dir/unlink.svg';
  static const String addBold = '$_dir/add_bold.svg';
  static const String explore = '$_dir/explore.svg';
  static const String home = '$_dir/home.svg';
  static const String info = '$_dir/info.svg';
  static const String more = '$_dir/more.svg';
  static const String post = '$_dir/post.svg';
  static const String profile = '$_dir/profile.svg';
  static const String report = '$_dir/report.svg';
  static const String reels = '$_dir/reels.svg';
  static const String save = '$_dir/save.svg';
  static const String saved = '$_dir/saved.svg';
  static const String search = '$_dir/search_behind_the_work.svg';
  static const String send = '$_dir/send.svg';
  static const String settings = '$_dir/settings.svg';
  static const String share = '$_dir/share.svg';
  static const String video = '$_dir/video.svg';
}

/// A board icon drawn in one color (defaults to the current text color).
class StudioIcon extends StatelessWidget {
  const StudioIcon(this.asset, {super.key, this.size = 24, this.color, this.semanticLabel});

  final String asset;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? context.studio.textPrimary;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
