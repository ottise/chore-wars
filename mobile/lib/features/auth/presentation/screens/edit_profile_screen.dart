import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/domain/entities/auth_models.dart';
import '../providers/auth_providers.dart';
import '../../../../core/utils/api_error_message.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({required this.profile, super.key});

  final UserProfile profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameCtrl;
  bool _isLoading = false;
  File? _selectedImage;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(text: widget.profile.displayName);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatarUrl = widget.profile.avatarUrl != null && widget.profile.avatarUrl!.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!) as ImageProvider
                        : (hasAvatarUrl
                            ? CachedNetworkImageProvider('${AppConstants.apiBaseUrl}${widget.profile.avatarUrl}')
                            : null),
                    child: (_selectedImage == null && !hasAvatarUrl)
                        ? const Icon(Icons.camera_alt, size: 40, color: AppTheme.purple)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _pickImage,
                  child: const Text('Change Avatar'),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _displayNameCtrl,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Display name cannot be empty';
                    }
                    if (v.trim().length < 2) return 'At least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Email cannot be changed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: 'Save changes',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final newName = _displayNameCtrl.text.trim();
    if (newName == widget.profile.displayName && _selectedImage == null) {
      context.pop();
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_selectedImage != null) {
        await ref.read(authRepositoryProvider).uploadAvatar(_selectedImage!.path);
      }
      if (newName != widget.profile.displayName) {
        await ref.read(authRepositoryProvider).updateProfile(displayName: newName);
      }
      ref.invalidate(userProfileProvider);
      if (mounted) {
        showAppMessage(context, 'Profile updated.');
        context.pop();
      }
    } catch (error) {
      if (mounted) showAppMessage(context, apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
