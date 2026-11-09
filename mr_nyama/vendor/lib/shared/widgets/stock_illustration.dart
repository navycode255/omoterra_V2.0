import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/theme.dart';

/// Vector redraw of the empty-stock reference; remains sharp at any density.
class MNStockIllustration extends StatelessWidget {
  const MNStockIllustration({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 128,
        height: 128,
        decoration: const BoxDecoration(
            color: MNColors.roseSurface, shape: BoxShape.circle),
        child: Center(
            child: SvgPicture.string(
                '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
      <g fill="none" stroke="#E30613" stroke-width="5" stroke-linecap="round"><path d="M60 12v10M31 24l7 8M89 24l-7 8"/></g>
      <path d="M24 46L60 28l36 18v38l-36 19-36-19z" fill="#FFE8CF"/>
      <path d="M60 65l36-19v38l-36 19z" fill="#F3BF89"/>
      <path d="M43 37l36 19v14l-6 3V59L37 41z" fill="white"/>
      <g fill="none" stroke="#141414" stroke-width="5" stroke-linejoin="round"><path d="M24 46L60 28l36 18v38l-36 19-36-19zM24 46l36 19 36-19M60 65v38"/></g>
    </svg>''',
                width: 88, height: 88)),
      );
}
