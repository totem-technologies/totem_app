import 'package:flutter/material.dart';

class CardScreen extends StatefulWidget {
  const CardScreen({
    required this.children,
    required this.isLoading,
    this.formKey,
    super.key,
  });

  final List<Widget> children;
  final GlobalKey<FormState>? formKey;
  final bool isLoading;

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: !widget.isLoading,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                child: Form(
                  key: widget.formKey,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
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

  @override
  bool get wantKeepAlive => true;
}
