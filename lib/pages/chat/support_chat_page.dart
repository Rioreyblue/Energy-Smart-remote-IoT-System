import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:exercise_app/services/chat_service.dart';
import 'package:exercise_app/models/chat_message_v2.dart';
import 'package:exercise_app/controllers/chat_notification_controller.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  double? _uploadProgress;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _chatService.initializeChat();

    // Initialize chat notification controller and mark as read
    if (mounted) {
      final chatNotificationController =
          Provider.of<ChatNotificationController>(context, listen: false);
      await chatNotificationController.initialize();

      // Mark conversation as read when opened
      if (_chatService.currentChatId != null) {
        await chatNotificationController.markAsRead(
          _chatService.currentChatId!,
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Format date for message grouping
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  /// Format time for message display
  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('h:mm a').format(date);
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  /// Send text message
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final success = await _chatService.sendMessage(text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send message. Please try again.'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    }
  }

  /// Pick and send image
  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        final file = File(image.path);
        final success = await _chatService.sendImageMessage(
          file,
          onUploadProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );

        setState(() {
          _isUploading = false;
          _uploadProgress = null;
        });

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to upload image. Please try again.'),
              backgroundColor: AppColor.accentRed,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    }
  }

  /// Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        final file = File(image.path);
        final success = await _chatService.sendImageMessage(
          file,
          onUploadProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );

        setState(() {
          _isUploading = false;
          _uploadProgress = null;
        });

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to upload image. Please try again.'),
              backgroundColor: AppColor.accentRed,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    }
  }

  /// Show image source picker
  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Iconsax.gallery),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Iconsax.camera),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
              ],
            ),
          ),
    );
  }

  /// Build date separator
  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.withAlpha(77))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateHeader(date),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.withAlpha(77))),
        ],
      ),
    );
  }

  /// Build message bubble
  Widget _buildMessageBubble(
    ChatMessageV2 message,
    ChatMessageV2? previousMessage,
  ) {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final isCurrentUser = message.senderId == currentUserId;
    final date = message.timestamp.toDate();
    final isUnsent = message.metadata?['unsent'] == true;
    final showDateSeparator =
        previousMessage == null ||
        !_isSameDay(previousMessage.timestamp.toDate(), date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDateSeparator) _buildDateSeparator(date),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            mainAxisAlignment:
                isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser) ...[
                _SenderAvatar(chatService: _chatService, message: message),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    // Sender name and email
                    if (!isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: _SenderHeader(
                          chatService: _chatService,
                          message: message,
                        ),
                      ),
                    // Message bubble
                    GestureDetector(
                      onLongPress: () => _showMessageOptions(message),
                      child: Container(
                        // Remove padding for image messages to avoid border effect
                        padding:
                            message.type == 'image'
                                ? EdgeInsets.zero
                                : const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                        decoration: BoxDecoration(
                          // For image messages from current user, use transparent background
                          // For text messages from current user, use green background
                          color:
                              isCurrentUser
                                  ? (message.type == 'image'
                                      ? Colors.transparent
                                      : AppColor.accentGreen)
                                  : Colors.grey[200],
                          borderRadius:
                              message.type == 'image'
                                  ? BorderRadius.zero
                                  : BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(
                                      isCurrentUser ? 20 : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      isCurrentUser ? 4 : 20,
                                    ),
                                  ),
                          // Remove shadow for image messages
                          boxShadow:
                              message.type == 'image'
                                  ? []
                                  : [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            // Image message
                            if (message.type == 'image' &&
                                message.attachments.isNotEmpty)
                              GestureDetector(
                                onTap:
                                    () => _showImagePreview(
                                      message.attachments.first['url']
                                          as String,
                                    ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    message.attachments.first['url'] as String,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.error),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            // Text message
                            if (message.type == 'text' || isUnsent)
                              Text(
                                isUnsent ? '[Message unsent]' : message.text,
                                style: TextStyle(
                                  color:
                                      isCurrentUser
                                          ? Colors.white
                                          : Colors.black87,
                                  fontSize: 15,
                                  fontStyle:
                                      isUnsent
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                  height: 1.4,
                                ),
                              ),
                            const SizedBox(height: 6),
                            // Time and status
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(date),
                                  style: TextStyle(
                                    // For image messages with transparent background, use darker color
                                    color:
                                        (message.type == 'image' &&
                                                isCurrentUser)
                                            ? Colors.black87.withAlpha(153)
                                            : (isCurrentUser
                                                    ? Colors.white
                                                    : Colors.black87)
                                                .withAlpha(179),
                                    fontSize: 11,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    // For image messages, use darker check icon
                                    color:
                                        (message.type == 'image' &&
                                                isCurrentUser)
                                            ? Colors.black87.withAlpha(204)
                                            : Colors.white.withAlpha(230),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Only show profile picture for image messages, not text messages (Messenger-style)
              if (isCurrentUser && message.type == 'image') ...[
                const SizedBox(width: 12),
                FutureBuilder<String?>(
                  future: _chatService.getUserPhotoUrl(message.senderId),
                  builder: (context, snapshot) {
                    final url = snapshot.data;
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColor.accentGreen.withAlpha(77),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            (url != null && url.isNotEmpty)
                                ? NetworkImage(url)
                                : null,
                        backgroundColor: AppColor.accentGreen.withAlpha(26),
                        child:
                            (url == null || url.isEmpty)
                                ? Icon(
                                  Iconsax.user,
                                  size: 20,
                                  color: AppColor.accentGreen,
                                )
                                : null,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Check if two dates are on the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Show message options
  Future<void> _showMessageOptions(ChatMessageV2 message) async {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final isCurrentUser = message.senderId == currentUserId;
    final isUnsent = message.metadata?['unsent'] == true;

    if (!isCurrentUser) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUnsent)
                  ListTile(
                    leading: const Icon(Iconsax.message_remove),
                    title: const Text('Unsend'),
                    onTap: () => Navigator.pop(context, 'unsend'),
                  ),
                ListTile(
                  leading: const Icon(Iconsax.trash, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
                ListTile(
                  leading: const Icon(Iconsax.close_circle),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );

    if (action == 'delete') {
      await _chatService.deleteMessage(message.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message deleted')));
      }
    } else if (action == 'unsend') {
      await _chatService.unsendMessage(message.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message unsent')));
      }
    }
  }

  /// Show image preview
  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(child: Image.network(imageUrl)),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: AppColor.accentGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_1),
          onPressed: () => context.go('/home'),
          color: Colors.white,
        ),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(77), width: 2),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: const AssetImage(
                  'assets/icon/update_icon.png',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support Team',
                    style: ResponsiveText.title(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: () => _chatService.refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/icon/update_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _chatService,
            builder: (context, child) {
              if (_chatService.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColor.accentGreen,
                    ),
                  ),
                );
              }

              if (_chatService.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.warning_2,
                        size: 64,
                        color: AppColor.accentRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading chat',
                        style: ResponsiveText.title(context),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _chatService.error!,
                          style: ResponsiveText.body(context),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _chatService.refresh(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.accentGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // Messages are in descending order from Firestore (newest first)
              // Keep that order for ListView with reverse: true
              final messages = _chatService.messages;

              return Column(
                children: [
                  // Chat messages
                  Expanded(
                    child:
                        messages.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Iconsax.message_text,
                                    size: 64,
                                    color: AppColor.accentGreen.withAlpha(128),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Start a conversation',
                                    style: ResponsiveText.title(
                                      context,
                                    ).copyWith(color: AppColor.disabled),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                    ),
                                    child: Text(
                                      'Send us a message and we\'ll get back to you soon!',
                                      style: ResponsiveText.body(
                                        context,
                                      ).copyWith(color: AppColor.disabled),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                // With reverse: true, index 0 is newest (bottom)
                                // So previous message is at index + 1
                                final message = messages[index];
                                final previousMessage =
                                    index < messages.length - 1
                                        ? messages[index + 1]
                                        : null;
                                return _buildMessageBubble(
                                  message,
                                  previousMessage,
                                );
                              },
                            ),
                  ),

                  // Upload progress indicator
                  if (_isUploading && _uploadProgress != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: AppColor.accentGreen.withAlpha(26),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColor.accentGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColor.accentGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(_uploadProgress! * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColor.accentGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Message input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withAlpha(51),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          // Image picker button
                          Container(
                            decoration: BoxDecoration(
                              color: AppColor.accentGreen.withAlpha(26),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Iconsax.gallery,
                                color: AppColor.accentGreen,
                              ),
                              onPressed:
                                  _isUploading ? null : _showImageSourceDialog,
                              tooltip: 'Add Image',
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Text input
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              enabled: !_isUploading,
                              decoration: InputDecoration(
                                hintText: 'Type your message...',
                                hintStyle: TextStyle(color: AppColor.disabled),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withAlpha(77),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withAlpha(77),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: const BorderSide(
                                    color: AppColor.accentGreen,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Send button
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColor.accentGreen,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Iconsax.send_1,
                                color: Colors.white,
                              ),
                              onPressed: _isUploading ? null : _sendMessage,
                              tooltip: 'Send',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.chatService, required this.message});

  final ChatService chatService;
  final ChatMessageV2 message;

  @override
  Widget build(BuildContext context) {
    final cachedUrl = message.senderPhotoUrl;
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return _AvatarBubble(imageUrl: cachedUrl);
    }

    return FutureBuilder<String?>(
      future: chatService.getUserPhotoUrl(message.senderId),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return _AvatarBubble(imageUrl: url);
      },
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColor.accentGreen.withAlpha(77), width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundImage:
            (imageUrl != null && imageUrl!.isNotEmpty)
                ? NetworkImage(imageUrl!)
                : null,
        backgroundColor: AppColor.accentGreen.withAlpha(26),
        child:
            (imageUrl == null || imageUrl!.isEmpty)
                ? Icon(Iconsax.user, size: 20, color: AppColor.accentGreen)
                : null,
      ),
    );
  }
}

class _SenderHeader extends StatelessWidget {
  const _SenderHeader({required this.chatService, required this.message});

  final ChatService chatService;
  final ChatMessageV2 message;

  @override
  Widget build(BuildContext context) {
    final preferred = (message.senderName ?? '').trim();
    final fallbackEmail = (message.senderEmail ?? '').trim();

    final cachedText =
        preferred.isNotEmpty
            ? preferred
            : (fallbackEmail.isNotEmpty ? fallbackEmail : null);

    if (cachedText != null) {
      return _SenderLabel(text: cachedText);
    }

    return FutureBuilder<String?>(
      future: chatService.getUserEmail(message.senderId),
      builder: (context, snapshot) {
        final label = (snapshot.data ?? message.senderId).trim();
        return _SenderLabel(text: label);
      },
    );
  }
}

class _SenderLabel extends StatelessWidget {
  const _SenderLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }
}
