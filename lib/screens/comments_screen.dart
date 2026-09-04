import 'package:flutter/material.dart';
import '../models/news_article.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../localization/app_translations.dart';

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

  void _postComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (_replyingToCommentId != null) {
      AppState.instance.addReply(widget.article.id, _replyingToCommentId!, text);
    } else {
      AppState.instance.addComment(widget.article.id, text);
    }
    
    _commentController.clear();
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
    _focusNode.unfocus();
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

  void _showReportMenu(Comment comment) {
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
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.primary),
                title: Text(tr('report_comment'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  AppState.instance.reportComment(widget.article.id, comment.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('comment_reported_hidden'))),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.textDark),
                title: Text(tr('block_user'), style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${comment.username} ${tr('blocked')}')),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(Comment comment, {bool isReply = false}) {
    if (comment.isReported) {
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
            Text(tr('comment_hidden'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

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
                    const Spacer(),
                    InkWell(
                      onTap: () => _showReportMenu(comment),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.more_horiz, size: 16, color: AppColors.textMuted),
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
                      onTap: () => AppState.instance.toggleCommentLike(widget.article.id, comment.id),
                      child: Icon(
                        comment.isLikedByUser ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: comment.isLikedByUser ? AppColors.primary : AppColors.textMuted,
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('comments_title'),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).dividerColor, height: 1),
        ),
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final comments = AppState.instance.getComments(widget.article.id);
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommentItem(comment, isReply: false),
                        ...comment.replies.map((reply) => _buildCommentItem(reply, isReply: true)),
                      ],
                    );
                  },
                ),
              ),
              Container(
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
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _cancelReply,
                              child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${AppState.instance.userName.hashCode}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _focusNode,
                              decoration: InputDecoration(
                                hintText: tr('add_comment_hint'),
                                hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.chipBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _postComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: _postComment,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
