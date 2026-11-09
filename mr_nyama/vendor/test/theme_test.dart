import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';

/// The approved Claude Design export, unpacked to its design-system CSS.
String designCss() {
  final html = File(
          '../../docs/mr_nyama/design/html/design-system-signature-b-fire-sweep.html')
      .readAsStringSync();
  final script = RegExp(
          r'<script type="__bundler/template"[^>]*>(.*?)</script>',
          dotAll: true)
      .firstMatch(html)!
      .group(1)!;
  return jsonDecode(script) as String;
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final css = designCss();

  void expectCss(String declaration) =>
      expect(css.toUpperCase().contains(declaration.toUpperCase()), isTrue,
          reason: 'design CSS should contain "$declaration"');

  group('tokens match the approved design CSS', () {
    test('brand and status colours', () {
      expectCss('.btn-p{background:${hex(MNColors.red)}');
      expectCss(
          '.btn-p:active:not(:disabled){background:${hex(MNColors.redPressed)}');
      expectCss('.bar{height:56px;background:${hex(MNColors.black)}');
      expectCss('color:${hex(MNColors.ink)}');
      // Written as the shorthand #555 in the CSS.
      expectCss('.ink2{color:#555}');
      expect(hex(MNColors.ink2), '#555555');
      expectCss('.mute{color:${hex(MNColors.muted)}');
      expectCss('.ok{color:${hex(MNColors.success)}');
      expectCss('.okd{color:${hex(MNColors.successOnDark)}');
      expectCss('.warn{color:${hex(MNColors.warning)}');
      expectCss('.err{color:${hex(MNColors.error)}');
      expectCss('.note.w{background:${hex(MNColors.warningSurface)}');
      expectCss('.note.e{background:${hex(MNColors.errorSurface)}');
      expectCss('.note.s{background:${hex(MNColors.successSurface)}');
      expectCss(
          '.btn-x{background:${hex(MNColors.disabled)};color:${hex(MNColors.disabledText)}');
      expectCss(
          '.key{height:64px;border-radius:12px;background:${hex(MNColors.surface)}');
      expectCss('border-top:1px solid ${hex(MNColors.border)}');
      expectCss('border:1.5px solid ${hex(MNColors.borderStrong)}');
      expectCss('background:${hex(MNColors.imageBackground)}');
      expectCss('.btn-t:active{background:${hex(MNColors.textPressed)}');
      expectCss(
          '.avatar{width:40px;height:40px;border-radius:50%;background:${hex(MNColors.avatar)}');
    });

    test('sizes and radii', () {
      expectCss(
          '.btn{height:${MNSize.button.toInt()}px;border-radius:${MNRadius.medium.toInt()}px');
      expectCss(
          '.nav{height:64px'); // Original export; owner updated reference.
      expect(MNSize.navBar, 56);
      expectCss('.ib{width:${MNSize.iconButton.toInt()}px');
      expectCss(
          '.qb{width:${MNSize.quantity.toInt()}px;height:48px;border-radius:${MNRadius.small.toInt()}px');
      expectCss('.qb.L{width:${MNSize.quantityLarge.toInt()}px');
      expectCss('.field{height:${MNSize.field.toInt()}px');
      expectCss('min-height:${MNSize.row.toInt()}px');
      expectCss(
          '.pc-img{position:relative;height:${MNSize.productImage.toInt()}px');
      expectCss('.tile{height:${MNSize.tile.toInt()}px');
      expectCss(
          '.sheet{position:absolute;left:0;right:0;bottom:0;background:#fff;border-radius:${MNRadius.sheet.toInt()}px');
      expectCss('.dot{width:${MNSize.pinDot.toInt()}px');
      expectCss('.chip{height:${MNSize.chip.toInt()}px');
    });

    test('type scale', () {
      expectCss('.big{font:800 34px/40px');
      expectCss('.h1{font:800 22px/28px');
      expectCss('.bar h1{flex:1;font:700 18px/24px');
      expectCss('font:700 17px/20px');
      expectCss('.rt{font:700 16px/22px');
      expectCss('.body{font:500 16px/22px');
      expectCss('.rs{font:500 14px/20px');
      expectCss(
          '.nv{border:0;background:none;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;font:700 12px/16px');
      expect(MNText.amountLarge.fontSize, 34);
      expect(MNText.amountLarge.height! * 34, closeTo(40, .001));
      expect(MNText.heading.fontWeight, FontWeight.w800);
      expect(MNText.button.fontSize, 17);
      expect(MNText.navLabel.fontSize, 12);
    });

    test('every text style sets the variable font weight axis', () {
      // Manrope is variable (wght 200–800, default 200): without the axis
      // set, text renders at 200 with synthetic bolding.
      final styles = [
        MNText.amountLarge,
        MNText.heading,
        MNText.barTitle,
        MNText.button,
        MNText.textButton,
        MNText.title,
        MNText.body,
        MNText.secondary,
        MNText.tile,
        MNText.menu,
        MNText.productName,
        MNText.meta,
        MNText.label,
        MNText.status,
        MNText.amount,
        MNText.price,
        MNText.navLabel,
        MNText.chip,
        MNText.quantity,
        MNText.quantityLarge,
        MNText.key,
        MNText.note,
        MNText.input,
      ];
      for (final style in styles) {
        expect(style.fontVariations,
            [FontVariation.weight(style.fontWeight!.value.toDouble())]);
      }
      expectCss(
          '.tile{height:88px;border-radius:12px;background:#F4F4F4;border:0;display:flex;flex-direction:column;align-items:flex-start;justify-content:space-between;padding:14px;font:800 15px/18px');
      expectCss(
          '.mrow{min-height:56px;display:flex;align-items:center;gap:14px;padding:0 8px 0 16px;border-top:1px solid #E2E2E2;font:600 16px/22px');
    });

    test('motion system v1', () {
      expectCss('--m-instant:${MNMotion.instant.inMilliseconds}ms');
      expectCss('--m-small:${MNMotion.small.inMilliseconds}ms');
      expectCss('--m-sheet:${MNMotion.sheet.inMilliseconds}ms');
      expectCss('--m-page:${MNMotion.page.inMilliseconds}ms');
      expectCss('--m-confirm:${MNMotion.confirm.inMilliseconds}ms');
      expectCss('--m-exit:${MNMotion.exit.inMilliseconds}ms');
      expectCss('--e-out:cubic-bezier(.2,.8,.2,1)');
      expectCss('--e-in:cubic-bezier(.4,0,1,1)');
      expectCss('--e-std:cubic-bezier(.2,0,0,1)');
      expectCss('--e-spring:cubic-bezier(.34,1.36,.64,1)');
      expect(MNMotion.easeOut, const Cubic(.2, .8, .2, 1));
      expect(MNMotion.spring, const Cubic(.34, 1.36, .64, 1));
      expectCss(
          '.m-cart-in{animation:m-cart-in ${MNMotion.cartIn.inMilliseconds}ms');
      expectCss(
          '.m-cart-out{animation:m-cart-out ${MNMotion.cartOut.inMilliseconds}ms');
      expectCss(
          '.sheet.m-out{animation:m-sheet-out ${MNMotion.sheetOut.inMilliseconds}ms');
      expectCss(
          '.m-in-tab{animation:m-tab-in ${MNMotion.tabIn.inMilliseconds}ms');
      expectCss(
          '.m-shake{animation:m-shake ${MNMotion.shake.inMilliseconds}ms');
      expectCss(
          '.radio{transition:border-width ${MNMotion.radio.inMilliseconds}ms var(--e-spring)');
      expectCss(
          '.btn:active:not(:disabled){transform:scale(${_css(MNMotion.pressButton)})');
      expectCss('.key:active{transform:scale(${_css(MNMotion.pressKey)})');
      expectCss('.pc:active{transform:scale(${_css(MNMotion.pressCard)})');
    });

    test('every approved icon is available', () {
      final names = RegExp(r'\.i-([a-z]+)\{--m:').allMatches(css).length;
      const referenceIcons = {
        MNIconData.receiveBox,
        MNIconData.brokenBox,
        MNIconData.food,
        MNIconData.roast,
        MNIconData.wings,
        MNIconData.filter,
        MNIconData.receive,
        // Owner request, 21 October 2026: copy a sign-in code to share it.
        MNIconData.copy,
        // Kikapu reference, 22 October 2026.
        MNIconData.basket,
        MNIconData.cloud,
        // Overview states supplied by the owner, 28 October 2026.
        MNIconData.overviewUp,
        MNIconData.overviewDown,
        MNIconData.overviewStar,
        MNIconData.overviewGift,
        MNIconData.accountGlobe,
        MNIconData.accountBook,
        MNIconData.accountWallet,
        MNIconData.accountUserPlus,
        MNIconData.undo,
        // Owner request, 7 November 2026: pick a phone number from contacts.
        MNIconData.contacts,
      };
      expect(
          MNIconData.values
              .where((icon) => !referenceIcons.contains(icon))
              .length,
          names);
      for (final icon in referenceIcons) {
        expect(icon.svg, contains('viewBox="0 0 24 24"'));
      }
    });
  });

  group('theme', () {
    final theme = mrNyamaTheme();

    test('Manrope, white surfaces, brand red primary', () {
      expect(theme.textTheme.bodyLarge!.fontFamily, 'Manrope');
      expect(theme.colorScheme.primary, MNColors.red);
      expect(theme.colorScheme.error, MNColors.error);
      expect(theme.scaffoldBackgroundColor, MNColors.white);
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    test('Manrope is bundled under its licence', () {
      expect(File('assets/fonts/Manrope.ttf').existsSync(), isTrue);
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });
  });

  test('colours and durations are only defined in the token files', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('core/theme/tokens.dart') ||
          path.endsWith('core/theme/motion.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (RegExp(r'Color\(0x').hasMatch(source) ||
          RegExp(r'fontWeight:').hasMatch(source) ||
          RegExp(r'(?<![A-Za-z])Colors\.(?!transparent\b)\w+')
              .hasMatch(source) ||
          // UI timing comes from MNMotion; non-visual delays (splash
          // floor, preview latency) may live elsewhere.
          (RegExp(r'^lib/(app|features|shared)/').hasMatch(path) &&
              RegExp(r'Duration\((milliseconds|microseconds|seconds)')
                  .hasMatch(source))) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });
}

/// CSS writes .98 without the leading zero.
String _css(double v) => v.toString().replaceFirst(RegExp('^0'), '');
