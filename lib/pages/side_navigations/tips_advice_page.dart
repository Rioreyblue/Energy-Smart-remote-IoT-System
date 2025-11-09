import 'package:flutter/material.dart';
import '../../constants/constant.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class TipsAdvicePage extends StatefulWidget {
  const TipsAdvicePage({super.key});

  @override
  State<TipsAdvicePage> createState() => _TipsAdvicePageState();
}

class _TipsAdvicePageState extends State<TipsAdvicePage> {
  final Set<int> _expandedIndices = {};

  final List<Map<String, dynamic>> _tips = [
    {
      'title': 'Unplug Devices',
      'shortDesc': 'Unplug electronics when not in use to save energy.',
      'detailedDesc':
          'Many electronic devices consume "phantom" or "vampire" power even when turned off. Unplugging devices like phone chargers, TVs, computers, and gaming consoles can save 5-10% on your electricity bill. Consider using power strips with switches for easier management.',
      'icon': Iconsax.electricity,
      'category': 'Appliances',
      'savings': '5-10% monthly',
      'color': AppColor.accentGreen,
    },
    {
      'title': 'Use LED Bulbs',
      'shortDesc': 'Switch to LED bulbs for lower consumption.',
      'detailedDesc':
          'LED bulbs use up to 80% less energy than traditional incandescent bulbs and last 25 times longer. They also produce less heat, reducing cooling costs. Replace your most frequently used bulbs first for maximum impact. A single LED bulb can save you ₱500-800 per year compared to incandescent bulbs.',
      'icon': Iconsax.lamp_on,
      'category': 'Lighting',
      'savings': '80% energy reduction',
      'color': AppColor.lowConsumption,
    },
    {
      'title': 'Set AC to 24°C',
      'shortDesc': 'Optimal AC temperature for savings.',
      'detailedDesc':
          'Each degree above 22°C can save 3-5% on cooling costs. Setting your AC to 24-25°C is ideal for comfort and efficiency. Use programmable thermostats to automatically adjust temperature when you\'re away. Keep windows and doors closed, and use ceiling fans to help circulate air.',
      'icon': Iconsax.element_3,
      'category': 'HVAC',
      'savings': '10-15% cooling costs',
      'color': AppColor.mediumConsumption,
    },
    {
      'title': 'Seal Air Leaks',
      'shortDesc': 'Prevent energy loss through gaps and cracks.',
      'detailedDesc':
          'Air leaks around windows, doors, and electrical outlets can waste 10-20% of your heating and cooling energy. Use weatherstripping for doors and windows, caulk gaps around windows and baseboards, and install outlet covers. This simple fix can significantly reduce your energy bills.',
      'icon': Iconsax.home,
      'category': 'Insulation',
      'savings': '10-20% HVAC costs',
      'color': AppColor.accentGreen,
    },
    {
      'title': 'Wash Clothes in Cold Water',
      'shortDesc': 'Use cold water for laundry to save energy.',
      'detailedDesc':
          'About 90% of the energy used by washing machines goes to heating water. Washing clothes in cold water can save significant energy and money. Modern detergents work effectively in cold water, and it helps preserve fabric colors and reduce shrinkage.',
      'icon': Iconsax.lovely,
      'category': 'Appliances',
      'savings': '90% washing energy',
      'color': AppColor.lowConsumption,
    },
    {
      'title': 'Use Smart Power Strips',
      'shortDesc': 'Automatically cut power to unused devices.',
      'detailedDesc':
          'Smart power strips detect when devices are in standby mode and automatically cut power to save energy. They\'re especially useful for entertainment centers, home offices, and gaming setups. Some models allow you to designate "always-on" devices while others turn off completely.',
      'icon': Iconsax.smart_home,
      'category': 'Appliances',
      'savings': '5-10% monthly',
      'color': AppColor.accentGreen,
    },
    {
      'title': 'Maintain Your Refrigerator',
      'shortDesc': 'Keep your fridge running efficiently.',
      'detailedDesc':
          'Clean condenser coils every 6 months, check door seals for leaks, and maintain proper temperature settings (2-3°C for fridge, -18°C for freezer). Don\'t overload your fridge, and avoid placing hot food inside. A well-maintained refrigerator uses 15-20% less energy.',
      'icon': Iconsax.refresh,
      'category': 'Appliances',
      'savings': '15-20% energy',
      'color': AppColor.lowConsumption,
    },
    {
      'title': 'Use Natural Light',
      'shortDesc': 'Maximize daylight to reduce lighting costs.',
      'detailedDesc':
          'Open curtains and blinds during the day to use natural light instead of artificial lighting. Position workspaces near windows. Natural light not only saves energy but also improves mood and productivity. Consider installing skylights in darker areas of your home.',
      'icon': Iconsax.sun_1,
      'category': 'Lighting',
      'savings': 'Varies by usage',
      'color': AppColor.mediumConsumption,
    },
    {
      'title': 'Upgrade to Energy Star Appliances',
      'shortDesc': 'Replace old appliances with energy-efficient models.',
      'detailedDesc':
          'Energy Star certified appliances use 10-50% less energy than standard models. When replacing appliances, look for the Energy Star label. While upfront costs may be higher, the long-term savings on energy bills make them a wise investment. Focus on high-energy appliances like refrigerators, air conditioners, and water heaters first.',
      'icon': Iconsax.star,
      'category': 'Appliances',
      'savings': '10-50% per appliance',
      'color': AppColor.accentGreen,
    },
    {
      'title': 'Install Ceiling Fans',
      'shortDesc': 'Use fans to reduce AC dependency.',
      'detailedDesc':
          'Ceiling fans can make a room feel 4-6°C cooler, allowing you to raise your thermostat and save on cooling costs. Fans use about 90% less energy than air conditioners. Remember to turn fans off when you leave the room since they cool people, not spaces.',
      'icon': Iconsax.wind,
      'category': 'HVAC',
      'savings': 'Up to 40% cooling costs',
      'color': AppColor.lowConsumption,
    },
    {
      'title': 'Insulate Your Water Heater',
      'shortDesc': 'Wrap your water heater to retain heat.',
      'detailedDesc':
          'Insulating your water heater tank can reduce heat loss by 25-45%, saving 4-9% on water heating costs. Use an insulating blanket specifically designed for water heaters. Also, lower the temperature to 49-54°C - most households don\'t need it hotter and it reduces energy waste.',
      'icon': Iconsax.element_4,
      'category': 'Water Heating',
      'savings': '4-9% water heating',
      'color': AppColor.mediumConsumption,
    },
    {
      'title': 'Plant Shade Trees',
      'shortDesc': 'Use trees to naturally cool your home.',
      'detailedDesc':
          'Strategically placed trees can reduce cooling costs by up to 25% by shading your home from direct sunlight. Deciduous trees provide shade in summer and allow sunlight through in winter. Plant trees on the east and west sides of your home for maximum benefit.',
      'icon': Iconsax.tree,
      'category': 'Outdoor',
      'savings': 'Up to 25% cooling',
      'color': AppColor.lowConsumption,
    },
    {
      'title': 'Use Microwave Instead of Oven',
      'shortDesc': 'Microwaves are more energy-efficient for cooking.',
      'detailedDesc':
          'Microwaves use 50-80% less energy than conventional ovens for similar cooking tasks. Use your microwave for reheating and cooking small portions. For larger meals, consider using a slow cooker or pressure cooker, which are also more efficient than ovens.',
      'icon': Iconsax.radar,
      'category': 'Cooking',
      'savings': '50-80% cooking energy',
      'color': AppColor.accentGreen,
    },
    {
      'title': 'Clean Air Filters Regularly',
      'shortDesc': 'Maintain HVAC filters for optimal efficiency.',
      'detailedDesc':
          'Dirty air filters force your HVAC system to work harder, increasing energy consumption by 5-15%. Check filters monthly and replace them every 1-3 months, or more frequently if you have pets or allergies. This simple maintenance task can significantly improve air quality and reduce energy costs.',
      'icon': Iconsax.filter,
      'category': 'HVAC',
      'savings': '5-15% HVAC energy',
      'color': AppColor.mediumConsumption,
    },
    {
      'title': 'Use Laptop Instead of Desktop',
      'shortDesc': 'Laptops consume less energy than desktops.',
      'detailedDesc':
          'Laptops typically use 50-80% less energy than desktop computers. If you work from home, consider using a laptop for your computing needs. When using a desktop, enable power-saving modes and turn off the monitor when not in use. Also, unplug chargers when devices are fully charged.',
      'icon': Iconsax.monitor,
      'category': 'Electronics',
      'savings': '50-80% computer energy',
      'color': AppColor.lowConsumption,
    },
  ];

  void _toggleCard(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Tips & Advice'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_1, color: theme.iconTheme.color),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              'Energy Saving Tips',
              style: ResponsiveText.headline(context),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),
            const SizedBox(height: Insets.sm),
            Text(
                  'Discover practical ways to reduce your energy consumption and save money on your electricity bills.',
                  style: ResponsiveText.body(context).copyWith(
                    color:
                        isDark
                            ? AppColor.textSecondaryDark
                            : AppColor.textSecondary,
                  ),
                )
                .animate()
                .fadeIn(duration: 300.ms, delay: 100.ms)
                .slideY(begin: -0.2, end: 0),
            const SizedBox(height: Insets.xl),

            // Tips List
            ...List.generate(
              _tips.length,
              (index) => _TipCard(
                    tip: _tips[index],
                    isExpanded: _expandedIndices.contains(index),
                    onTap: () => _toggleCard(index),
                    index: index,
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (index * 50).ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 400.ms,
                    delay: (index * 50).ms,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Map<String, dynamic> tip;
  final bool isExpanded;
  final VoidCallback onTap;
  final int index;

  const _TipCard({
    required this.tip,
    required this.isExpanded,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = tip['color'] as Color;
    final icon = tip['icon'] as IconData;

    return Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isExpanded
                            ? color.withAlpha(128)
                            : (isDark
                                ? AppColor.surfaceDark.withAlpha(51)
                                : AppColor.surface.withAlpha(51)),
                    width: isExpanded ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isExpanded ? 38 : 13),
                      blurRadius: isExpanded ? 12 : 8,
                      offset: Offset(0, isExpanded ? 4 : 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Icon Container
                        Container(
                          padding: const EdgeInsets.all(Insets.md),
                          decoration: BoxDecoration(
                            color: color.withAlpha(38),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: Insets.md),
                        // Title and Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title'] as String,
                                style: ResponsiveText.title(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tip['shortDesc'] as String,
                                style: ResponsiveText.body(context).copyWith(
                                  color:
                                      isDark
                                          ? AppColor.textSecondaryDark
                                          : AppColor.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Expand/Collapse Indicator
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Iconsax.arrow_down_1,
                            color:
                                isDark
                                    ? AppColor.textSecondaryDark
                                    : AppColor.textSecondary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),

                    // Expanded Content
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child:
                          isExpanded
                              ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: Insets.md),
                                  Divider(
                                    color:
                                        isDark
                                            ? AppColor.surfaceDark
                                            : AppColor.surface,
                                    thickness: 1,
                                  ),
                                  const SizedBox(height: Insets.md),
                                  Text(
                                    tip['detailedDesc'] as String,
                                    style: ResponsiveText.body(
                                      context,
                                    ).copyWith(
                                      height: 1.6,
                                      color:
                                          isDark
                                              ? AppColor.textPrimaryDark
                                              : AppColor.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: Insets.md),
                                  // Savings Badge
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: Insets.md,
                                          vertical: Insets.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withAlpha(51),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: color.withAlpha(128),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Iconsax.chart_success,
                                              size: 16,
                                              color: color,
                                            ),
                                            const SizedBox(width: Insets.sm),
                                            Text(
                                              'Savings: ${tip['savings'] as String}',
                                              style: ResponsiveText.label(
                                                context,
                                              ).copyWith(
                                                color: color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: Insets.sm),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: Insets.md,
                                          vertical: Insets.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isDark
                                                  ? AppColor.surfaceDark
                                                  : AppColor.surface)
                                              .withAlpha(204),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          tip['category'] as String,
                                          style: ResponsiveText.caption(
                                            context,
                                          ).copyWith(
                                            color:
                                                isDark
                                                    ? AppColor.textSecondaryDark
                                                    : AppColor.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(target: isExpanded ? 1 : 0)
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.02, 1.02),
          duration: 200.ms,
        );
  }
}
