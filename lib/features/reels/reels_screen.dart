import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sharing/share_content_builder.dart';
import '../../services/sharing/share_models.dart';
import '../../state/app_state.dart';
import '../../widgets/sharing/share_sheet.dart';
import 'reel_item.dart';
import 'reel_model.dart';
import 'reels_api.dart';
import 'reels_controller.dart';

/// Snappy, no-bounce vertical paging, like YouTube Shorts / Instagram Reels.
class ReelPagePhysics extends PageScrollPhysics {
  const ReelPagePhysics({super.parent});

  @override
  ReelPagePhysics applyTo(ScrollPhysics? ancestor) =>
      ReelPagePhysics(parent: buildParent(ancestor));

  // About critically damped: settles fast, no wobble.
  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.5, stiffness: 160, damping: 18);

  // A light flick is enough to change reels.
  @override
  double get minFlingVelocity => 50.0;

  @override
  double get minFlingDistance => 8.0;
}

/// Full-screen Reels, opened over the app from the bottom bar's Reels tab.
/// There is no bottom bar while it is open; back (the button or the system
/// gesture) returns to the app.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, this.location, this.api, this.initialReel});

  /// Played first, ahead of the feed (a notification's video).
  final Reel? initialReel;

  /// state, district, city, subdistrict, village — the reader's own by
  /// default.
  final Map<String, String>? location;

  /// Injectable for tests.
  final ReelsApi? api;

  /// The reader's location as the shorts-feed wants it (scope=main mixes
  /// global reels with ones matching these).
  static Map<String, String> readerLocation() {
    final s = AppState.instance;
    return {
      'state': s.stateName,
      'district': s.district,
      'city': s.city,
      'subdistrict': s.subdistrict,
      'village': s.village,
    };
  }

  /// Opens Reels: a short fade-and-rise from the bottom bar, and the same
  /// back out.
  static Future<void> open(BuildContext context, {Reel? initialReel}) {
    return Navigator.of(context).push(route(initialReel: initialReel));
  }

  /// The Reels route, for callers that push through their own navigator
  /// helper (e.g. a debounced push).
  static Route<void> route({Reel? initialReel}) {
    return PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/reels'),
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => ReelsScreen(initialReel: initialReel),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
    );
  }

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late final ReelsController _ctrl = ReelsController(
    api: widget.api ?? ReelsApi.forApp(),
    location: widget.location ?? ReelsScreen.readerLocation(),
    pinned: widget.initialReel,
  );
  final PageController _page = PageController();
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.loadFirstPage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appVisible = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _page.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    _ctrl.onPageChanged(i);
    final reels = _ctrl.reels;
    // The next reel's thumbnail is ready before the swipe lands.
    if (i + 1 < reels.length && reels[i + 1].thumbnailUrl.isNotEmpty) {
      precacheImage(NetworkImage(reels[i + 1].thumbnailUrl), context);
    }
  }

  /// The app's share sheet, with the backend's share_url.
  void _share(Reel r) {
    ShareSheet.show(
      context,
      ShareContent(
        contentType: ShareContentType.short,
        contentId: r.id,
        title: r.title,
        imageUrl: r.thumbnailUrl.isEmpty ? null : r.thumbnailUrl,
        videoUrl: r.videoUrl.isNotEmpty ? r.videoUrl : r.youtubeUrl,
        canonicalUrl:
            ShareContentBuilder.trustedShareUrl(r.shareUrl) ?? r.safeShareUrl,
        category: r.channelName.isEmpty ? null : r.channelName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Plays only while this screen is on top: another route over it (the
    // share sheet, a login) or the app in the background pauses it.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            final c = _ctrl;
            final canPlay = onTop && _appVisible;

            return Stack(
              children: [
                if (c.reels.isEmpty)
                  c.isLoadingFirst
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white))
                      : _FullScreenMessage(
                          icon: c.firstPageError != null
                              ? Icons.wifi_off_rounded
                              : Icons.video_library_outlined,
                          text: c.firstPageError ?? 'ప్రస్తుతం రీల్స్ లేవు',
                          onRetry: c.loadFirstPage,
                        )
                else
                  // Never inside another vertical scroll view: that would
                  // take the swipe.
                  PageView.builder(
                    key: const Key('reels_pager'),
                    controller: _page,
                    scrollDirection: Axis.vertical,
                    physics:
                        const ReelPagePhysics(parent: ClampingScrollPhysics()),
                    // Keeps the next reel built, so it is ready to show.
                    allowImplicitScrolling: true,
                    itemCount: c.reels.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) {
                      final r = c.reels[i];
                      return ReelItem(
                        key: ValueKey(r.id),
                        reel: r,
                        isActive: canPlay && i == c.currentIndex,
                        isMuted: c.isMuted,
                        onToggleMute: c.toggleMute,
                        onShare: () => _share(r),
                      );
                    },
                  ),

                if (c.reels.isNotEmpty && c.loadMoreFailed)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    child: Center(
                      child: ActionChip(
                        key: const Key('reels_load_more_retry'),
                        backgroundColor: Colors.white24,
                        avatar: const Icon(Icons.refresh,
                            color: Colors.white, size: 18),
                        label: const Text('మళ్ళీ ప్రయత్నించండి',
                            style: TextStyle(color: Colors.white)),
                        onPressed: c.loadMore,
                      ),
                    ),
                  )
                else if (c.isLoadingMore &&
                    c.currentIndex >= c.reels.length - 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),

                // Back to the app.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: IconButton(
                      key: const Key('reels_back'),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.black26),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FullScreenMessage extends StatelessWidget {
  const _FullScreenMessage(
      {required this.icon, required this.text, required this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white60, size: 52),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('reels_retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('మళ్ళీ ప్రయత్నించండి'),
            ),
          ],
        ),
      ),
    );
  }
}
