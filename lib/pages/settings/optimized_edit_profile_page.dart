import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/constant.dart';
import '../../services/profile_service.dart';

class OptimizedEditProfilePage extends StatefulWidget {
  const OptimizedEditProfilePage({super.key});

  @override
  State<OptimizedEditProfilePage> createState() =>
      _OptimizedEditProfilePageState();
}

class _OptimizedEditProfilePageState extends State<OptimizedEditProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();

  late AnimationController _saveAnimationController;
  late Animation<double> _saveAnimation;

  bool _isSaving = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _saveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _saveAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _saveAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Iconsax.arrow_left_2),
        ),
        actions: [
          Consumer<ProfileService>(
            builder: (context, profileService, child) {
              return TextButton(
                onPressed:
                    _isSaving ? null : () => _saveProfile(profileService),
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : AnimatedBuilder(
                          animation: _saveAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.9 + (0.1 * _saveAnimation.value),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ProfileService>(
        builder: (context, profileService, child) {
          if (profileService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileService.error != null) {
            return _buildErrorState(profileService.error!);
          }

          // Initialize form fields if they're empty
          if (_fullNameController.text.isEmpty) {
            _fullNameController.text = profileService.fullName;
            _phoneNumberController.text = profileService.phoneNumber;
            _addressController.text = profileService.address;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(Insets.lg),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildProfilePhotoSection(profileService),
                  SizedBox(height: Insets.xl),
                  _buildFormFields(),
                  SizedBox(height: Insets.xl),
                  _buildSaveButton(profileService),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, color: AppColor.accentRed, size: 64),
          SizedBox(height: Insets.lg),
          Text(
            'Error Loading Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColor.accentRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: Insets.sm),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Insets.xl),
          ElevatedButton(
            onPressed: () {
              context.read<ProfileService>().refresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhotoSection(ProfileService profileService) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColor.primary.withAlpha(51),
                    AppColor.accentGreen.withAlpha(51),
                  ],
                ),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(51),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child:
                    _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : profileService.hasProfilePhoto
                        ? Image.network(
                          profileService.profilePhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        )
                        : _buildDefaultAvatar(),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColor.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 3,
                  ),
                ),
                child: IconButton(
                  onPressed: () => _showImagePicker(profileService),
                  icon: const Icon(
                    Iconsax.camera,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: Insets.md),
        Text(
          'Profile Photo',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Insets.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => _showImagePicker(profileService),
              icon: const Icon(Iconsax.camera, size: 16),
              label: const Text('Change Photo'),
              style: TextButton.styleFrom(foregroundColor: AppColor.primary),
            ),
            if (profileService.hasProfilePhoto || _selectedImage != null) ...[
              SizedBox(width: Insets.md),
              TextButton.icon(
                onPressed: () => _removePhoto(profileService),
                icon: const Icon(Iconsax.trash, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColor.accentRed,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Iconsax.user,
        size: 48,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name',
          icon: Iconsax.user,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Full name is required';
            }
            if (value.trim().length < 2) {
              return 'Full name must be at least 2 characters';
            }
            return null;
          },
        ),
        SizedBox(height: Insets.lg),
        _buildTextField(
          controller: _phoneNumberController,
          label: 'Phone Number',
          icon: Iconsax.call,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Phone number is required';
            }
            if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(value.trim())) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
        SizedBox(height: Insets.lg),
        _buildTextField(
          controller: _addressController,
          label: 'Address',
          icon: Iconsax.location,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Address is required';
            }
            if (value.trim().length < 5) {
              return 'Address must be at least 5 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.md),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.md),
          borderSide: BorderSide(color: AppColor.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  Widget _buildSaveButton(ProfileService profileService) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveProfile(profileService),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: Insets.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.md),
          ),
          elevation: 0,
        ),
        child:
            _isSaving
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
      ),
    );
  }

  Future<void> _showImagePicker(ProfileService profileService) async {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: EdgeInsets.all(Insets.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Photo',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: Insets.lg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                        icon: const Icon(Iconsax.camera),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: Insets.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                        icon: const Icon(Iconsax.gallery),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.accentGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto(ProfileService profileService) async {
    final success = await profileService.deleteProfilePhoto();

    if (success && mounted) {
      setState(() {
        _selectedImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo removed successfully'),
          backgroundColor: AppColor.accentGreen,
        ),
      );
    }
  }

  Future<void> _saveProfile(ProfileService profileService) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    _saveAnimationController.forward();

    try {
      // Update profile data
      final success = await profileService.updateProfile(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (success) {
        // Upload new photo if selected
        if (_selectedImage != null) {
          await profileService.uploadProfilePhoto(_selectedImage!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: AppColor.accentGreen,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: AppColor.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _saveAnimationController.reset();
      }
    }
  }
}
