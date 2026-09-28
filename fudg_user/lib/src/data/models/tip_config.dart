/// Admin-configured tip options from `GET /food/tips/config`.
///
/// No fallback list: a disabled/unreachable config means hide tipping, not
/// guess retired amounts.
class TipConfig {
  final bool enabled;
  final List<int> presets;
  final double? maxAmount;

  const TipConfig({this.enabled = false, this.presets = const [], this.maxAmount});

  factory TipConfig.fromJson(Map<String, dynamic> json) => TipConfig(
        enabled: json['tipsEnabled'] == true,
        presets: ((json['presets'] as List?) ?? const [])
            .map((e) => int.tryParse('$e') ?? 0)
            .where((n) => n > 0)
            .toList(),
        maxAmount: json['maxAmount'] == null ? null : double.tryParse('${json['maxAmount']}'),
      );
}
