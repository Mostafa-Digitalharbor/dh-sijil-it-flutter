import 'package:flutter/material.dart';

/// Picks the glyph for an asset from its category name.
///
/// ## Why a heuristic and not a lookup table
///
/// Categories are customer data — `maintenance.equipment.category` rows the
/// customer created — so there is no id, no external identifier and no
/// selection value to key off (spec §10 forbids hardcoding ids, and there is
/// nothing stable to hardcode anyway). The alternatives were a generic icon on
/// every row, which loses the scannability the design depends on, or this:
/// match the words customers actually use, and fall back cleanly.
///
/// The fallback is the point. An unmatched category gets [fallback] rather
/// than a wrong icon, so a customer whose categories are in Arabic, French or
/// their own shorthand sees a consistent neutral glyph instead of a laptop
/// beside their printers.
abstract final class AssetIcons {
  /// Shown for any category this does not recognise.
  static const IconData fallback = Icons.devices_other_rounded;

  /// Keyword → glyph, checked in order. Lower-cased substring matches, so
  /// "Laptops", "Company Laptop" and "laptop-dock" all resolve.
  static const List<(List<String>, IconData)>
  _rules = <(List<String>, IconData)>[
    (<String>['laptop', 'notebook', 'macbook'], Icons.laptop_mac_rounded),
    (<String>['desktop', 'workstation', 'pc'], Icons.desktop_windows_rounded),
    (<String>['monitor', 'display', 'screen'], Icons.monitor_rounded),
    (
      <String>['mobile', 'phone', 'iphone', 'tablet', 'ipad'],
      Icons.smartphone_rounded,
    ),
    (<String>['printer', 'scanner', 'copier'], Icons.print_rounded),
    (<String>['server', 'rack', 'nas'], Icons.dns_rounded),
    (
      <String>['network', 'router', 'switch', 'firewall', 'access point'],
      Icons.router_rounded,
    ),
    (
      <String>['accessory', 'mouse', 'keyboard', 'headset', 'dock', 'webcam'],
      Icons.mouse_rounded,
    ),
    (<String>['camera'], Icons.photo_camera_rounded),
    (<String>['projector'], Icons.videocam_rounded),
    (<String>['software', 'licence', 'license'], Icons.apps_rounded),
  ];

  static IconData forCategory(String? category) {
    if (category == null || category.trim().isEmpty) return fallback;

    final name = category.toLowerCase();
    for (final (keywords, icon) in _rules) {
      for (final keyword in keywords) {
        if (name.contains(keyword)) return icon;
      }
    }
    return fallback;
  }
}
