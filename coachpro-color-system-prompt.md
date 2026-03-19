# 🎨 COACHPRO — COMPLETE UI COLOR SYSTEM PROMPT
## Dark Mode + Light Mode Component Color Mapping
### Feed this to your AI agent before building ANY screen

---

## 📌 THE TWO PALETTES

### 🌑 DARK MODE PALETTE (6 shades — Grey/Slate family)
```
#CED4DA  →  ~Pale Slate      (lightest — near white grey)
#ADB5BD  →  ~Pale Slate 2    (light grey — secondary text)
#6C757D  →  ~Slate Grey      (mid grey — muted/disabled)
#495057  →  ~Iron Grey       (dark grey — borders, dividers)
#343A40  →  ~Gunmetal        (deep grey — card surfaces)
#212529  →  ~Shadow Grey     (darkest — page background)
```

### 🌕 LIGHT MODE PALETTE (4 shades — White/Blue family)
```
#F9F7F7  →  Off White        (lightest — page background)
#DBE2EF  →  Frost Blue       (light blue-grey — card surface, inputs)
#3F72AF  →  Steel Blue       (primary blue — CTAs, active states)
#112D4E  →  Deep Navy        (darkest — headings, key text)
```

---

## 🌑 DARK MODE — COMPONENT COLOR MAP

> Rule: Darker shades = backgrounds/structure. Lighter shades = text/icons on top.
> Think of it as layers — each layer gets one step lighter.

```
LAYER 0 — PAGE / SCAFFOLD BACKGROUND
  Scaffold backgroundColor      →  #212529  (Shadow Grey — the deepest layer)
  BottomNavigationBar bg        →  #212529  (same as scaffold, seamless)
  Drawer background             →  #212529

LAYER 1 — SURFACE / CARDS
  Card background               →  #343A40  (Gunmetal — sits above page)
  BottomSheet background        →  #343A40
  Dialog background             →  #343A40
  Shimmer base color            →  #343A40
  Shimmer highlight color       →  #495057

LAYER 2 — ELEVATED SURFACE
  Input field fill              →  #495057  (Iron Grey — higher than card)
  Dropdown background           →  #495057
  Chip background (inactive)    →  #495057
  Table row (alternate)         →  #495057
  Tooltip background            →  #495057
  Selected list item bg         →  #495057

LAYER 3 — BORDERS & DIVIDERS
  Divider color                 →  #495057  (Iron Grey — subtle separation)
  Input field border (default)  →  #495057
  Input field border (focused)  →  #CED4DA  (Pale Slate — lights up on focus)
  Card border                   →  #343A40  (same as card — invisible border)
  OutlinedButton border         →  #6C757D  (Slate Grey)

LAYER 4 — TEXT
  Primary text (headings, body) →  #CED4DA  (Pale Slate — most readable on dark)
  Secondary text (subtitles)    →  #ADB5BD  (Pale Slate 2 — softer)
  Hint text / placeholder       →  #6C757D  (Slate Grey — very muted)
  Disabled text                 →  #495057  (Iron Grey — barely visible)
  Caption / label / timestamp   →  #6C757D  (Slate Grey)

LAYER 5 — ICONS
  Primary icon                  →  #CED4DA  (Pale Slate)
  Secondary / muted icon        →  #6C757D  (Slate Grey)
  Disabled icon                 →  #495057  (Iron Grey)
  BottomNav inactive icon       →  #6C757D  (Slate Grey)
  BottomNav active icon         →  #CED4DA  (Pale Slate) + role accent color

LAYER 6 — INTERACTIVE STATES
  Button hover/pressed tint     →  #495057  (Iron Grey overlay)
  List tile hover bg            →  #343A40  with 80% opacity
  Ripple / splash color         →  #CED4DA  at 10% opacity
  Focus ring                    →  #ADB5BD  at 40% opacity

LAYER 7 — SPECIAL COMPONENTS
  AppBar background             →  #212529  (same as scaffold — borderless)
  AppBar title text             →  #CED4DA  (Pale Slate)
  AppBar icon                   →  #ADB5BD  (Pale Slate 2)
  TabBar indicator              →  Role accent color (NOT grey)
  TabBar active label           →  #CED4DA  (Pale Slate)
  TabBar inactive label         →  #6C757D  (Slate Grey)
  ProgressBar background        →  #495057  (Iron Grey)
  ProgressBar fill              →  Role accent color
  Switch track (off)            →  #495057  (Iron Grey)
  Switch track (on)             →  Role accent color at 50%
  Switch thumb (off)            →  #6C757D  (Slate Grey)
  Switch thumb (on)             →  Role accent color
  Checkbox border               →  #6C757D  (Slate Grey)
  Checkbox fill                 →  Role accent color
  Radio border                  →  #6C757D  (Slate Grey)
  Radio fill                    →  Role accent color
  Slider track                  →  #495057  (Iron Grey)
  Slider active track           →  Role accent color
  Slider thumb                  →  #CED4DA  (Pale Slate)
  Badge/notification dot bg     →  Role accent color
  Badge text                    →  #212529  (Shadow Grey)
  Skeleton/shimmer card         →  #343A40  → #495057 gradient sweep

LAYER 8 — STATUS COLORS (same in both modes, just lighter bg behind them)
  Success chip bg               →  #20C997 at 15% opacity
  Success chip text             →  #20C997
  Error chip bg                 →  #FF6B6B at 15% opacity
  Error chip text               →  #FF6B6B
  Warning chip bg               →  #FFB830 at 15% opacity
  Warning chip text             →  #FFB830
  Info chip bg                  →  Role accent color at 15%
  Info chip text                →  Role accent color
```

---

## 🌕 LIGHT MODE — COMPONENT COLOR MAP

> Rule: Lighter shades = backgrounds. Darker shades = text/elements on top.
> Used for: Parent portal, Settings screen, Invoice/Receipt views.

```
LAYER 0 — PAGE / SCAFFOLD BACKGROUND
  Scaffold backgroundColor      →  #F9F7F7  (Off White — the base canvas)
  BottomNavigationBar bg        →  #F9F7F7
  Drawer background             →  #F9F7F7

LAYER 1 — SURFACE / CARDS
  Card background               →  #FFFFFF  (pure white — sits above page)
  BottomSheet background        →  #FFFFFF
  Dialog background             →  #FFFFFF
  Shimmer base color            →  #DBE2EF  (Frost Blue)
  Shimmer highlight color       →  #F9F7F7  (Off White)

LAYER 2 — ELEVATED SURFACE / INPUTS
  Input field fill              →  #DBE2EF  (Frost Blue — softly recessed)
  Dropdown background           →  #DBE2EF
  Chip background (inactive)    →  #DBE2EF
  Table row (alternate)         →  #F9F7F7
  Tooltip background            →  #112D4E  (Deep Navy — inverted)
  Tooltip text                  →  #F9F7F7  (Off White)
  Selected list item bg         →  #DBE2EF

LAYER 3 — BORDERS & DIVIDERS
  Divider color                 →  #DBE2EF  (Frost Blue — gentle line)
  Input field border (default)  →  #DBE2EF
  Input field border (focused)  →  #3F72AF  (Steel Blue — highlights active)
  Card border                   →  #DBE2EF
  OutlinedButton border         →  #3F72AF  (Steel Blue)

LAYER 4 — TEXT
  Primary text (headings, body) →  #112D4E  (Deep Navy — most readable)
  Secondary text (subtitles)    →  #3F72AF  (Steel Blue — secondary info)
  Hint text / placeholder       →  #DBE2EF  darker / #9AACCB
  Disabled text                 →  #DBE2EF  (Frost Blue — very soft)
  Caption / label / timestamp   →  #3F72AF  at 70% opacity
  Link text                     →  #3F72AF  (Steel Blue)

LAYER 5 — ICONS
  Primary icon                  →  #112D4E  (Deep Navy)
  Secondary / muted icon        →  #3F72AF  (Steel Blue)
  Disabled icon                 →  #DBE2EF  (Frost Blue)
  BottomNav inactive icon       →  #3F72AF  at 50%
  BottomNav active icon         →  #112D4E  (Deep Navy)

LAYER 6 — INTERACTIVE STATES
  Button primary bg             →  #3F72AF  (Steel Blue)
  Button primary text           →  #F9F7F7  (Off White)
  Button secondary bg           →  #DBE2EF  (Frost Blue)
  Button secondary text         →  #112D4E  (Deep Navy)
  Button hover/pressed tint     →  #112D4E  at 8% overlay
  Ripple / splash color         →  #3F72AF  at 12% opacity
  Focus ring                    →  #3F72AF  at 30% opacity

LAYER 7 — SPECIAL COMPONENTS
  AppBar background             →  #F9F7F7  (Off White)
  AppBar elevation shadow       →  #DBE2EF  (very subtle)
  AppBar title text             →  #112D4E  (Deep Navy)
  AppBar icon                   →  #112D4E  (Deep Navy)
  TabBar indicator              →  #3F72AF  (Steel Blue)
  TabBar active label           →  #112D4E  (Deep Navy)
  TabBar inactive label         →  #3F72AF  at 50%
  ProgressBar background        →  #DBE2EF  (Frost Blue)
  ProgressBar fill              →  #3F72AF  (Steel Blue)
  Switch track (off)            →  #DBE2EF  (Frost Blue)
  Switch track (on)             →  #3F72AF  at 40%
  Switch thumb (off)            →  #F9F7F7  (Off White)
  Switch thumb (on)             →  #3F72AF  (Steel Blue)
  Checkbox border               →  #3F72AF  (Steel Blue)
  Checkbox fill                 →  #3F72AF  (Steel Blue)
  Slider track                  →  #DBE2EF  (Frost Blue)
  Slider active track           →  #3F72AF  (Steel Blue)
  Slider thumb                  →  #112D4E  (Deep Navy)
  Badge/notification dot bg     →  #3F72AF  (Steel Blue)
  Badge text                    →  #F9F7F7  (Off White)
```

---

## 🔀 SIDE-BY-SIDE REFERENCE TABLE

| Component                  | 🌑 Dark Mode        | 🌕 Light Mode       |
|----------------------------|---------------------|---------------------|
| Page background            | `#212529`           | `#F9F7F7`           |
| Card background            | `#343A40`           | `#FFFFFF`           |
| Input field fill           | `#495057`           | `#DBE2EF`           |
| Input border (default)     | `#495057`           | `#DBE2EF`           |
| Input border (focused)     | `#CED4DA`           | `#3F72AF`           |
| Divider                    | `#495057`           | `#DBE2EF`           |
| Primary text               | `#CED4DA`           | `#112D4E`           |
| Secondary text             | `#ADB5BD`           | `#3F72AF`           |
| Hint / placeholder         | `#6C757D`           | `#9AACCB`           |
| Disabled text              | `#495057`           | `#DBE2EF`           |
| Primary icon               | `#CED4DA`           | `#112D4E`           |
| Secondary icon             | `#6C757D`           | `#3F72AF`           |
| AppBar bg                  | `#212529`           | `#F9F7F7`           |
| AppBar title               | `#CED4DA`           | `#112D4E`           |
| BottomNav bg               | `#212529`           | `#F9F7F7`           |
| BottomNav active icon      | `#CED4DA`           | `#112D4E`           |
| BottomNav inactive icon    | `#6C757D`           | `#3F72AF` 50%       |
| Primary CTA button bg      | Role accent         | `#3F72AF`           |
| Primary CTA button text    | `#212529`           | `#F9F7F7`           |
| Secondary button bg        | `#495057`           | `#DBE2EF`           |
| Secondary button text      | `#CED4DA`           | `#112D4E`           |
| Chip (inactive)            | `#495057`           | `#DBE2EF`           |
| Chip (active)              | Role accent         | `#3F72AF`           |
| Tab indicator              | Role accent         | `#3F72AF`           |
| ProgressBar bg             | `#495057`           | `#DBE2EF`           |
| ProgressBar fill           | Role accent         | `#3F72AF`           |
| Switch (off track)         | `#495057`           | `#DBE2EF`           |
| Switch (on track)          | Role accent 50%     | `#3F72AF` 40%       |
| Shimmer base               | `#343A40`           | `#DBE2EF`           |
| Shimmer highlight          | `#495057`           | `#F9F7F7`           |
| Tooltip bg                 | `#495057`           | `#112D4E`           |
| Tooltip text               | `#CED4DA`           | `#F9F7F7`           |
| Bottom sheet bg            | `#343A40`           | `#FFFFFF`           |
| Dialog bg                  | `#343A40`           | `#FFFFFF`           |
| Ripple / splash            | `#CED4DA` 10%       | `#3F72AF` 12%       |
| Badge bg                   | Role accent         | `#3F72AF`           |
| Badge text                 | `#212529`           | `#F9F7F7`           |

---

## 🎨 FLUTTER IMPLEMENTATION

```dart
// lib/core/theme/app_color_tokens.dart

class ColorTokens {

  // ── DARK MODE TOKENS ──────────────────────────────────
  static const dark = _DarkTokens();

  // ── LIGHT MODE TOKENS ─────────────────────────────────
  static const light = _LightTokens();
}

class _DarkTokens {
  const _DarkTokens();

  // Palette
  Color get paleSlate1   => const Color(0xFFCED4DA);
  Color get paleSlate2   => const Color(0xFFADB5BD);
  Color get slateGrey    => const Color(0xFF6C757D);
  Color get ironGrey     => const Color(0xFF495057);
  Color get gunmetal     => const Color(0xFF343A40);
  Color get shadowGrey   => const Color(0xFF212529);

  // Semantic tokens
  Color get background   => shadowGrey;
  Color get surface      => gunmetal;
  Color get surfaceHigh  => ironGrey;
  Color get border       => ironGrey;
  Color get borderFocus  => paleSlate1;
  Color get divider      => ironGrey;
  Color get textPrimary  => paleSlate1;
  Color get textSecondary => paleSlate2;
  Color get textMuted    => slateGrey;
  Color get textDisabled => ironGrey;
  Color get iconPrimary  => paleSlate1;
  Color get iconMuted    => slateGrey;
  Color get ripple       => paleSlate1.withOpacity(0.10);
  Color get shimmerBase  => gunmetal;
  Color get shimmerHigh  => ironGrey;
  Color get inputFill    => ironGrey;
  Color get chipInactive => ironGrey;
  Color get tooltipBg    => ironGrey;
  Color get tooltipText  => paleSlate1;
}

class _LightTokens {
  const _LightTokens();

  // Palette
  Color get offWhite     => const Color(0xFFF9F7F7);
  Color get frostBlue    => const Color(0xFFDBE2EF);
  Color get steelBlue    => const Color(0xFF3F72AF);
  Color get deepNavy     => const Color(0xFF112D4E);

  // Semantic tokens
  Color get background   => offWhite;
  Color get surface      => const Color(0xFFFFFFFF);
  Color get surfaceHigh  => frostBlue;
  Color get border       => frostBlue;
  Color get borderFocus  => steelBlue;
  Color get divider      => frostBlue;
  Color get textPrimary  => deepNavy;
  Color get textSecondary => steelBlue;
  Color get textMuted    => steelBlue.withOpacity(0.60);
  Color get textDisabled => frostBlue;
  Color get iconPrimary  => deepNavy;
  Color get iconMuted    => steelBlue;
  Color get ripple       => steelBlue.withOpacity(0.12);
  Color get shimmerBase  => frostBlue;
  Color get shimmerHigh  => offWhite;
  Color get inputFill    => frostBlue;
  Color get chipInactive => frostBlue;
  Color get tooltipBg    => deepNavy;
  Color get tooltipText  => offWhite;
  Color get primaryBtn   => steelBlue;
  Color get primaryBtnText => offWhite;
  Color get secondaryBtn => frostBlue;
  Color get secondaryBtnText => deepNavy;
}
```

```dart
// lib/core/theme/app_theme.dart

ThemeData get darkTheme => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF212529),
  colorScheme: const ColorScheme.dark(
    background:     Color(0xFF212529),  // Shadow Grey
    surface:        Color(0xFF343A40),  // Gunmetal
    surfaceVariant: Color(0xFF495057),  // Iron Grey
    outline:        Color(0xFF495057),  // Iron Grey
    primary:        Color(0xFF4C6EF5),  // Keep role accent for CTA
    onPrimary:      Color(0xFF212529),
    onBackground:   Color(0xFFCED4DA),  // Pale Slate
    onSurface:      Color(0xFFCED4DA),  // Pale Slate
    onSurfaceVariant: Color(0xFFADB5BD), // Pale Slate 2
  ),
  dividerColor: const Color(0xFF495057),
  cardTheme: const CardTheme(
    color: Color(0xFF343A40),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF495057),
    hintStyle: const TextStyle(color: Color(0xFF6C757D)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF495057)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFCED4DA), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF212529),
    elevation: 0,
    iconTheme: IconThemeData(color: Color(0xFFADB5BD)),
    titleTextStyle: TextStyle(
      color: Color(0xFFCED4DA),
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF212529),
    unselectedItemColor: Color(0xFF6C757D),
    elevation: 0,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF495057),
    disabledColor: const Color(0xFF343A40),
    labelStyle: const TextStyle(color: Color(0xFFADB5BD)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    linearTrackColor: Color(0xFF495057),
  ),
  switchTheme: SwitchThemeData(
    trackColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected)
            ? const Color(0xFF4C6EF5).withOpacity(0.5)
            : const Color(0xFF495057)),
    thumbColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected)
            ? const Color(0xFF4C6EF5)
            : const Color(0xFF6C757D)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF495057), thickness: 1),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: const Color(0xFF495057),
      borderRadius: BorderRadius.circular(8),
    ),
    textStyle: const TextStyle(color: Color(0xFFCED4DA)),
  ),
);

ThemeData get lightTheme => ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF9F7F7),
  colorScheme: const ColorScheme.light(
    background:     Color(0xFFF9F7F7),  // Off White
    surface:        Color(0xFFFFFFFF),  // Pure White
    surfaceVariant: Color(0xFFDBE2EF),  // Frost Blue
    outline:        Color(0xFFDBE2EF),
    primary:        Color(0xFF3F72AF),  // Steel Blue
    onPrimary:      Color(0xFFF9F7F7),
    onBackground:   Color(0xFF112D4E),  // Deep Navy
    onSurface:      Color(0xFF112D4E),
    onSurfaceVariant: Color(0xFF3F72AF), // Steel Blue
  ),
  dividerColor: const Color(0xFFDBE2EF),
  cardTheme: const CardTheme(
    color: Color(0xFFFFFFFF),
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Color(0xFFDBE2EF)),
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFDBE2EF),
    hintStyle: const TextStyle(color: Color(0xFF9AACCB)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDBE2EF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3F72AF), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF9F7F7),
    elevation: 0,
    iconTheme: IconThemeData(color: Color(0xFF112D4E)),
    titleTextStyle: TextStyle(
      color: Color(0xFF112D4E),
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFFF9F7F7),
    unselectedItemColor: Color(0xFF3F72AF),
    selectedItemColor: Color(0xFF112D4E),
    elevation: 0,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFDBE2EF),
    labelStyle: const TextStyle(color: Color(0xFF112D4E)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Color(0xFF3F72AF),
    linearTrackColor: Color(0xFFDBE2EF),
  ),
  switchTheme: SwitchThemeData(
    trackColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected)
            ? const Color(0xFF3F72AF).withOpacity(0.4)
            : const Color(0xFFDBE2EF)),
    thumbColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected)
            ? const Color(0xFF3F72AF)
            : const Color(0xFFF9F7F7)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFDBE2EF), thickness: 1),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: const Color(0xFF112D4E),
      borderRadius: BorderRadius.circular(8),
    ),
    textStyle: const TextStyle(color: Color(0xFFF9F7F7)),
  ),
);
```

---

## 🔮 HOW TO USE IN WIDGETS

```dart
// In any widget, NEVER hardcode colors. Always do:

// ✅ CORRECT
Container(
  color: Theme.of(context).colorScheme.surface, // adapts to dark/light
  child: Text(
    'Hello',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  ),
)

// ✅ ALSO CORRECT (using extension)
Container(
  color: context.isDark
      ? const Color(0xFF343A40)   // Gunmetal
      : const Color(0xFFFFFFFF),  // Pure White
)

// ❌ WRONG — never hardcode
Container(
  color: Colors.white,  // breaks dark mode
  child: Text('Hello', style: TextStyle(color: Colors.black)),
)
```

```dart
// lib/core/utils/extensions/context_ext.dart
extension ThemeExt on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
```

---

## 🏷️ WHICH SCREENS USE WHICH MODE

| Screen / Section              | Mode           | Why                                      |
|-------------------------------|----------------|------------------------------------------|
| Admin Dashboard               | 🌑 Dark        | Power user, data-heavy, professional     |
| Teacher Dashboard             | 🌑 Dark        | Same — professional usage                |
| Student Dashboard             | 🌑 Dark        | Modern, energetic, youth appeal          |
| Quiz Taking Screen            | 🌑 Dark        | Focus mode, reduce eye strain            |
| Batch Chat                    | 🌑 Dark        | Messaging apps convention                |
| Performance Charts            | 🌑 Dark        | Charts pop more on dark                  |
| Parent Portal                 | 🌕 Light       | Parents prefer clean, familiar light UI  |
| Fee Receipt / PDF Preview     | 🌕 Light       | Receipts are documents — light is correct|
| Settings Screen               | 🌕 Light       | Clean, neutral settings convention       |
| Login / Onboarding            | 🌑 Dark        | Premium first impression                 |
| Splash Screen                 | 🌑 Dark        | Brand moment                             |

---

## ✅ AGENT RULES FOR COLOR USAGE

1. Every background uses the darkest/lightest token — NEVER a middle grey as background
2. Text on dark background = always `#CED4DA` (Pale Slate) for primary, `#ADB5BD` for secondary
3. Text on light background = always `#112D4E` (Deep Navy) for primary, `#3F72AF` for secondary
4. Borders and dividers = `#495057` on dark, `#DBE2EF` on light — consistently
5. Input fields get ONE step lighter than card: `#495057` on dark, `#DBE2EF` on light
6. Focus/active borders INVERT to the lightest shade: `#CED4DA` on dark, `#3F72AF` on light
7. Role accent colors (blue, teal, amber, purple) are ONLY used for: CTAs, active indicators, status chips, and icons that need emphasis — never for backgrounds
8. When in doubt: if dark mode, go darker. If light mode, go whiter.
