import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../localization/app_translations.dart';
import 'account_login_screen.dart';

class CommentsScreen extends StatefulWidget {
  final NewsArticle article;

  /// Renders as a sheet on the current screen rather than a pushed page:
  /// drag handle and close button instead of a Scaffold with a back arrow.
  /// Same state, same loading and posting logic — only the chrome differs.
  final bool sheetMode;

  const CommentsScreen({
    super.key,
    required this.article,
    this.sheetMode = false,
  });

  /// Opens comments over the current screen, keeping the post behind visible.
  static Future<void> showSheet(BuildContext context, NewsArticle article) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: CommentsScreen(article: article, sheetMode: true),
      ),
    );
  }

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
      _showLoginPromptModal(
        context,
        title: tr('login_to_comment'),
        subtitle: tr('login_to_comment_desc'),
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
        widget.article.comments++;
        final targetId = widget.article.id.isNotEmpty
            ? widget.article.id
            : widget.article.slug;
        if (targetId.isNotEmpty) {
          AppState.instance.userAddedComments[targetId] =
              (AppState.instance.userAddedComments[targetId] ?? 0) + 1;
        }
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
    if (!AppState.instance.isLoggedIn) {
      _showLoginPromptModal(
        context,
        title: tr('login_to_comment'),
        subtitle: tr('login_to_reply_desc'),
      );
      return;
    }
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final titleColor = isDark ? AppColors.textLight : AppColors.textDark;
        final iconColor = isDark ? AppColors.iconMutedDark : AppColors.textDark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkNavy : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                if (isOwnComment) ...[
                  ListTile(
                    leading:
                        const Icon(Icons.edit_outlined, color: AppColors.primary),
                    title: Text(tr('edit_comment'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
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
                    leading: Icon(Icons.block, color: iconColor),
                    title: Text(tr('block_user'),
                        style: TextStyle(
                            color: titleColor,
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkNavy : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('report_comment'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('report_reason_prompt'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map((r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          r.$2,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textCommentBodyDark : AppColors.textDark,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: isDark ? AppColors.iconMutedDark : Colors.grey,
                        ),
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
      },
    );
  }

  Widget _buildCommentItem(Comment comment, {bool isReply = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (comment.isReported || comment.visibility == 'hidden') {
      return Container(
        margin: EdgeInsets.only(left: isReply ? 48 : 0, bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceElevatedDark
              : Theme.of(context).dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: isDark ? Border.all(color: AppColors.borderDark) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 16,
                color: isDark ? AppColors.iconMutedDark : Colors.grey),
            const SizedBox(width: 8),
            Text(tr('comment_hidden'),
                style: TextStyle(
                    color: isDark ? AppColors.iconMutedDark : Colors.grey,
                    fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    if (comment.visibility == 'public_tombstone') {
      return Container(
        margin: EdgeInsets.only(left: isReply ? 48 : 0, bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceElevatedDark
              : Theme.of(context).dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: isDark ? Border.all(color: AppColors.borderDark) : null,
        ),
        child: Text(tr('comment_deleted'),
            style: TextStyle(
                color: isDark ? AppColors.iconMutedDark : Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 13)),
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
            backgroundColor: isDark
                ? AppColors.surfaceElevatedDark
                : AppColors.chipBg,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.iconMutedDark
                            : AppColors.textMuted,
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
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3)),
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
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.more_horiz,
                            size: 16,
                            color: isDark
                                ? AppColors.iconMutedDark
                                : AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textCommentBodyDark
                        : AppColors.textDark,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!AppState.instance.isLoggedIn) {
                          _showLoginPromptModal(
                            context,
                            title: tr('login_to_comment'),
                            subtitle: tr('login_to_like_desc'),
                          );
                          return;
                        }
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
                            ? AppColors.heartRed
                            : (isDark
                                ? AppColors.iconMutedDark
                                : AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textMuted,
                      ),
                    ),
                    if (!isReply) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _onReplyTap(comment),
                        child: Text(
                          tr('reply'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textMuted,
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
    final body = Column(
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
      );

    if (widget.sheetMode) return _asSheet(context, body);

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
      body: body,
    );
  }

  /// Sheet chrome: handle, title, close. No Scaffold, so the post behind
  /// stays on screen and the reader never leaves it.
  Widget _asSheet(BuildContext context, Widget body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkNavy : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 4),
            child: Row(
              children: [
                Text(
                  tr('comments_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? AppColors.textLight : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 20,
                      color: isDark ? AppColors.textLight : null),
                  onPressed: () => Navigator.pop(context),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : Theme.of(context).dividerColor),
          Expanded(child: body),
        ],
      ),
    );
  }

  void _showLoginPromptModal(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkNavy : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDark
                ? const Border(
                    top: BorderSide(color: AppColors.borderDark, width: 1))
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Icon pill
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.brandBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                // Title
                Text(
                  title ?? tr('login_to_comment'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle / Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    subtitle ?? tr('login_to_comment_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Login action button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountLoginScreen(),
                        ),
                      ).then((_) {
                        if (!mounted) return;
                        if (AppState.instance.isLoggedIn) {
                          _fetchComments();
                          setState(() {});
                        }
                      });
                    },
                    icon: const Icon(Icons.login_rounded, size: 20, color: Colors.white),
                    label: Text(
                      tr('log_in'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Dismiss / Later button
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    tr('maybe_later'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.iconMutedDark : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildCommentComposer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkNavy : Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                    child: Icon(Icons.close,
                        size: 16,
                        color: isDark ? AppColors.iconMutedDark : AppColors.textMuted),
                  )
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark
                      ? AppColors.surfaceElevatedDark
                      : AppColors.primary.withValues(alpha: 0.12),
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
                      : Icon(Icons.person_rounded,
                          size: 18,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    enabled: !_isPosting,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                    cursorColor: isDark ? AppColors.textLight : AppColors.primary,
                    decoration: InputDecoration(
                      hintText: tr('add_comment_hint'),
                      hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.iconMutedDark : AppColors.textMuted),
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceElevatedDark : AppColors.chipBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderDark : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderDark : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.brandBlue : AppColors.primary,
                          width: 1.5,
                        ),
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
                        icon: const Icon(Icons.send_rounded, color: AppColors.primary),
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
