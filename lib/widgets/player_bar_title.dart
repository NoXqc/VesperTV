import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';
import '../utils/time_format.dart';

/// Shared by the Android/TV and Windows lower player bars.
class PlayerBarTitle extends StatefulWidget {
  const PlayerBarTitle({super.key, required this.title, this.style});

  final String title;
  final TextStyle? style;

  @override
  State<PlayerBarTitle> createState() => _PlayerBarTitleState();
}

class _PlayerBarTitleState extends State<PlayerBarTitle>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!_enabled ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    final now = DateTime.now();
    final delay = const Duration(minutes: 1) -
        Duration(
            seconds: now.second,
            milliseconds: now.millisecond,
            microseconds: now.microsecond);
    _timer = Timer(delay, () {
      setState(() {});
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _schedule();
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppPreferences, bool>((prefs) => prefs.use24h);
    return LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          Flexible(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.style ??
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: (box.maxWidth * 0.1).clamp(0.0, 8.0)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                TimeFormat.hm.format(DateTime.now()),
                maxLines: 1,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
