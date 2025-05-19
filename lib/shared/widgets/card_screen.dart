import 'package:flutter/material.dart';

class CardScreen extends StatelessWidget {
  const CardScreen({
    required this.children,
    required this.formKey,
    required this.isLoading,
    super.key,
  });

  final List<Widget> children;
  final GlobalKey<FormState> formKey;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                child: Form(
                  key: formKey,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
