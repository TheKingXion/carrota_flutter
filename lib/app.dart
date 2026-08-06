import "dart:math" as math;

import "package:flutter/material.dart";

import "app_store.dart";
import "local_database.dart";
import "models.dart";
import "screens.dart";
import "sheets.dart";
import "theme.dart";
import "widgets.dart";

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final AppStore store;
  final composer = TextEditingController();
  final tab = ValueNotifier<int>(0);
  var loading = true;
  var onboarded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = AppStore(persistence: SqliteStatePersistence());
    _initialize();
  }

  Future<void> _initialize() async {
    await store.initialize();
    if (!mounted) return;
    setState(() {
      onboarded = store.onboarded;
      loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      store.flushPersistence();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    composer.dispose();
    tab.dispose();
    super.dispose();
  }

  Future<void> send(BuildContext phoneContext) async {
    final value = composer.text;
    composer.clear();
    if (value.trim().isEmpty) return;
    if (RegExp(r"lleg|recib|mercader", caseSensitive: false).hasMatch(value)) {
      store.addUserMessage(value);
      showDeliverySheet(phoneContext, store);
      return;
    }
    if (RegExp(r"cierr", caseSensitive: false).hasMatch(value)) {
      store.addUserMessage(value);
      showClosingSheet(phoneContext, store);
      return;
    }
    await store.send(value);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: desktopBackdrop,
        body: PhoneStage(
          child: ColoredBox(
            color: background,
            child: Center(
              child: CircularProgressIndicator(color: primary),
            ),
          ),
        ),
      );
    }

    if (!onboarded) {
      return Onboarding(
        onDone: (profile) {
          store.completeOnboarding(profile);
          setState(() => onboarded = true);
        },
      );
    }

    return Scaffold(
      backgroundColor: desktopBackdrop,
      body: PhoneStage(
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (phoneContext) => AnimatedBuilder(
              animation: Listenable.merge([store, tab]),
              builder: (context, _) {
                final pages = [
                  HomeScreen(
                    store: store,
                    onOpenProduct: (id) =>
                        showProductSheet(phoneContext, store, id),
                    onOpenDelivery: () =>
                        showDeliverySheet(phoneContext, store),
                    onOpenClosing: () => showClosingSheet(phoneContext, store),
                  ),
                  TodayScreen(
                    store: store,
                    onOpenClosing: () => showClosingSheet(phoneContext, store),
                  ),
                  MemoryScreen(store: store),
                  BusinessScreen(
                    store: store,
                    onOpenProduct: (id) =>
                        showProductSheet(phoneContext, store, id),
                    onOpenShopping: () =>
                        showShoppingSheet(phoneContext, store),
                  ),
                ];

                return ColoredBox(
                  color: background,
                  child: Column(
                    children: [
                      Expanded(
                        child: IndexedStack(
                          index: tab.value,
                          children: pages,
                        ),
                      ),
                      _Composer(
                        controller: composer,
                        onSend: () => send(phoneContext),
                        onCamera: () => showComingSoon(phoneContext, "Cámara"),
                        onVoice: () =>
                            showComingSoon(phoneContext, "Micrófono"),
                      ),
                      _MobileNavigation(
                        selectedIndex: tab.value,
                        onChanged: (value) => tab.value = value,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onCamera,
    required this.onVoice,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 4, right: 5),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: hairline),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120E3D27),
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            _ComposerButton(
              icon: Icons.mic_none_rounded,
              tooltip: "Hablar",
              onPressed: onVoice,
            ),
            _ComposerButton(
              icon: Icons.camera_alt_outlined,
              tooltip: "Documento",
              onPressed: onCamera,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: "Dile algo a Carrota…",
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 13,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton.filled(
                onPressed: onSend,
                tooltip: "Enviar",
                style: IconButton.styleFrom(backgroundColor: primary),
                icon: const Icon(Icons.arrow_upward_rounded, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerButton extends StatelessWidget {
  const _ComposerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 21, color: mutedInk),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const items = [
    (Icons.home_rounded, "Inicio"),
    (Icons.calendar_today_rounded, "Hoy"),
    (Icons.history_rounded, "Memoria"),
    (Icons.storefront_rounded, "Negocio"),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        margin: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: hairline),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x190E3D27),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final active = index == selectedIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(index),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: active ? primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index].$1,
                        size: 21,
                        color: active ? primary : mutedInk,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[index].$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? primary : mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class PhoneStage extends StatelessWidget {
  const PhoneStage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return child;
        }

        final phoneHeight = math.min(880.0, constraints.maxHeight - 28);
        return Stack(
          children: [
            Center(
              child: Container(
                key: const ValueKey("phone-frame"),
                width: 430,
                height: phoneHeight,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: phoneFrame,
                  borderRadius: BorderRadius.circular(52),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D0A1B12),
                      blurRadius: 55,
                      offset: Offset(0, 24),
                    ),
                    BoxShadow(
                      color: Color(0x1AFFFFFF),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(45),
                  child: ColoredBox(
                    color: background,
                    child: Column(
                      children: [
                        const _FakeStatusBar(),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FakeStatusBar extends StatelessWidget {
  const _FakeStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            const Text(
              "9:41",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              width: 102,
              height: 21,
              decoration: BoxDecoration(
                color: phoneFrame,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const Spacer(),
            const Icon(Icons.signal_cellular_alt_rounded, size: 13),
            const SizedBox(width: 4),
            const Icon(Icons.wifi_rounded, size: 13),
            const SizedBox(width: 4),
            const Icon(Icons.battery_full_rounded, size: 15),
          ],
        ),
      ),
    );
  }
}

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});

  final ValueChanged<BusinessProfile> onDone;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  var page = 0;
  final ownerController = TextEditingController();
  final businessController = TextEditingController();
  final typeController = TextEditingController(text: "Tienda de alimentos");
  String currency = "MXN";
  String? error;

  @override
  void dispose() {
    ownerController.dispose();
    businessController.dispose();
    typeController.dispose();
    super.dispose();
  }

  bool _continue() {
    if (page == 1 && ownerController.text.trim().isEmpty) {
      setState(() => error = "Escribe tu nombre para continuar.");
      return false;
    }
    if (page == 2 &&
        (businessController.text.trim().isEmpty ||
            typeController.text.trim().isEmpty)) {
      setState(() => error = "Completa el nombre y tipo de negocio.");
      return false;
    }
    error = null;
    if (page == 3) {
      widget.onDone(
        BusinessProfile(
          ownerName: ownerController.text.trim(),
          businessName: businessController.text.trim(),
          businessType: typeController.text.trim(),
          currency: currency,
        ),
      );
    } else {
      setState(() => page++);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (page) {
      0 => "Hola, soy Lumo.",
      1 => "¿Cómo te llamas?",
      2 => "Cuéntame sobre tu negocio.",
      _ => "${businessController.text.trim()} está listo.",
    };
    final description = switch (page) {
      0 =>
        "Voy a ayudarte a entender y operar tu negocio hablando de forma natural.",
      1 => "Usaré tu nombre para personalizar los resúmenes y alertas.",
      2 => "Estos datos ayudan a que las respuestas de la IA sean relevantes.",
      _ =>
        "Podrás registrar ventas, recibir mercadería y consultar el negocio con OpenAI o DeepSeek.",
    };

    return Scaffold(
      backgroundColor: desktopBackdrop,
      body: PhoneStage(
        child: ColoredBox(
          color: background,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel("Lumo · configuración"),
                      Text(
                        "${page + 1} / 4",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const LumoMark(size: 64),
                  const SizedBox(height: 30),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (page == 1)
                    TextField(
                      key: const ValueKey("owner-name"),
                      controller: ownerController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "Tu nombre",
                        hintText: "Ej. Jorge",
                      ),
                    ),
                  if (page == 2) ...[
                    TextField(
                      key: const ValueKey("business-name"),
                      controller: businessController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "Nombre del negocio",
                        hintText: "Ej. Carrota",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey("business-type"),
                      controller: typeController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: "Tipo de negocio",
                        hintText: "Ej. Verdulería",
                      ),
                    ),
                  ],
                  if (page == 3) ...[
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Moneda"),
                      items: const [
                        DropdownMenuItem(
                            value: "MXN", child: Text("MXN · Peso mexicano")),
                        DropdownMenuItem(
                            value: "CLP", child: Text("CLP · Peso chileno")),
                        DropdownMenuItem(
                            value: "USD", child: Text("USD · Dólar")),
                        DropdownMenuItem(
                            value: "EUR", child: Text("EUR · Euro")),
                      ],
                      onChanged: (value) =>
                          setState(() => currency = value ?? currency),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessController.text.trim(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(typeController.text.trim()),
                            Text(
                              "${ownerController.text.trim()} · $currency",
                              style: const TextStyle(color: mutedInk),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const Spacer(),
                  LinearProgressIndicator(
                    value: (page + 1) / 4,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: hairline,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _continue,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: primary,
                      ),
                      child: Text(page == 3 ? "Empezar" : "Continuar"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
