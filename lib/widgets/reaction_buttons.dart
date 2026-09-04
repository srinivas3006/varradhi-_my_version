import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum Reaction { like, dislike, none }

class ReactionButtons extends StatefulWidget {
  final String articleId;
  final Reaction initialReaction;
  final int initialLikeCount;
  final int initialDislikeCount;
  final Future<void> Function(String articleId, Reaction reaction)? onServerSync;
  final void Function(Reaction newReaction, int likes, int dislikes)? onChanged;

  const ReactionButtons({
    super.key,
    required this.articleId,
    this.initialReaction = Reaction.none,
    this.initialLikeCount = 0,
    this.initialDislikeCount = 0,
    this.onServerSync,
    this.onChanged,
  });

  @override
  State<ReactionButtons> createState() => _ReactionButtonsState();
}

class _ReactionButtonsState extends State<ReactionButtons> {
  late Reaction _reaction;
  late int _likes;
  late int _dislikes;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _reaction = widget.initialReaction;
    _likes = widget.initialLikeCount;
    _dislikes = widget.initialDislikeCount;
  }

  void _applyLocalChange(Reaction next) {
    final prev = _reaction;

    if (prev == Reaction.like) _likes = (_likes - 1).clamp(0, 1 << 30);
    if (prev == Reaction.dislike) _dislikes = (_dislikes - 1).clamp(0, 1 << 30);

    if (next == Reaction.like) _likes++;
    if (next == Reaction.dislike) _dislikes++;

    _reaction = next;
  }

  Future<void> _onTap(Reaction tapped) async {
    if (_syncing) return;
    final prev = _reaction;
    final next = prev == tapped ? Reaction.none : tapped;

    setState(() {
      _applyLocalChange(next);
      _syncing = true;
    });

    widget.onChanged?.call(_reaction, _likes, _dislikes);

    try {
      if (widget.onServerSync != null) {
        await widget.onServerSync!(widget.articleId, _reaction);
      } else {
        // fallback: try ApiService default endpoint
        await ApiService.instance.postArticleReaction(widget.articleId, _reaction);
      }
    } catch (e) {
      // rollback
      setState(() {
        // naive rollback to initial values when server fails
        _reaction = prev;
        _likes = widget.initialLikeCount + (prev == Reaction.like ? 1 : 0);
        _dislikes = widget.initialDislikeCount + (prev == Reaction.dislike ? 1 : 0);
      });
      widget.onChanged?.call(_reaction, _likes, _dislikes);
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _syncing ? null : () => _onTap(Reaction.like),
          icon: Icon(
            _reaction == Reaction.like ? Icons.favorite : Icons.favorite_border,
            color: _reaction == Reaction.like ? color : null,
            size: 20,
          ),
        ),
        Text('$_likes', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _syncing ? null : () => _onTap(Reaction.dislike),
          icon: Icon(
            _reaction == Reaction.dislike ? Icons.thumb_down : Icons.thumb_down_outlined,
            color: _reaction == Reaction.dislike ? color : null,
            size: 20,
          ),
        ),
        Text('$_dislikes', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
