/// The time screens show relative dates against ("Today · 2:14 PM", "Mon", "Yesterday").
///
/// It is the device clock. Only tests change it, to pin those labels, and the goldens that
/// show them, to a fixed date: `appNow = () => DateTime(2026, 10, 27, 14, 14);` in setUp, and
/// `appNow = DateTime.now;` in tearDown.
DateTime Function() appNow = DateTime.now;
