import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exercise_app/constants/constant.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onCompleted});

  final Future<void> Function()? onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final List<String> _lottieAssets = [
    'assets/A_2.json',
    'assets/A_7.json',
    'assets/A_3.json',
    'assets/A_6.json',
  ];

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Welcome to EnergySmart',
      'body':
          'Take control of your energy usage. Monitor, track, and manage electricity smarter than ever.',
      'features': ['Smart', 'Efficient', 'Sustainable'],
    },
    {
      'title': 'Real-Time Monitoring',
      'body':
          'Stay updated, every second. Track your appliance usage and view live energy data.',
      'features': ['Live Data', 'Usage Stats', 'Power Tracking'],
    },
    {
      'title': 'Smart Alerts & Insights',
      'body':
          'Receive usage alerts, bill estimates, and tips to reduce electricity costs.',
      'features': ['Notifications', 'Insights', 'Savings'],
    },
    {
      'title': 'Personalized Energy Goals',
      'body':
          'Set saving goals, track progress, and build a more sustainable space.',
      'features': ['Goals', 'Progress', 'Achievement'],
    },
  ];

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'hasCompletedOnboarding': true,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      if (widget.onCompleted != null) {
        await widget.onCompleted!.call();
      } else {
        context.go('/');
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColor.accentGreen.withAlpha(13), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: _completeOnboarding,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: AppColor.accentGreen.withAlpha(26),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColor.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemCount: _lottieAssets.length,
                  itemBuilder: (context, index) {
                    return _buildPage(
                      _pages[index]['title'],
                      _pages[index]['body'],
                      _lottieAssets[index],
                      _pages[index]['features'],
                      size,
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_lottieAssets.length, (index) {
                        final isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: isActive ? 18 : 6,
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? AppColor.primary
                                    : AppColor.textSecondary.withAlpha(128),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentPage > 0)
                          GestureDetector(
                            onTap: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                color: AppColor.accentGreen.withAlpha(26),
                              ),
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(right: 20),
                              child: Icon(
                                Icons.arrow_back,
                                color: AppColor.accentGreen,
                              ),
                            ),
                          ),
                        ElevatedButton(
                          onPressed:
                              _isCompleting
                                  ? null
                                  : () {
                                    if (_currentPage <
                                        _lottieAssets.length - 1) {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    } else {
                                      _completeOnboarding();
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: AppColor.primary.withAlpha(77),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child:
                                _isCompleting
                                    ? SizedBox(
                                      key: const ValueKey('loading'),
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Text(
                                      key: const ValueKey('label'),
                                      _currentPage < _lottieAssets.length - 1
                                          ? 'Next'
                                          : 'Get Started',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    String title,
    String body,
    String lottieAsset,
    List<String> features,
    Size size,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: size.height * 0.35,
              width: size.width * 0.8,
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.primary.withAlpha(26),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Lottie.asset(lottieAsset, fit: BoxFit.contain),
              ),
            ),
          ),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              children:
                  features.map((feature) {
                    return Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColor.primary.withAlpha(51),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        feature,
                        style: const TextStyle(
                          color: AppColor.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColor.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColor.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
