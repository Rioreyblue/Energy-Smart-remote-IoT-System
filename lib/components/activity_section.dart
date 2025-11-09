import 'package:flutter/material.dart';
import 'package:exercise_app/constants/constant.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import '../services/recent_activity_service.dart';

class ActivitySection extends StatelessWidget {
  final double Function(BuildContext, double) responsiveFontSize;
  const ActivitySection({required this.responsiveFontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: RecentActivityService().listenRecentActivities(
                  limit: 10,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return Text(
                      '${snapshot.data!.length} activities',
                      style: TextStyle(
                        fontSize: responsiveFontSize(context, 12),
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          SizedBox(height: Insets.md),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: RecentActivityService().listenRecentActivities(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final activities = snapshot.data!;
              return Column(
                children:
                    activities.map((activity) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: Insets.sm),
                        child: _ActivityItem(
                          activity: activity,
                          responsiveFontSize: responsiveFontSize,
                        ),
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Iconsax.warning_2, color: Colors.orange, size: 32),
          const SizedBox(height: 8),
          Text(
            'Error loading activities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          ),
          Text(
            error,
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Iconsax.activity, color: Colors.grey, size: 32),
          const SizedBox(height: 8),
          Text(
            'No recent activities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            'Your energy activities will appear here',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;
  final double Function(BuildContext, double) responsiveFontSize;

  const _ActivityItem({
    required this.activity,
    required this.responsiveFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final type = activity['type'] ?? '';
    final message = activity['message'] ?? '';
    final timestamp = activity['timestamp'];
    final Map<String, dynamic> meta =
        (activity['meta'] as Map<String, dynamic>?) ?? const {};

    // Get icon and color based on activity type
    final iconData = _getActivityIcon(type, meta);
    final iconColor = _getActivityColor(type);

    // Format timestamp
    final timeString = _formatTimestamp(timestamp);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: iconColor.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: iconColor, size: 16),
        ),
        SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                timeString,
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 12),
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getActivityIcon(String type, Map<String, dynamic> meta) {
    // If applianceIcon from meta exists, map it to corresponding Iconsax icon
    final iconString = meta['applianceIcon'] as String?;
    if (iconString != null && iconString.isNotEmpty) {
      final mapped = _mapIconStringToIconData(iconString);
      if (mapped != null) return mapped;
    }
    // Fallback to type-based icon
    switch (type) {
      case 'appliance_on':
        return Iconsax.lamp;
      case 'appliance_off':
        return Iconsax.lamp_1;
      case 'threshold_reached':
        return Iconsax.warning_2;
      case 'goal_achieved':
        return Iconsax.tick_circle;
      case 'daily_summary':
        return Iconsax.chart_2;
      case 'energy_alert':
        return Iconsax.flash_1;
      case 'cost_alert':
        return Iconsax.wallet;
      default:
        return Iconsax.activity;
    }
  }

  IconData? _mapIconStringToIconData(String icon) {
    switch (icon) {
      case 'Iconsax.lamp':
        return Iconsax.lamp;
      case 'Iconsax.lamp_1':
        return Iconsax.lamp_1;
      case 'Iconsax.lamp_charge':
        return Iconsax.lamp_charge;
      case 'Iconsax.socket':
        return Iconsax.electricity;
      case 'Iconsax.coffee':
        return Iconsax.coffee;
      case 'Iconsax.air_conditioner':
        return Iconsax.wind;
      case 'Iconsax.water':
        return Iconsax.drop;
      case 'Iconsax.monitor':
        return Iconsax.monitor;
      case 'Iconsax.fan':
        return Iconsax.wind;
      case 'Iconsax.refresh':
        return Iconsax.refresh;
      case 'Iconsax.home':
        return Iconsax.home;
      default:
        return null;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'appliance_on':
        return AppColor.accentGreen;
      case 'appliance_off':
        return AppColor.mediumConsumption;
      case 'threshold_reached':
        return Colors.orange;
      case 'goal_achieved':
        return AppColor.accentGreen;
      case 'daily_summary':
        return AppColor.lowConsumption;
      case 'energy_alert':
        return Colors.red;
      case 'cost_alert':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    // Fallback if missing timestamp
    if (timestamp == null) return 'Just now';

    try {
      DateTime dateTime;

      // Handle common Firestore/Flutter timestamp shapes
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp is Map && timestamp['_seconds'] != null) {
        final seconds = (timestamp['_seconds'] as num).toInt();
        dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } else if (timestamp is int) {
        // millisecondsSinceEpoch
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        // ISO8601 or date string
        dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
      } else {
        return 'Just now';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) {
        final f = DateFormat('h:mm a');
        return f.format(dateTime);
      }
      if (difference.inDays == 1) {
        final f = DateFormat('h:mm a');
        return 'Yesterday · ${f.format(dateTime)}';
      }
      // Older than 2 days: show concise date + time
      final f = DateFormat('MMM d, yyyy · h:mm a');
      return f.format(dateTime);
    } catch (e) {
      return 'Just now';
    }
  }
}
