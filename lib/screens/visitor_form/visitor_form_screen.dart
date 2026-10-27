import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_exception.dart';
import '../../core/feedback.dart';
import '../../core/validators.dart';
import '../../models/visitor.dart';
import '../../providers/visitor_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../visitor_details/visitor_details_screen.dart';

class VisitorFormScreen extends StatefulWidget {
  const VisitorFormScreen({super.key, this.visitor});

  /// When set, the form edits this visitor instead of registering a new one.
  final Visitor? visitor;

  @override
  State<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends State<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _purposeController;

  String? _visitorType;
  String? _project;
  bool _isSaving = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _isEditing => widget.visitor != null;

  @override
  void initState() {
    super.initState();
    final visitor = widget.visitor;
    _nameController = TextEditingController(text: visitor?.name);
    _mobileController = TextEditingController(text: visitor?.mobile);
    _emailController = TextEditingController(text: visitor?.email);
    _purposeController = TextEditingController(text: visitor?.purpose);
    _visitorType = visitorTypes.contains(visitor?.visitorType) ? visitor!.visitorType : null;
    _project = projects.contains(visitor?.project) ? visitor!.project : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      showAppSnackBar(context, 'Please fix the highlighted fields', isError: true);
      return;
    }

    final draft = VisitorDraft(
      name: _nameController.text,
      mobile: _mobileController.text,
      email: _emailController.text,
      visitorType: _visitorType!,
      project: _project!,
      purpose: _purposeController.text,
    );

    setState(() => _isSaving = true);
    final provider = context.read<VisitorProvider>();

    try {
      if (_isEditing) {
        await provider.editVisitor(widget.visitor!.id, draft);
        if (!mounted) return;
        showAppSnackBar(context, 'Visitor details updated');
        Navigator.of(context).pop();
      } else {
        final visitor = await provider.registerVisitor(draft);
        if (!mounted) return;
        showAppSnackBar(context, '${visitor.name} registered successfully');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VisitorDetailsScreen(
              visitorId: visitor.id,
              justRegistered: true,
              refreshOnOpen: false,
            ),
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit visitor' : 'Register visitor')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  _isEditing
                      ? 'Update the visitor\'s details below.'
                      : 'Fill in the visitor\'s details. A QR pass is generated once saved.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameController,
                  label: 'Visitor name',
                  hint: 'e.g. Rahul Sharma',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.required(value, 'Visitor name'),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _mobileController,
                  label: 'Mobile number',
                  hint: '10 digit mobile number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: Validators.mobile,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'name@example.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  optional: true,
                  validator: Validators.optionalEmail,
                ),
                const SizedBox(height: 18),
                AppDropdownField(
                  label: 'Visitor type',
                  icon: Icons.badge_outlined,
                  options: visitorTypes,
                  initialValue: _visitorType,
                  onChanged: (value) => _visitorType = value,
                  validator: (value) => Validators.selection(value, 'visitor type'),
                ),
                const SizedBox(height: 18),
                AppDropdownField(
                  label: 'Project',
                  icon: Icons.apartment_rounded,
                  options: projects,
                  initialValue: _project,
                  onChanged: (value) => _project = value,
                  validator: (value) => Validators.selection(value, 'a project'),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _purposeController,
                  label: 'Purpose of visit',
                  hint: 'e.g. Site visit, Material delivery',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  validator: (value) => Validators.required(value, 'Purpose of visit'),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outlined(
                        label: 'Cancel',
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: _isEditing ? 'Save changes' : 'Register visitor',
                        icon: _isEditing ? Icons.check_rounded : Icons.qr_code_2_rounded,
                        isLoading: _isSaving,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
