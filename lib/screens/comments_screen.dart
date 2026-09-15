import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/navigation/auth_guard.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../localization/app_translations.dart';
import 'account_login_screen.dart';

class CommentsScreen extends StatefulWidget {
  final NewsArticle article;

  const CommentsScreen({super.key, required this.article});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _replyingToCommentId;
  String? _replyingToUsername;
  bool _isLoading = true;
  bool _isPosting = false;
  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await ApiService.instance.getComments(widget.article.id);
      if (mounted) {
        setState(() {
          if (fetched.isNotEmpty) {
            _comments = fetched;
          } else {
            // Fall back to any locally cached demo comments for this article if none returned yet
            _comments = AppState.instance.getComments(widget.article.id);
          }
          _isLoading = false;
        });
        AppState.instance.setComments(widget.article.id, _comments);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _comments = AppState.instance.getComments(widget.article.id);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!AppState.instance.isLoggedIn) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(tr('login_to_comment')),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            action: SnackBarAction(
              label: tr('login'),
              textColor: Colors.amber,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountLoginScreen()),
                ).then((_) => _fetchComments());
              },
            ),
          ),
        );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final newComment = await ApiService.instance.postComment(
        widget.article.id,
        text,
        parentId: _replyingToCommentId,
      );

      if (mounted) {
        setState(() {
          if (_replyingToCommentId != null) {
            final parentIdx =
                _comments.indexWhere((c) => c.id == _replyingToCommentId);
            if (parentIdx != -1) {
              _comments[parentIdx].replies.add(newComment);
            } else {
              _comments.insert(0, newComment);
            }
          } else {
            _comments.insert(0, newComment);
          }
          _replyingToCommentId = null;
          _replyingToUsername = null;
          _isPosting = false;
        });

        _commentController.clear();
        _focusNode.unfocus();
        AppState.instance.setComments(widget.article.id, _comments);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('comment_posted')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        String errorMsg = tr('comment_post_failed');
        if (e is DioException && e.response?.data is Map) {
          errorMsg = e.response?.data['errors']?['message'] ?? errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onReplyTap(Comment parentComment) {
    setState(() {
      _replyingToCommentId = parentComment.id;
      _replyingToUsername = parentComment.username;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
    _commentController.clear();
    _focusNode.unfocus();
  }

  void _showCommentOptions(Comment comment, {bool isReply = false}) {
    final currentUserId = AppState.instance.userId;
    final currentUserName = AppState.instance.userName;
    final isOwnComment =
        (comment.authorId != null && comment.authorId == currentUserId) ||
            (comment.username == currentUserName && currentUserName.isNotEmpty);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (isOwnComment) ...[
                ListTile(
                  leading:
                      const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: Text(tr('edit_comment'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(comment);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text(tr('delete_comment'),
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteComment(comment);
                  },
                ),
              ] else ...[
                ListTile(
                  leading:
                      const Icon(Icons.flag_outlined, color: AppColors.primary),
                  title: Text(tr('report_comment'),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportReasonDialog(comment);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: AppColors.textDark),
                  title: Text(tr('block_user'),
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('${comment.username} ${tr('blocked')}')),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(Comment comment) {
    final editController = TextEditingController(text: comment.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('edit_comment')),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: tr('updated_comment_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiService.instance.editComment(comment.id, newText);
                if (!mounted) return;
                _fetchComments();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('comment_updated'))),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('comment_update_failed'))),
                );
              }
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    ).whenComplete(() => editController.dispose());
  }

  void _confirmDeleteComment(Comment comment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_comment')),
        content: Text(tr('delete_comment_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance.deleteComment(comment.id);
                if (!mounted) return;
                setState(() {
                  _comments.removeWhere((c) => c.id == comment.id);
                  for (var c in _comments) {
                    c.replies.removeWhere((r) => r.id == comment.id);
                  }
                });
                AppState.instance.setComments(widget.article.id, _comments);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('comment_deleted'))),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('comment_delete_failed'))),
                );
              }
            },
            child: Text(tr('delete_comment')),
          ),
        ],
      ),
    );
  }

  void _showReportReasonDialog(Comment comment) {
    final reasons = [
      ('spam', tr('reason_spam')),
      ('abuse', tr('reason_abuse')),
      ('hate', tr('reason_hate')),
      ('misinformation', tr('reason_misinformation')),
      ('violence', tr('reason_violence')),
      ('sexual_content', tr('reason_sexual')),
      ('other', tr('reason_other')),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('report_comment'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                tr('report_reason_prompt'),
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ...reasons.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.$2, style: const TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await ApiService.instance
                            .reportComment(comment.id, reason: r.$1);
                        if (!mounted) return;
                        setState(() => comment.isReported = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(tr('comment_reported_hidden'))),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('comment_report_failed'))),
                        );
                      }
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, {bool isReply = false}) {
    if (comment.isReported || comment.visibility == 'hidden') {
      return Container(
        margin: EdgeInsets.only(left: isReply ? 48 : 0, bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(tr('comment_hidden'),
                style: const TextStyle(
                    color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    if (comment.visibility == 'public_tombstone') {
      return Container(
        margin: EdgeInsets.only(left: isReply ? 48 : 0, bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(tr('comment_deleted'),
            style: const TextStyle(
                color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
      );
    }

    final isPendingReview =
        comment.status == 'pending' || comment.visibility == 'author_only';

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 48 : 0, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundImage: NetworkImage(comment.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (isPendingReview) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tr('pending_review'),
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: () =>
                          _showCommentOptions(comment, isReply: isReply),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.more_horiz,
                            size: 16, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          comment.isLikedByUser = !comment.isLikedByUser;
                          if (comment.isLikedByUser) {
                            comment.likes += 1;
                          } else {
                            comment.likes =
                                (comment.likes - 1).clamp(0, 999999);
                          }
                        });
                        AppState.instance
                            .toggleCommentLike(widget.article.id, comment.id);
                      },
                      child: Icon(
                        comment.isLikedByUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: comment.isLikedByUser
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likes}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (!isReply) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _onReplyTap(comment),
                        child: Text(
                          tr('reply'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppState.instance.isLoggedIn) {
      return _buildLoginRequiredScreen();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('comments_title'),
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).dividerColor, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchComments,
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                tr('no_comments'),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 14),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCommentItem(comment, isReply: false),
                                ...comment.replies.map((reply) =>
                                    _buildCommentItem(reply, isReply: true)),
                              ],
                            );
                          },
                        ),
            ),
          ),
          _buildCommentComposer(context),
        ],
      ),
    );
  }

  Widget _buildLoginRequiredScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('comments_title'),
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  tr('login_to_comment'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => requireAuth(context, () {
                    if (!mounted) return;
                    _fetchComments();
                    setState(() {});
                  }),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(tr('login')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildCommentComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyingToUsername != null) ...[
              Row(
                children: [
                  Text(
                    '${tr('replying_to')} $_replyingToUsername',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.textMuted),
                  )
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage:
                      (AppState.instance.profileImagePath != null &&
                              AppState.instance.profileImagePath!
                                  .startsWith('http'))
                          ? NetworkImage(AppState.instance.profileImagePath!)
                          : null,
                  child: (AppState.instance.profileImagePath != null &&
                          AppState.instance.profileImagePath!
                              .startsWith('http'))
                      ? null
                      : const Icon(Icons.person_rounded,
                          size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    enabled: !_isPosting,
                    decoration: InputDecoration(
                      hintText: tr('add_comment_hint'),
                      hintStyle: const TextStyle(
                          fontSize: 14, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.chipBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 8),
                _isPosting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: AppColors.primary),
                        onPressed: _postComment,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
