import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/studio_colors.dart';

/// Icon files extracted from the boards (`assets/icons/`, catalog in docs/new-ui/ICONS.md).
/// Each SVG keeps the board's own stroke width, so only size and color are set here.
abstract final class StudioIcons {
  static const String _dir = 'assets/icons';

  static const String arrowRight = '$_dir/arrow_right.svg';
  static const String back = '$_dir/back.svg';
  static const String backBold = '$_dir/back_to_explore.svg';
  static const String chat = '$_dir/chat.svg';
  static const String check = '$_dir/check.svg';
  static const String close = '$_dir/close.svg';
  static const String edit = '$_dir/edit_piece.svg';
  static const String events = '$_dir/events.svg';
  static const String folder = '$_dir/folder.svg';
  static const String folderOptions = '$_dir/conversation_options.svg';
  static const String deleteFolder = '$_dir/delete_folder.svg';
  static const String renameFolder = '$_dir/rename_folder.svg';
  static const String newFolder = '$_dir/add_a_photo.svg';
  static const String filter = '$_dir/filter_feed.svg';
  static const String inbox = '$_dir/inbox_unread_items.svg';
  static const String layers = '$_dir/layers.svg';
  static const String explore = '$_dir/explore.svg';
  static const String home = '$_dir/home.svg';
  static const String info = '$_dir/info.svg';
  static const String more = '$_dir/more.svg';
  static const String post = '$_dir/post.svg';
  static const String profile = '$_dir/profile.svg';
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
