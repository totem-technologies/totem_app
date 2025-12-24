import 'package:flutter/material.dart';

class HomeLoadingScreen extends StatelessWidget {
  const HomeLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator.adaptive(strokeWidth: 1.5),
    );
    // return ListView(
    //   physics: const NeverScrollableScrollPhysics(),
    //   children: [
    //     Padding(
    //       padding: const EdgeInsetsDirectional.all(16),
    //       child: SpaceCard.shimmer(),
    //     ),
    //     SizedBox(
    //       height: 180,
    //       child: ListView.separated(
    //         itemCount: 3,
    //         scrollDirection: Axis.horizontal,
    //         padding: const EdgeInsetsDirectional.all(16),
    //         itemBuilder: (context, index) {
    //           return SpaceCard.shimmer(compact: true);
    //         },
    //         separatorBuilder: (context, index) => const SizedBox(width: 16),
    //       ),
    //     ),
    //     GridView.builder(
    //       padding: const EdgeInsetsDirectional.all(16),
    //       physics: const NeverScrollableScrollPhysics(),
    //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    //         crossAxisCount: 2,
    //         childAspectRatio: 16 / 21,
    //         crossAxisSpacing: 16,
    //         mainAxisSpacing: 16,
    //       ),
    //       itemBuilder: (context, index) {
    //         return SpaceCard.shimmer(compact: true);
    //       },
    //       itemCount: 6,
    //       shrinkWrap: true,
    //     ),
    //   ],
    // );
  }
}
