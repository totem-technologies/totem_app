import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/blog/widgets/blog_detail_app_bar.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  @override
  Widget build(BuildContext context) {
    final blogRef = ref.watch(blogPostProvider(widget.slug));
    final theme = Theme.of(context);

    return Scaffold(
      body: blogRef.when(
        data: (blog) {
          return RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(blogPostProvider(widget.slug).future),
            child: CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  centerTitle: true,
                  expandedHeight: MediaQuery.sizeOf(context).height * 0.4,
                  automaticallyImplyLeading: false,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: BlogDetailAppBar(event: blog),
                  ),

                  leading: Container(
                    margin: const EdgeInsetsDirectional.only(start: 20),
                    alignment: Alignment.center,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.adaptive.arrow_back),
                        iconSize: 24,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => popOrHome(context),
                      ),
                    ),
                  ),
                  actionsPadding: const EdgeInsetsDirectional.only(end: 20),
                  actions: [
                    Container(
                      height: 36,
                      alignment: Alignment.center,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Builder(
                          builder: (context) {
                            return IconButton(
                              icon: Icon(Icons.adaptive.share),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                SharePlus.instance.share(
                                  ShareParams(
                                    uri: Uri.parse(
                                      'https://totem.org/blog/${blog.slug}?utm_source=app&utm_medium=share',
                                    ),
                                    sharePositionOrigin: box != null
                                        ? box.localToGlobal(Offset.zero) &
                                              box.size
                                        : null,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  title: Text(blog.title),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Html(data: blog.contentHtml),
                  ),
                ),
              ],
            ),
          );
        },
        error: (error, stackTrace) {
          debugPrint('Error loading blog post: $error');
          debugPrint('Stack trace: $stackTrace');
          return const Center(child: Text('Error loading blog post'));
        },
        loading: () {
          return const LoadingIndicator();
        },
      ),
    );
  }
}
