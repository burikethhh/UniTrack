import 'package:flutter/material.dart';

/// Custom text field with ISKSULARS TRACK styling
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool autofocus;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    // Inherit the global inputDecorationTheme (fillColor, borders, labelStyle,
    // hintStyle) and only override what's widget-specific. Previously this
    // constructed a fresh InputDecoration that silently bypassed the theme.
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
    final iconColor = theme.inputDecorationTheme.prefixIconColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: TextStyle(fontSize: 16, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: iconColor)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Password text field with visibility toggle
class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  const PasswordTextField({
    super.key,
    this.controller,
    this.label = 'Password',
    this.hint,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textInputAction = TextInputAction.done,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      errorText: widget.errorText,
      obscureText: _obscureText,
      prefixIcon: Icons.lock_outline,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      validator: widget.validator,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
    );
  }
}
